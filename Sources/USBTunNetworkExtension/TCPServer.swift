// SPDX-License-Identifier: MIT
// Copyright © 2026 USBTun. All Rights Reserved.

import Foundation
import Network
import os

/// TCP server that listens for a single connection on port 9876
/// Used to receive IP packets from the computer over USB via usbmux
class TCPServer {
    private let port: UInt16
    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue: DispatchQueue
    
    /// Callback when a packet is received from the TCP connection
    var onPacketReceived: ((Data) -> Void)?
    
    /// Callback when the connection state changes
    var onStateChange: ((NWConnection.State) -> Void)?
    
    init(port: UInt16 = 9876, queue: DispatchQueue = DispatchQueue(label: "TCPServerQueue")) {
        self.port = port
        self.queue = queue
    }
    
    /// Start listening for connections
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        guard let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!) else {
            throw TCPServerError.failedToCreateListener
        }
        
        self.listener = listener
        
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                wg_log(.info, message: "TCP server listening on port \(self?.port ?? 0)")
            case .failed(let error):
                wg_log(.error, message: "TCP server failed: \(error.localizedDescription)")
            case .cancelled:
                wg_log(.info, staticMessage: "TCP server cancelled")
            default:
                break
            }
        }
        
        listener.newConnectionHandler = { [weak self] newConnection in
            guard let self = self else { return }
            
            // Only accept one connection at a time
            if self.connection != nil {
                wg_log(.warning, staticMessage: "Rejecting new connection - already connected")
                newConnection.cancel()
                return
            }
            
            wg_log(.info, staticMessage: "Accepting new TCP connection")
            self.connection = newConnection
            self.setupConnection(newConnection)
        }
        
        listener.start(queue: queue)
    }
    
    /// Stop the server and close any active connection
    func stop() {
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        wg_log(.info, staticMessage: "TCP server stopped")
    }
    
    /// Send a packet over the TCP connection
    func sendPacket(_ packet: Data) {
        guard let connection = connection else {
            wg_log(.error, staticMessage: "Cannot send packet: no active connection")
            return
        }
        
        // Frame the packet with 4-byte length prefix (big-endian)
        var lengthBytes = UInt32(packet.count).bigEndian
        var framedData = Data()
        framedData.append(Data(bytes: &lengthBytes, count: 4))
        framedData.append(packet)
        
        connection.send(content: framedData, completion: .contentProcessed { error in
            if let error = error {
                wg_log(.error, message: "Failed to send packet: \(error.localizedDescription)")
            }
        })
    }
    
    private func setupConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            self?.onStateChange?(state)
            
            switch state {
            case .ready:
                wg_log(.info, staticMessage: "TCP connection established")
                self?.receiveNextPacket(from: connection)
            case .failed(let error):
                wg_log(.error, message: "TCP connection failed: \(error.localizedDescription)")
                self?.connection = nil
            case .cancelled:
                wg_log(.info, staticMessage: "TCP connection cancelled")
                self?.connection = nil
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func receiveNextPacket(from connection: NWConnection) {
        // First, read the 4-byte length prefix
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                wg_log(.error, message: "Error receiving length: \(error.localizedDescription)")
                return
            }
            
            guard let lengthData = data, lengthData.count == 4 else {
                wg_log(.error, staticMessage: "Invalid length prefix")
                return
            }
            
            // Parse length (big-endian uint32)
            let length = lengthData.withUnsafeBytes { buffer in
                buffer.load(as: UInt32.self).bigEndian
            }
            
            guard length > 0 && length <= 4096 else {
                wg_log(.error, message: "Invalid packet length: \(length)")
                return
            }
            
            // Now read the actual packet
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { packetData, _, isComplete, error in
                if let error = error {
                    wg_log(.error, message: "Error receiving packet: \(error.localizedDescription)")
                    return
                }
                
                guard let packetData = packetData, packetData.count == Int(length) else {
                    wg_log(.error, staticMessage: "Incomplete packet received")
                    return
                }
                
                // Deliver the packet
                self.onPacketReceived?(packetData)
                
                // Continue receiving
                self.receiveNextPacket(from: connection)
            }
        }
    }
}

enum TCPServerError: Error {
    case failedToCreateListener
    case noActiveConnection
}
