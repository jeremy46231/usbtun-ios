// SPDX-License-Identifier: MIT
// Copyright © 2026 USBTun. All Rights Reserved.

import Foundation
import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var tcpServer: TCPServer?
    private let serverQueue = DispatchQueue(label: "USBTunServerQueue")
    
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let activationAttemptId = options?["activationAttemptId"] as? String
        let errorNotifier = ErrorNotifier(activationAttemptId: activationAttemptId)

        Logger.configureGlobal(tagged: "NET", withFilePath: FileManager.logFileURL?.path)

        wg_log(.info, message: "Starting USBTun tunnel from the " + (activationAttemptId == nil ? "OS directly, rather than the app" : "app"))

        // Configure network settings with hardcoded USBTun configuration
        // Point-to-point network: 10.99.0.0/30
        // iPhone (gateway): 10.99.0.1
        // Computer: 10.99.0.2
        
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.99.0.2")
        
        // Configure IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["10.99.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings
        
        // Configure DNS settings (use common public DNS servers)
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        networkSettings.dnsSettings = dnsSettings
        
        // Set MTU
        networkSettings.mtu = 1420
        
        // Apply network settings
        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                wg_log(.error, message: "Failed to set network settings: \(error.localizedDescription)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotSetNetworkSettings)
                completionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)
                return
            }
            
            wg_log(.info, staticMessage: "Network settings configured successfully")
            
            // Start TCP server
            do {
                let server = TCPServer(port: 9876, queue: self.serverQueue)
                self.tcpServer = server
                
                // Handle incoming packets from TCP (computer -> iOS -> internet)
                server.onPacketReceived = { [weak self] packet in
                    self?.handleIncomingPacket(packet)
                }
                
                // Handle connection state changes
                server.onStateChange = { state in
                    wg_log(.info, message: "TCP connection state: \(state)")
                }
                
                try server.start()
                
                // Start reading packets from iOS network stack (internet -> iOS -> computer)
                self.startReadingPackets()
                
                wg_log(.info, staticMessage: "USBTun tunnel started successfully")
                completionHandler(nil)
                
            } catch {
                wg_log(.error, message: "Failed to start TCP server: \(error.localizedDescription)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotStartBackend)
                completionHandler(PacketTunnelProviderError.couldNotStartBackend)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        wg_log(.info, staticMessage: "Stopping USBTun tunnel")

        tcpServer?.stop()
        tcpServer = nil
        
        ErrorNotifier.removeLastErrorFile()
        
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let completionHandler = completionHandler else { return }
        
        // Simple status message support
        if messageData.count == 1 && messageData[0] == 0 {
            let status = "USBTun active\nLocal IP: 10.99.0.1\nRemote IP: 10.99.0.2"
            completionHandler(status.data(using: .utf8))
        } else {
            completionHandler(nil)
        }
    }
    
    // MARK: - Packet Handling
    
    /// Handle packets received from the computer via TCP
    /// These packets need to be injected into the iOS network stack
    private func handleIncomingPacket(_ packet: Data) {
        // Write packet to the iOS network stack
        // Protocol number 4 = IPv4
        packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
    }
    
    /// Start reading packets from iOS network stack
    /// These are response packets that need to be sent back to the computer
    private func startReadingPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            
            // Send each packet over TCP to the computer
            for packet in packets {
                self.tcpServer?.sendPacket(packet)
            }
            
            // Continue reading
            self.startReadingPackets()
        }
    }
}
