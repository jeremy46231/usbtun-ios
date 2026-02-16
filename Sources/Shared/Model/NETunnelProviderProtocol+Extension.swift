// SPDX-License-Identifier: MIT
// Copyright © 2026 USBTun. All Rights Reserved.

import NetworkExtension

enum PacketTunnelProviderError: String, Error {
    case savedProtocolConfigurationIsInvalid
    case couldNotStartBackend
    case couldNotSetNetworkSettings
}

extension NETunnelProviderProtocol {
    /// Create a simple USBTun protocol configuration
    /// USBTun uses hardcoded settings, so this is much simpler than WireGuard
    convenience init?(usbTunNamed name: String) {
        self.init()
        
        guard let appId = Bundle.main.bundleIdentifier else { return nil }
        providerBundleIdentifier = "\(appId).network-extension"
        serverAddress = "10.99.0.2" // Remote address (computer)
        
        // No configuration data needed - everything is hardcoded
        #if os(macOS)
        providerConfiguration = ["UID": getuid()]
        #endif
    }
}

            }
        }
        #endif
        return false
    }
}
