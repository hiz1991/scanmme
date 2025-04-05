import SwiftUI
import SwiftData // For @Query, @Environment, etc.
import VisionKit // For VNDocumentCameraScan and DocumentScannerView


struct HomeScreenView: View {
    // Environment & State variables
    @Environment(\.modelContext) private var modelContext // Access SwiftData context
    @Query(sort: \Folder.createdAt, order: .forward) var folders: [Folder] // Fetch folders
    @State private var newFolderName: String = "" // For adding new folders
    @State private var searchText = "" // For search bar
    @State private var navigateToEditScreen = false // Controls navigation to edit view
    @State private var isShowingScanner = false // Controls presentation of scanner sheet
    @State private var scannedDocument: VNDocumentCameraScan? = nil // Holds result from scanner
    @State private var scanError: Error? = nil // Holds error from scanner

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Main scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        SearchBarView(searchText: $searchText) // Extracted Search Bar

                        RecentScansSectionView() // Extracted Recent Scans (uses placeholders)

                        // Extracted Folders Section View using SwiftData
                        FoldersSectionView(
                            folders: folders, // Pass the fetched folders
                            newFolderName: $newFolderName, // Pass binding for new name input
                            addFolderAction: addFolder, // Pass the add function
                            deleteFolderAction: deleteFolder // Pass the delete function
                        )

                        ProvidersSectionView() // Extracted Providers (uses placeholders)

                        Spacer(minLength: 100) // Space at bottom before overlay buttons

                    } // End VStack
                    .padding(.top)
                } // End ScrollView
                .coordinateSpace(name: "scrollView") // For potential future scroll effects

                // Overlay for Scan Buttons
                ScanButtonsOverlayView(isShowingScanner: $isShowingScanner)

            } // End ZStack (Main content ZStack)
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
            // Background NavigationLink for programmatic navigation to ScanEditView
            .background(
                NavigationLink(
                    // Ensure ScanEditView initializer accepts VNDocumentCameraScan?
                    destination: ScanEditView(scannedDocument: self.scannedDocument),
                    isActive: $navigateToEditScreen
                ) { EmptyView() }
                .opacity(0)
            )
            // Sheet presentation for the scanner
            .sheet(isPresented: $isShowingScanner, onDismiss: {
                // Navigation logic after scanner dismissal
                if scannedDocument != nil {
                    print("Scanner sheet dismissed, successful scan detected. Navigating.")
                    navigateToEditScreen = true
                    // Consider resetting scannedDocument = nil here or in ScanEditView's onDisappear
                } else {
                    print("Scanner sheet dismissed, no successful scan detected.")
                    scanError = nil // Reset error
                }
            }) {
                 // Present the actual DocumentScannerView (ensure it's defined)
                 // This placeholder needs to be replaced with the real implementation
                 // that uses VisionKit and calls the onScanResult closure.
                 DocumentScannerView { result in                     
                     switch result {
                     case .success(let scan):
                         print("Scan received in HomeScreenView. Page count: \(scan.pageCount)")
                         self.scannedDocument = scan
                         self.scanError = nil
                     case .failure(let error):
                         print("Scan failed in HomeScreenView: \(error.localizedDescription)")
                         self.scanError = error
                         self.scannedDocument = nil
                     }
                 }
            }
        } // End NavigationView
        .navigationViewStyle(.stack) // Use stack style
    }

    // MARK: - Data Functions

    /// Adds a new folder to SwiftData.
    private func addFolder() {
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return } // Don't add empty names
        let newFolder = Folder(name: trimmedName, colorHex: ["#EAAA00","#DC63EA","#6CC7EA","#59EA38"][Int.random(in: 0..<4)])
        modelContext.insert(newFolder) // Insert into SwiftData context
        newFolderName = "" // Clear the input field
        print("Added folder: \(newFolder.name)")
        // Note: SwiftData typically autosaves. Manual save below if needed.
        // try? modelContext.save()
    }

    /// Deletes a specific folder from SwiftData.
    private func deleteFolder(folder: Folder) {
        withAnimation { // Animate the deletion if part of a List
            modelContext.delete(folder)
            print("Deleted folder: \(folder.name)")
            // try? modelContext.save() // Optional manual save
        }
    }

     // --- Placeholder for DocumentScannerView ---
     // Replace this with the actual implementation using UIViewControllerRepresentable
     // and VNDocumentCameraViewController as shown in previous examples.
//     struct DocumentScannerView: View {
//         var onScanResult: (Result<VNDocumentCameraScan, Error>) -> Void
//         // Need @Environment(\.dismiss) var dismiss inside the real one
//         var body: some View {
//            VStack {
//                Text("Placeholder Scanner View")
//                Button("Simulate Scan Success") {
//                    // In a real implementation, the delegate would call this
//                    // For placeholder, we simulate success with a dummy scan object if possible
//                    // Or just simulate the flow without real data
//                     print("Simulating scan success...")
//                     // onScanResult(.success(VNDocumentCameraScan())) // Needs a real scan object
//                     // For testing flow:
//                     // 1. Set a dummy scan object (if you can create one) OR
//                     // 2. Just call the completion with a placeholder/nil that triggers navigation logic
//                     // For now, just print and let the onDismiss handle it (assuming scannedDocument is set somehow)
//                     // parent.dismiss() // The real coordinator would call dismiss
//                }
//                Button("Simulate Cancel") {
//                     // parent.dismiss()
//                }
//            }
//         }
//     }
}

// MARK: - Extracted View Structs

/// View for the search bar
struct SearchBarView: View {
    @Binding var searchText: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search scans...", text: $searchText)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

/// Section displaying recent scans (uses placeholder data)
struct RecentScansSectionView: View {
    // TODO: Replace with @Query fetching ScannedDocument objects
    var body: some View {
        Section {
            VStack(spacing: 10) {
                // Replace with ForEach over fetched documents
                RecentScanItem(icon: "doc.text", iconColor: .blue, title: "Electricity Bill - March", date: "Scanned: Apr 1, 2025", tag: "Bill", tagColor: .blue)
                RecentScanItem(icon: "envelope", iconColor: .green, title: "Letter from Aunt May", date: "Scanned: Mar 30, 2025", tag: "Personal", tagColor: .green)
            }
            .padding(.horizontal)
        } header: {
            Text("Recent Scans")
                .font(.title2.weight(.semibold))
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Section displaying folders from SwiftData and UI for adding new folders
struct FoldersSectionView: View {
    // Input: The fetched folders array from the parent view's @Query
    let folders: [Folder]
    // Input: Binding for the new folder name TextField
    @Binding var newFolderName: String
    // Input: Closures for actions defined in the parent view
    let addFolderAction: () -> Void
    let deleteFolderAction: (Folder) -> Void

    // Grid layout configuration
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 140)) // Responsive grid columns
    ]

    var body: some View {
        Section {
            // --- UI for Adding Folders ---
            HStack {
                TextField("New Folder Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                Button("Add", action: addFolderAction)
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 5) // Spacing
            
            // --- Grid Displaying Actual Folders ---
            if folders.isEmpty {
                Text("No folders yet. Add one above!")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(folders) { folder in
                        FolderItemView(folder: folder) // Use dedicated view for each item
                        
                        // Add context menu for deletion (alternative to swipe-to-delete)
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleteFolderAction(folder)
                                }
                                // Add other actions like Rename here
                            }
                        // TODO: Wrap with NavigationLink if tapping should navigate
                        // NavigationLink(destination: FolderDetailView(folder: folder)) {
                        //    FolderItemView(folder: folder)
                        // }
                    }
                }
                .padding(.horizontal)
            }
        } header: {
            Text("Folders")
                .font(.title2.weight(.semibold))
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// View for displaying a single folder item in the grid
struct FolderItemView: View {
    // Use @ObservedObject because Folder is a class (@Model)
    // Ensure Folder conforms to ObservableObject if not using @Model directly (but @Model handles it)
    var folder: Folder

    var body: some View {
         HStack {
            // Display icon (default or custom)
            Image(systemName: folder.iconName ?? "folder")
                // Example: Apply color if available
                 .foregroundColor(folder.colorHex != nil ? (Color(hex:folder.colorHex!)) : .accentColor)
            // Display folder name
            Text(folder.name)
                .lineLimit(1) // Prevent long names wrapping badly
            Spacer()
            // Display count of documents in the folder
            Text("\(folder.documents?.count ?? 0)")
                 .font(.caption2)
                 .foregroundColor(.secondary)
                 .padding(.horizontal, 5)
                 .background(Color(.systemGray5))
                 .clipShape(Capsule())

        }
        .padding() // Padding inside the item
        .background(Color(.secondarySystemBackground)) // Background color
        .cornerRadius(10) // Rounded corners
    }
}

/// Section displaying providers (uses placeholder data)
struct ProvidersSectionView: View {
    // TODO: Replace with actual data source and logic
    var body: some View {
        Section {
             VStack(spacing: 10) {
                 ProviderItem(icon: "building.columns", title: "ATT")
                 ProviderItem(icon: "building.columns", title: "Disney")
                 ProviderItem(icon: "leaf", iconColor: .green, title: "Eco Electricity Vienna")
             }
             .padding(.horizontal)
        } header: {
             Text("Providers")
                .font(.title2.weight(.semibold))
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// View for the scan buttons overlay at the bottom
struct ScanButtonsOverlayView: View {
    @Binding var isShowingScanner: Bool
    // TODO: Potentially pass actions for the buttons if needed

    var body: some View {
        ZStack {
            // Using HStack for simpler centering layout example
            HStack(spacing: 20) {
                 Spacer() // Pushes buttons to center

                 // Main Scan Button
                 Button {
                     print("Scan Tapped - Opening Scanner")
                     isShowingScanner = true
                 } label: {
                     Image(systemName: "viewfinder")
                         .font(.system(size: 28, weight: .medium))
                         .foregroundColor(.white)
                         .frame(width: 64, height: 64)
                         .background(Color.blue)
                         .clipShape(Circle())
                         .shadow(color: Color.blue.opacity(0.4), radius: 5, y: 3)
                 }

                 // Auto Scan Button
                 Button {
                     print("Auto Scan Tapped - Opening Scanner")
                     // TODO: Implement specific auto-scan logic if different
                     isShowingScanner = true
                 } label: {
                     Image(systemName: "film")
                         .font(.system(size: 18, weight: .medium))
                         .foregroundColor(.blue) // Use accent color
                         .frame(width: 40, height: 40)
                         .background(.thinMaterial) // Use material background for contrast
                         .clipShape(Circle())
                         .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                 }

                 Spacer() // Pushes buttons to center
            }
            .padding(.bottom, 30) // Padding from bottom safe area
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom) // Align overlay to bottom
    }
}


// MARK: - Helper Views (Copied from original user code)

/// View for displaying a recent scan item (placeholder)
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
                .frame(width: 30, alignment: .center)

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
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

/// View for displaying a provider item (placeholder)
struct ProviderItem: View {
    let icon: String
    var iconColor: Color = .gray // Default color
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 30, alignment: .center)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary.opacity(0.8))

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onTapGesture {
             print("\(title) provider tapped")
             // TODO: Implement navigation or action
         }
    }
}

// MARK: - Preview Provider
struct HomeScreenView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeScreenView()
                .modelContainer(for: [Folder.self, ScannedDocument.self])
        }
    }
}
//    static var previews: some View {
//        HomeScreenView(folders: [
//            Folder(name: "Personal", iconName: "folder.fill", colorHex: "#FFA500"),
//            Folder(name: "Work", iconName: "folder.fill", colorHex: "#007AFF")
//          ])
//            // --- IMPORTANT for Previews with SwiftData ---
//            // Provide a model container. Use inMemory: true so preview data
//            // doesn't persist between launches and doesn't interfere with real data.
//            // You can also add sample data here for previewing.
//            .modelContainer(previewContainer) // Use shared preview container
//    }
//
//    // Helper for creating sample data and the container for previews
//    @MainActor static var previewContainer: ModelContainer = {
//        let schema = Schema([
//            Folder.self,
//            ScannedDocument.self,
//        ])
//        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
//        do {
//            let container = try ModelContainer(for: schema, configurations: [configuration])
//            // Add sample data
//            let sampleFolder1 = Folder(name: "Bills")
//            let sampleFolder2 = Folder(name: "Personal")
//            container.mainContext.insert(sampleFolder1)
//            container.mainContext.insert(sampleFolder2)
//            // Add sample documents if needed and link them to folders
//            return container
//        } catch {
//            fatalError("Failed to create model container for preview: \(error)")
//        }
//    }()

