//
//  Good_Audio_ConverterApp.swift
//  Good_Audio_Converter
//
//  Created by Agent Sandbox on 8/20/26.
//

import SwiftUI

@main
struct Good_Audio_ConverterApp: App {
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
    }
}
