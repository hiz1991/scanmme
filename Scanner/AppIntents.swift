import AppIntents
import SwiftUI // Assuming your app uses SwiftUI

// 1. Define the Intent
struct StartNewScanIntent: AppIntent {
    // Title shown to the user
    static var title: LocalizedStringResource = "Start New Scan"
    // Optional description
    static var description: IntentDescription? = "Opens the app to start a new document scan."
    // Makes it available without user configuration
    static var openAppWhenRun: Bool = true // Often useful to bring app forefront

    // This function runs when the intent is triggered
    @MainActor // Ensure UI code runs on the main thread
    func perform() async throws -> some IntentResult {
        // --- Your Code Here ---
        // Example: Post a notification, access a shared AppState,
        // or use deep linking to navigate your app to the scanner view.
        // This depends heavily on your app's architecture.
        print("PERFORMING: StartNewScanIntent")
        // Example using NotificationCenter to tell your main app scene/view to navigate:
        NotificationCenter.default.post(name: .startNewScanNotification, object: nil)

        // You might return .result() or .result(dialog:) to provide feedback
        return .result()
    }
}

// Extension for the Notification Name (if using that method)
extension Notification.Name {
    static let startNewScanNotification = Notification.Name("com.yourapp.startNewScan")
}


// 2. Expose it via AppShortcutsProvider
struct YourAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartNewScanIntent(),
            phrases: [
                // How users can trigger this with Siri
                "Start a new scan in \(.applicationName)",
                "New scan with \(.applicationName)",
                "Scan document using \(.applicationName)"
            ],
            shortTitle: "New Scan", // Short title for buttons/widgets
            systemImageName: "camera.viewfinder" // Icon
        )
        // Add more AppShortcuts for other intents here
        // AppShortcut(intent: OpenLastScanIntent(), ...)
    }
}
