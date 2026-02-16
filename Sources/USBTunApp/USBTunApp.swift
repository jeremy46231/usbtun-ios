// SPDX-License-Identifier: MIT
// Copyright © 2026 USBTun. All Rights Reserved.

import SwiftUI

@main
struct USBTunApp: App {
    init() {
        // Configure logging
        Logger.configureGlobal(tagged: "APP", withFilePath: FileManager.logFileURL?.path)
        wg_log(.info, staticMessage: "USBTun app starting")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
