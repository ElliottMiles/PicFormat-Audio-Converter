//
//  Good_Audio_ConverterApp.swift
//  Good_Audio_Converter
//
//  Created by Agent Sandbox on 8/20/26.
//

import SwiftUI

@main
struct Good_Audio_ConverterApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // .utility, not .userInitiated — this is incidental
                    // background housekeeping, not something the user is
                    // waiting on, unlike the Task.detached calls elsewhere
                    // that offload direct results of a user action.
                    await Task.detached(priority: .utility) {
                        FileExportService.performStaleCleanup()
                    }.value
                }
        }
        // Backgrounding is a far more reliable "the user is leaving" signal
        // than app termination — iOS guarantees this fires, unlike
        // applicationWillTerminate, which is skipped entirely for a
        // suspended app the system later kills to reclaim memory.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background else { return }
            Task.detached(priority: .utility) {
                FileExportService.performStaleCleanup()
            }
        }
    }
}
