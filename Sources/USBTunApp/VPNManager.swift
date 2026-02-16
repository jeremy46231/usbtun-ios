// SPDX-License-Identifier: MIT
// Copyright © 2026 USBTun. All Rights Reserved.

import Foundation
import NetworkExtension
import Combine

/// Simple manager for USBTun VPN connection
/// Unlike WireGuard which supports multiple tunnels, USBTun has a single tunnel with hardcoded configuration
class VPNManager: ObservableObject {
    @Published var status: NEVPNStatus = .invalid
    @Published var isConnected: Bool = false
    @Published var statusDescription: String = "Disconnected"
    
    private var vpnManager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    
    init() {
        loadVPNConfiguration()
    }
    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Load or create VPN configuration
    private func loadVPNConfiguration() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                wg_log(.error, message: "Failed to load VPN configuration: \(error.localizedDescription)")
                return
            }
            
            // Try to find existing USBTun configuration
            if let manager = managers?.first(where: { $0.localizedDescription == "USBTun" }) {
                self.vpnManager = manager
                self.setupStatusObserver()
                self.updateStatus(manager.connection.status)
                wg_log(.info, staticMessage: "Loaded existing VPN configuration")
            } else {
                // Create new configuration
                self.createVPNConfiguration()
            }
        }
    }
    
    /// Create a new VPN configuration
    private func createVPNConfiguration() {
        guard let protocolConfig = NETunnelProviderProtocol(usbTunNamed: "USBTun") else {
            wg_log(.error, staticMessage: "Failed to create protocol configuration")
            return
        }
        
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "USBTun"
        manager.protocolConfiguration = protocolConfig
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                wg_log(.error, message: "Failed to save VPN configuration: \(error.localizedDescription)")
                return
            }
            
            wg_log(.info, staticMessage: "Created new VPN configuration")
            
            // Reload to get the saved instance
            manager.loadFromPreferences { error in
                if let error = error {
                    wg_log(.error, message: "Failed to reload VPN configuration: \(error.localizedDescription)")
                    return
                }
                
                self.vpnManager = manager
                self.setupStatusObserver()
                self.updateStatus(manager.connection.status)
            }
        }
    }
    
    /// Set up observation of VPN status changes
    private func setupStatusObserver() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: vpnManager?.connection,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let connection = notification.object as? NEVPNConnection else {
                return
            }
            self.updateStatus(connection.status)
        }
    }
    
    /// Update published status properties
    private func updateStatus(_ newStatus: NEVPNStatus) {
        status = newStatus
        isConnected = (newStatus == .connected)
        
        switch newStatus {
        case .invalid:
            statusDescription = "Invalid"
        case .disconnected:
            statusDescription = "Disconnected"
        case .connecting:
            statusDescription = "Connecting..."
        case .connected:
            statusDescription = "Connected"
        case .reasserting:
            statusDescription = "Reconnecting..."
        case .disconnecting:
            statusDescription = "Disconnecting..."
        @unknown default:
            statusDescription = "Unknown"
        }
        
        wg_log(.info, message: "VPN status: \(statusDescription)")
    }
    
    /// Start the VPN connection
    func connect() {
        guard let manager = vpnManager else {
            wg_log(.error, staticMessage: "Cannot connect: VPN manager not initialized")
            return
        }
        
        guard status == .disconnected || status == .invalid else {
            wg_log(.warning, message: "Cannot connect: already \(statusDescription)")
            return
        }
        
        do {
            let options: [String: NSObject] = [
                "activationAttemptId": UUID().uuidString as NSString
            ]
            try manager.connection.startVPNTunnel(options: options)
            wg_log(.info, staticMessage: "Starting VPN tunnel...")
        } catch {
            wg_log(.error, message: "Failed to start VPN: \(error.localizedDescription)")
        }
    }
    
    /// Stop the VPN connection
    func disconnect() {
        guard let manager = vpnManager else {
            wg_log(.error, staticMessage: "Cannot disconnect: VPN manager not initialized")
            return
        }
        
        guard status != .disconnected && status != .disconnecting else {
            wg_log(.warning, staticMessage: "Already disconnected")
            return
        }
        
        manager.connection.stopVPNTunnel()
        wg_log(.info, staticMessage: "Stopping VPN tunnel...")
    }
    
    /// Toggle connection state
    func toggleConnection() {
        if isConnected || status == .connecting {
            disconnect()
        } else {
            connect()
        }
    }
}
