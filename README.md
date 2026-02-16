# USBTun for iOS

USB-based iPhone network routing system that routes all computer traffic through iPhone's internet connection over USB, without using Personal Hotspot or requiring jailbreak.

This is a fork of [WireGuard](https://www.wireguard.com/) for iOS/macOS, stripped down and modified for USB-based IP packet tunneling.

## Status

🚧 **Work in Progress** - Currently stripping WireGuard-specific code and rebranding.

## Building

- Clone this repo
- Open the project in Xcode
- Configure your development team in the project settings
- Build and run on a physical iOS device

## Architecture

USBTun uses NEPacketTunnelProvider to create a VPN tunnel that:
1. Accepts IP packets from a computer over TCP via USB (using usbmuxd)
2. Injects them into iOS network stack
3. Returns response packets back over TCP

This allows routing all computer traffic through iPhone's cellular/WiFi connection.

## License

Based on WireGuard for iOS/macOS - see COPYING for details.
