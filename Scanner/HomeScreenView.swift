// MARK: - HomeScreenView.swift
// Create a new SwiftUI View file named HomeScreenView.swift and paste this code.

import SwiftUI

// Placeholder View for the Scanner Interface
struct ScannerView: View {
    // Environment variable to dismiss the sheet/cover
    @Environment(\.dismiss) var dismiss
    
    // Callback to simulate finishing a scan and potentially navigating
    // In a real app, this would likely pass the scanned data back
    var onScanComplete: () -> Void
    
    var body: some View {
        NavigationView { // Embed in NavigationView for a toolbar
            VStack {
                Spacer()
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 100))
                    .foregroundColor(.gray)
                Text("Scanning Subsystem Placeholder")
                    .font(.title2)
                    .padding(.top)
                Spacer()
                // Simulate capturing a document - Action now handled by onScanComplete
                Button("Simulate Capture & Edit") {
                }
                .navigationTitle("Scan Document")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss() // Dismiss the sheet
                        }
                    }
                }
            }
        }
    }
}


struct HomeScreenView: View {
    // State for the search field
    @State private var searchText = ""
    // State to trigger navigation to the edit screen AFTER scanning
    @State private var navigateToEditScreen = false
    // State to present the scanner view
    @State private var isShowingScanner = false

    var body: some View {
        NavigationView {
            // Use ZStack to overlay buttons over the scrollable content
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) { // Increased spacing a bit
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search scans...", text: $searchText)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                        // Recent Scans Section
                        Section {
                            VStack(spacing: 10) {
                                RecentScanItem(icon: "doc.text", iconColor: .blue, title: "Electricity Bill - March", date: "Scanned: Apr 1, 2025", tag: "Bill", tagColor: .blue)
                                RecentScanItem(icon: "envelope", iconColor: .green, title: "Letter from Aunt May", date: "Scanned: Mar 30, 2025", tag: "Personal", tagColor: .green)
                            }
                            .padding(.horizontal)
                        } header: {
                             Text("Recent Scans")
                                .font(.title2.weight(.semibold))
                                .padding(.horizontal)
                                // Ensure header aligns with list content if needed
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }


                        // Folders Section
                        Section {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                FolderItem(icon: "folder", iconColor: .yellow, title: "Bills")
                                FolderItem(icon: "folder", iconColor: .purple, title: "Personal")
                                FolderItem(icon: "plus", iconColor: .gray, title: "Add Folder", isAddButton: true)
                            }
                            .padding(.horizontal)
                        } header: {
                            Text("Folders")
                               .font(.title2.weight(.semibold))
                               .padding(.horizontal)
                               .frame(maxWidth: .infinity, alignment: .leading)
                        }


                        // Providers Section
                         Section {
                            VStack(spacing: 10) {
                                ProviderItem(icon: "building.columns", title: "ATT")
                                ProviderItem(icon: "building.columns", title: "Disney")
                                // Using Vienna location context
                                ProviderItem(icon: "leaf", iconColor: .green, title: "Eco Electricity Vienna")
                            }
                            .padding(.horizontal)
                        } header: {
                            Text("Providers")
                               .font(.title2.weight(.semibold))
                               .padding(.horizontal)
                               .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Spacer to ensure content doesn't sit right under the buttons
                        // Adjust height as needed
                        Spacer(minLength: 100)

                    }
                    .padding(.top) // Add padding at the top of the VStack
                } // End ScrollView
                .coordinateSpace(name: "scrollView") // For potential future scroll effects

                // --- Button Positioning (Absolute within ZStack) ---
                // This positions the buttons relative to the bottom edge of the screen area
                ZStack {
                     // Main Scan Button Container (Frame) - Approx calculations for positioning
                     let frameWidth: CGFloat = 72
                     let mainButtonWidth: CGFloat = 64
                     let autoButtonWidth: CGFloat = 40
                     let gap: CGFloat = 4
                     let screenWidth = UIScreen.main.bounds.width
                     let frameX = screenWidth / 2
                     let frameY: CGFloat = frameWidth / 2 // Y position relative to bottom padding

                     Circle()
                        .fill(Color(.systemGray5)) // Frame color
                        .frame(width: frameWidth, height: frameWidth) // 64 + 2*4 padding
                        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                        .position(x: frameX, y: frameY) // Position frame center

                     // Main Scan Button
                     Button {
                         print("Scan Tapped - Opening Scanner")
                         // Remove direct navigation: navigateToEditScreen = true
                         isShowingScanner = true // Present the scanner view
                     } label: {
                         Image(systemName: "viewfinder")
                             .font(.system(size: 28, weight: .medium))
                             .foregroundColor(.white)
                             .frame(width: mainButtonWidth, height: mainButtonWidth)
                             .background(Color.blue)
                             .clipShape(Circle())
                             .shadow(color: Color.blue.opacity(0.4), radius: 5, y: 3)
                     }
                     .position(x: frameX, y: frameY) // Position button center

                     // Auto Scan Button
                     Button {
                         print("Auto Scan Tapped - Opening Scanner")
                         // TODO: Implement specific auto-scan logic if different
                         isShowingScanner = true // Also present the scanner view
                     } label: {
                         Image(systemName: "film")
                             .font(.system(size: 18, weight: .medium))
                             .foregroundColor(.white)
                             .frame(width: autoButtonWidth, height: autoButtonWidth)
                             .background(Color.blue) // Make background solid blue
                             .clipShape(Circle())
                             .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                     }
                     .opacity(0.8) // Apply opacity
                     // Calculate X: Center + Frame Radius + Gap + Auto Button Radius
                     .position(x: frameX + (frameWidth / 2) + gap + (autoButtonWidth / 2),
                               // Align Y centers (Main button Y is frameY)
                               y: frameY)
                }
                .frame(height: 72) // Container height for positioning within ZStack overlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom) // Align container to ZStack bottom
                .padding(.bottom, 30) // Overall padding from device safe area bottom


            } // End ZStack
            .navigationTitle("LetterScan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        print("Settings Tapped")
                        // TODO: Implement navigation to settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            // Link to the Edit Screen - Navigation is now triggered AFTER scanning
            .background(
                 // Invisible NavigationLink for programmatic navigation
                NavigationLink(destination: ScanEditView(), isActive: $navigateToEditScreen) { EmptyView() }
                    .opacity(0) // Make it invisible
            )
            // Modifier to present the scanner view modally
            .sheet(isPresented: $isShowingScanner, onDismiss: {
                // --- MODIFIED: Trigger navigation on dismiss if needed ---
                // This is safer than DispatchQueue.main.asyncAfter
                // Check if navigation should occur (e.g., if a scan was successfully simulated)
                // For this example, we assume dismissal always means navigateToEditScreen should be true
                // In a real app, the onScanComplete closure might set a flag that's checked here.
                print("Scanner sheet dismissed, attempting navigation.")
                navigateToEditScreen = true // Set flag *after* dismissal
            }) {
                // This is the view that will be presented
                 ScannerView {
                     // This closure is called when "Simulate Capture & Edit" is tapped *before* dismissing
                     print("Scan complete callback triggered.")
                     // We no longer set navigateToEditScreen here directly.
                     // The onDismiss handler will manage it.
                 }
            }
            // Alternatively, use .fullScreenCover for a non-dismissible-by-swipe presentation
            // .fullScreenCover(isPresented: $isShowingScanner) { ScannerView(...) }

        }
        // Use stack style for broader compatibility, especially on iPad
        .navigationViewStyle(.stack)
    }
}

// MARK: - Home Screen Helper Views

struct RecentScanItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let date: String
    let tag: String
    let tagColor: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30, alignment: .center) // Align icons

            VStack(alignment: .leading) {
                Text(title).font(.headline).lineLimit(1)
                Text(date).font(.caption).foregroundColor(.gray)
            }

            Spacer()

            Text(tag)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tagColor.opacity(0.15))
                .foregroundColor(tagColor)
                .clipShape(Capsule())
        }
        .padding(12) // Slightly more padding
        .background(Color(.systemGray6))
        .cornerRadius(10) // Slightly more rounded
    }
}

struct FolderItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    var isAddButton: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isAddButton ? .gray : iconColor)
            Text(title)
                .font(.subheadline.weight(.medium)) // Adjusted font
                .foregroundColor(isAddButton ? .gray : .primary.opacity(0.9))
            Spacer()
        }
        .padding()
        .background(isAddButton ? Color(.systemGray6) : iconColor.opacity(0.1))
        .cornerRadius(10)
        .onTapGesture {
             print("\(title) folder tapped")
             // TODO: Implement navigation or action
         }
    }
}

struct ProviderItem: View {
    let icon: String
    var iconColor: Color = .gray // Default color
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 30, alignment: .center) // Align icons

            Text(title)
                .font(.headline)
                .foregroundColor(.primary.opacity(0.8))

            Spacer()
        }
        .padding(12) // Slightly more padding
        .background(Color(.systemGray6))
        .cornerRadius(10) // Slightly more rounded
        .onTapGesture {
             print("\(title) provider tapped")
             // TODO: Implement navigation or action
         }
    }
}


// MARK: - Preview Provider for HomeScreenView
struct HomeScreenView_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreenView()
    }
}



