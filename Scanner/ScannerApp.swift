//
//  ScannerApp.swift
//  Scanner
//
//  Created by Khizir Putcygov on 02.04.25.
//

import SwiftUI

@main
struct ScannerApp: App {
    var body: some Scene {
        WindowGroup {
            HomeScreenView() // Your starting view
        }
        // Add the model container, specifying the models to manage
        // SwiftData automatically creates the underlying storage (e.g., SQLite)
        .modelContainer(for: [Folder.self, ScannedDocument.self])
        // For CloudKit sync (requires iCloud capability setup):
        // .modelContainer(for: [Folder.self, ScannedDocument.self], isAutosaveEnabled: true, isCloudKitEnabled: true)

    }
}
