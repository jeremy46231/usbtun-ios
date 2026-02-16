// SPDX-License-Identifier: MIT
// Copyright © 2026 USBTun. All Rights Reserved.

import SwiftUI
import NetworkExtension

/// Main content view for USBTun app
struct ContentView: View {
    @StateObject private var vpnManager = VPNManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Icon/Logo placeholder
                Image(systemName: "cable.connector")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 60)
                
                // App Title
                Text("USBTun")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Status indicator
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 20, height: 20)
                        
                        if vpnManager.status == .connecting || vpnManager.status == .reasserting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    Text(vpnManager.statusDescription)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Connection info (when connected)
                if vpnManager.isConnected {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Tunnel IP", value: "10.99.0.1")
                        InfoRow(label: "Remote IP", value: "10.99.0.2")
                        InfoRow(label: "TCP Port", value: "9876")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Connect/Disconnect button
                Button(action: {
                    vpnManager.toggleConnection()
                }) {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(buttonColor)
                        .cornerRadius(10)
                }
                .disabled(vpnManager.status == .connecting || vpnManager.status == .disconnecting)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var statusColor: Color {
        switch vpnManager.status {
        case .connected:
            return .green
        case .connecting, .reasserting:
            return .orange
        case .disconnected, .invalid:
            return .gray
        case .disconnecting:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var buttonTitle: String {
        if vpnManager.isConnected {
            return "Disconnect"
        } else if vpnManager.status == .connecting {
            return "Connecting..."
        } else if vpnManager.status == .disconnecting {
            return "Disconnecting..."
        } else {
            return "Connect"
        }
    }
    
    private var buttonColor: Color {
        if vpnManager.isConnected || vpnManager.status == .disconnecting {
            return .red
        } else {
            return .blue
        }
    }
}

/// Info row component
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
