import SwiftUI

// Define keys for UserDefaults to avoid typos
struct UserDefaultsKeys {
    static let shouldRemoveDupsEnabled = "settings.shouldRemoveDupsEnabled"
    static let darkModeEnabled = "settings.darkModeEnabled"
}

struct SettingsView: View {
    let parent: HomeScreenView
    // Use @AppStorage for direct binding to UserDefaults
    @AppStorage(UserDefaultsKeys.shouldRemoveDupsEnabled) private var shouldRemoveDupsEnabled: Bool = true // Default value if not set
    @AppStorage(UserDefaultsKeys.darkModeEnabled) private var darkModeEnabled: Bool = false   // Default value if not set

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
//        VStack(alignment: .leading, spacing: 15) {
            
          
            
            Text("Settings")
                .font(.title)
                .padding(.top, 10)
                .padding(.bottom, 40)

            Toggle("Automatically removes duplicated pages", isOn: $shouldRemoveDupsEnabled)

            Button("Done") {
                // Action to dismiss the popover (handled by the parent view's state)
                print("Done tapped - popover should be dismissed by its presentation logic.")
                self.parent.showSettingsPopover = false
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
//        .navigationTitle("LetterScaasn")
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
       // .frame(width: 250, height: 280) // Define a size for the popover content
        .background(.ultraThinMaterial) // Or .thinMaterial, .regularMaterial, .thickMaterial
//        .opacity(0.9)
//        .cornerRadius(12)
        // No explicit save button is needed for @AppStorage as it updates UserDefaults on change
    }
}
