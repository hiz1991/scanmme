import SwiftUI
import PDFKit // For PDFDocument operations
import VisionKit // For VNDocumentCameraScan
import Vision // For OCR
import QuickLook // For QLPreviewController
import CoreSpotlight // For Spotlight indexing
import UniformTypeIdentifiers // For UTType
import SwiftData

// MARK: - Activity View Representable (for Share Sheet)
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - QuickLookView Representable (for PDF Preview)
struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookView

        init(_ parent: QuickLookView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}

// Enum for OCR Text Editor State
enum OcrEditorState {
    case disabled
    case enabled
}

// MARK: - Scan Edit View with Vision OCR
struct ScanEditView: View {

    // Access the ModelContext
    @Environment(\.modelContext) private var modelContext

    // Fetch available folders to populate the picker
    @Query(sort: \Folder.name) private var folders: [Folder]

    // State for the selected folder (using its ID for persistence stability)
    @State private var selectedFolderID: UUID? = nil // Start with no folder selected

    // Create an instance of the processor for the view's lifecycle
    // This processor now manages OCR state internally
    @StateObject private var ocrProcessor = YourOCRProcessor()

    // Input property for the scanned document
    let scannedDocument: VNDocumentCameraScan?

    // State for form inputs
    @State private var scanTitle: String = "Scan \(Date().formatted(date: .abbreviated, time: .shortened))"
    @State private var tags: String = ""
    // @State private var reminderDate = Date() // Uncomment if reminder feature is active

    // State related to OCR Editor UI
    @State private var ocrEditorState: OcrEditorState = .disabled

    // State holding the images extracted from the scan
    @State private var imagesToProcess: [CGImage] = []

    // State for tabs
    @State private var selectedTab = 0

    // State for Share Sheet
    @State private var showShareSheet = false
    @State private var pdfFileURLForSharing: URL? = nil

    // State for iCloud Saving Feedback
    @State private var isSavingToICloud = false
    @State private var showICloudSaveConfirmation = false
    @State private var iCloudSaveError: String? = nil

    // State for Local Saving Feedback
    @State private var isSavingLocally = false
    @State private var showLocalSaveConfirmation = false
    @State private var localSaveError: String? = nil

    // State for QuickLook Preview
    @State private var showQLPreview = false
    @State private var pdfPreviewURL: URL? = nil

    // Spotlight Domain Identifier
    private let spotlightDomainIdentifier = "me.scan.now.here.Scanner" // Replace with your unique identifier

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // --- Preview Area ---
                ZStack(alignment: .bottomTrailing) {
                    if !imagesToProcess.isEmpty {
                         Image(imagesToProcess[0], scale: 1.0, label: Text("Scanned Page 1"))
                             .resizable().aspectRatio(1.0, contentMode: .fit)
                             .frame(height: 250).cornerRadius(10)
                             .padding(.horizontal)
                             .padding(.bottom, 40) // Space for button
                     } else if scannedDocument == nil {
                         Rectangle().fill(Color(.systemGray4))
                             .aspectRatio(1.0, contentMode: .fit).frame(height: 250)
                             .cornerRadius(10).overlay(Text("No Scan Data").foregroundColor(.gray))
                             .padding(.horizontal)
                             .padding(.bottom, 40)
                     } else {
                         ProgressView("Extracting Images...")
                             .frame(height: 250)
                             .padding(.horizontal)
                             .padding(.bottom, 40)
                     }

                    // --- Preview PDF Button ---
                    Button {
                        prepareAndShowQLPreview()
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Preview PDF")
                    }
                    .buttonStyle(.bordered)
                    .padding([.bottom, .trailing])
                    .disabled(scannedDocument == nil || imagesToProcess.isEmpty)
                }
                // --- END Preview Area ---

                // --- Placeholder Buttons ---
                 HStack(spacing: 12) {
                     InfoButton(label: "Category", value: "Not Set", color: .blue)
                     InfoButton(label: "Events", value: "None Detected", color: .green)
                 }
                 .padding(.horizontal)
                 HStack(spacing: 12) {
                     InfoButton(label: "Keep", value: "Indefinitely", color: .purple)
                     InfoButton(label: "Language", value: "Auto", color: .red)
                 }
                 .padding(.horizontal).padding(.bottom)
                 // --- END BUTTONS ---


                // Tabs for switching between Details and OCR Text
                Picker("View", selection: $selectedTab) {
                    Text("Details").tag(0)
                    Text("OCR Text").tag(1)
                }
                .pickerStyle(.segmented).padding(.horizontal)


                // Tab Content Area
                if selectedTab == 0 {
                    // Details Tab Content (Form fields)
                    VStack(spacing: 15) {
                        TextField("Title", text: $scanTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Picker("Folder", selection: $selectedFolderID) {
                            Text("Unfiled").tag(UUID?.none) // Option for no folder
                            ForEach(folders) { folder in
                                Text(folder.name).tag(folder.id as UUID?) // Tag with the folder's ID
                            }
                        }
                       .padding(.vertical, 5).background(Color(.systemGray6)).cornerRadius(8)
                        TextField("Tags (comma separated)", text: $tags)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        // DatePicker("Reminder", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute]) // Uncomment if needed
                    }
                    .padding()

                } else {
                    // OCR Text Tab Content
                    VStack(alignment: .leading, spacing: 10) {
                        // Show progress, error, or text editor based on OCR state FROM THE PROCESSOR
                        if ocrProcessor.ocrInProgress {
                            ProgressView("Performing OCR...")
                                .frame(height: 200).frame(maxWidth: .infinity)
                        } else if let errorMsg = ocrProcessor.ocrError {
                            VStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                Text("OCR Error:")
                                Text(errorMsg).font(.caption).foregroundColor(.gray)
                            }
                            .frame(height: 200).frame(maxWidth: .infinity)
                        } else {
                            // Bind TextEditor directly to the processor's ocrText
                            TextEditor(text: $ocrProcessor.ocrText)
                                .frame(height: 200)
                                .border(Color(.systemGray5), width: 1)
                                .cornerRadius(5)
                                .disabled(ocrEditorState == .disabled)
                                .foregroundColor(ocrProcessor.ocrText.isEmpty || ocrProcessor.ocrText == "No text recognized." || ocrProcessor.ocrText.starts(with: "[OCR Error") ? .gray : .primary)
                                .background(ocrEditorState == .disabled ? Color.clear : Color(.systemGray6))
                        }

                        // Show "Edit Text" button conditionally
                        if ocrEditorState == .disabled &&
                           !ocrProcessor.ocrInProgress &&
                           ocrProcessor.ocrError == nil &&
                           !ocrProcessor.ocrText.isEmpty &&
                           ocrProcessor.ocrText != "No text recognized." &&
                           !ocrProcessor.ocrText.starts(with: "[OCR Error") {
                            Button("Edit Text") { ocrEditorState = .enabled }.padding(.top, 5)
                        }
                    }
                    .padding()
                }

                // --- Save Buttons and Feedback ---
                VStack(spacing: 10) {
                    // iCloud Save Button
                    Button { saveToICloud() } label: {
                        HStack { Image(systemName: "icloud.and.arrow.up"); Text(isSavingToICloud ? "Saving to iCloud..." : "Save to iCloud") }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSavingToICloud || isSavingLocally || imagesToProcess.isEmpty)

                    // Local Save Button
                    Button { saveLocally() } label: {
                        HStack { Image(systemName: "folder.fill.badge.plus"); Text(isSavingLocally ? "Saving Locally..." : "Save Locally") }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSavingLocally || isSavingToICloud || imagesToProcess.isEmpty)

                    // Display Saving Feedback
                    if showICloudSaveConfirmation {
                        Text("Saved to iCloud Successfully!").font(.caption).foregroundColor(.green)
                    } else if let error = iCloudSaveError {
                        Text("iCloud Save Error: \(error)").font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                    }

                    if showLocalSaveConfirmation {
                        Text("Saved Locally Successfully!").font(.caption).foregroundColor(.green)
                    } else if let error = localSaveError {
                        Text("Local Save Error: \(error)").font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                // --- END Save Buttons ---

                Spacer()
            } // End VStack
        } // End ScrollView
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Edit Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    // Share button
                    Button {
                        sharePDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(imagesToProcess.isEmpty || isSavingToICloud || isSavingLocally)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                // Show "Done" button only when editing OCR text
                if ocrEditorState == .enabled {
                    Button("Done") { ocrEditorState = .disabled; hideKeyboard() }
                }
            }
        }
        .onAppear {
            // Process the scanned document if images aren't already loaded
            if imagesToProcess.isEmpty && scannedDocument != nil {
                 processScannedDocument()
            }
            // Set default folder if none selected and folders are loaded
             Task { @MainActor in // Ensure UI-related state update happens on main thread
                 if selectedFolderID == nil, let unfiled = folders.first(where: { $0.name == "Unfiled" }) {
                      selectedFolderID = unfiled.id
                 } else if selectedFolderID == nil && !folders.isEmpty {
                     // Fallback to the first available folder if "Unfiled" doesn't exist
                     selectedFolderID = folders[0].id
                 }
             }
        }
        // Sheet Modifier for Share Sheet presentation
        .sheet(isPresented: $showShareSheet, onDismiss: cleanupTemporaryFileForSharing) {
            if let url = pdfFileURLForSharing {
                ActivityView(activityItems: [url])
            } else {
                Text("Error preparing share data.")
            }
        }
        // Sheet Modifier for QuickLook
        .sheet(isPresented: $showQLPreview, onDismiss: cleanupTemporaryFileForPreview) {
            if let url = pdfPreviewURL {
                QuickLookView(url: url)
                    .ignoresSafeArea()
            } else {
                Text("Error preparing preview data.")
            }
        }
    }

    // MARK: - Document Processing

    /// Extracts images from the VNDocumentCameraScan and triggers OCR processing.
    /// Extracts images from the VNDocumentCameraScan and triggers OCR processing.
    /// Extracts images from the VNDocumentCameraScan and triggers OCR processing.
        private func processScannedDocument() {
            guard let scan = scannedDocument else {
                // Update processor state directly on main thread if no scan
                Task { @MainActor in
                    ocrProcessor.ocrError = "No scan data available."
                    ocrProcessor.ocrText = ""
                    ocrProcessor.ocrInProgress = false
                }
                print("Error: No scan data provided to processScannedDocument.")
                return
            }
            print("Processing scanned document with \(scan.pageCount) pages.")

            // Start OCR Processor's progress indicator on main thread
            Task { @MainActor in
                ocrProcessor.ocrInProgress = true
                ocrProcessor.ocrError = nil
                ocrProcessor.ocrText = "Extracting images..."
            }

            // Perform extraction on background thread using Swift Concurrency
            Task.detached(priority: .userInitiated) {
                // Use a temporary mutable array inside the Task
                var mutableExtractedImages: [CGImage] = []
                let context = CIContext(options: nil) // Create context once

                for i in 0..<scan.pageCount {
                    let originalImage = scan.imageOfPage(at: i)
                    var convertedCGImage: CGImage? = nil

                    // Attempt 1: Direct .cgImage property
                    if let cgImage = originalImage.cgImage {
                        convertedCGImage = cgImage
                    } else {
                        // Attempt 2: Fallback using CIImage rendering
                        print("Warning: Page \(i+1) .cgImage was nil, attempting CIImage conversion.")
                        if let ciImage = CIImage(image: originalImage),
                           let cgImg = context.createCGImage(ciImage, from: ciImage.extent) {
                            convertedCGImage = cgImg
                            print("Successfully converted page \(i+1) via CIImage.")
                        } else {
                            print("Error: Could not convert page \(i + 1) to CGImage using direct or CIImage methods.")
                        }
                    }

                    // If conversion succeeded, add to temporary array
                    if let finalCGImage = convertedCGImage {
                        mutableExtractedImages.append(finalCGImage) // Modify the temporary array
                    }
                } // End loop

                // Create an immutable copy to safely pass to the MainActor context
                let extractedImages = mutableExtractedImages // Now 'extractedImages' is a 'let' constant

                // Update UI state and trigger OCR on main thread
                await MainActor.run {
                    // Check the IMMUTABLE extractedImages constant
                    if !extractedImages.isEmpty {
                        // Assign to the @State property
                        self.imagesToProcess = extractedImages // Pass Sendable immutable data across boundary
                        print("Extracted \(self.imagesToProcess.count) images successfully.")
                        // Trigger OCR with the extracted images
                        self.ocrProcessor.performOCROnImages(images: self.imagesToProcess)
                    } else if scan.pageCount > 0 { // Read captured 'scan'
                        // Handle case where NO images could be extracted AT ALL after trying conversions
                        self.ocrProcessor.ocrText = "Error: Could not convert scan data to processable images."
                        self.ocrProcessor.ocrError = "Image data conversion failed for all pages."
                        self.ocrProcessor.ocrInProgress = false
                        print("Error: No images extracted from scan after attempting conversions.")
                    } else {
                        // Handle case where scan.pageCount was 0 initially
                        print("Scan had 0 pages.")
                        self.ocrProcessor.ocrInProgress = false
                    }
                } // End MainActor.run
            } // End Task.detached
        }

    // In ScanEditView struct:

        // Function to generate PDF data using ONLY the pages kept after OCR filtering
        private func generatePDFData(scannedDocument: VNDocumentCameraScan) -> Data? {
            let pdfDocument = PDFDocument()

            // Get the list of indices kept by the processor
            // Ensure OCR is complete before calling this, indicated by ocrProcessor.ocrInProgress == false
            let indicesToInclude = ocrProcessor.keptPageIndices

            guard !ocrProcessor.ocrInProgress else {
                print("Error: generatePDFData called while OCR is still in progress.")
                // Handle this case - maybe return nil or show an alert
                return nil
            }

            print("Generating PDF using kept indices: \(indicesToInclude.sorted()) from original \(scannedDocument.pageCount) pages.")

            // Iterate through the kept indices (sorted to maintain order)
                 for index in indicesToInclude.sorted() {
                     // Validate index against the original document bounds
                     guard index >= 0 && index < scannedDocument.pageCount else {
                         print("Warning: Kept index \(index) is out of bounds for original document page count \(scannedDocument.pageCount). Skipping.")
                         continue
                     }

                     // Get the image for the valid kept index - Direct assignment
                     let image: UIImage = scannedDocument.imageOfPage(at: index) // <-- CORRECTED LINE

                     // Now try to create the PDFPage (this initializer *can* fail, so keep 'if let')
                     if let pdfPage = PDFPage(image: image) {
                         // Insert page into the new PDF document
                         pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
                     } else {
                         print("Error: Could not create PDFPage from image at original index \(index)")
                     }
                 } // End loop

            // Handle cases where no pages ended up in the PDF
            if pdfDocument.pageCount == 0 {
                if indicesToInclude.isEmpty {
                    print("Info: No pages were kept after filtering. Generating empty PDF.")
                } else {
                    print("Error: Pages were kept by OCR, but none were successfully added to the PDF.")
                    // Consider returning nil or specific error data
                    // For now, we return an empty PDF's data representation
                }
            }

            // Return the data representation of the generated PDF
            return pdfDocument.dataRepresentation()
        }

        // --- Ensure you call generatePDFData at the right time ---
        // Make sure functions like saveMetadata() or shareDocument() are called *after*
        // the ocrProcessor has finished (e.g., after the loading indicator disappears).
        // The existing structure where processing happens in .onAppear and buttons are
        // enabled/disabled based on ocrInProgress should handle this.

        // Example within a save function:
        /*
        func triggerSave() {
            guard !ocrProcessor.ocrInProgress else {
                print("Cannot save yet, OCR processing.")
                // Show alert or disable button
                return
            }
            // ... proceed with saving ...
            saveMetadata() // This will call the updated generatePDFData
        }
        */

    /// Generates a temporary PDF file.
    private func generateTemporaryPDF(purpose: String) -> URL? {
        guard let pdfData = generatePDFData(scannedDocument: scannedDocument!) else {
            // Update error state on MainActor as this might be called from background indirectly
             Task { @MainActor in
                 self.localSaveError = "Could not generate PDF data for \(purpose)."
                 self.iCloudSaveError = "Could not generate PDF data for \(purpose)."
                 self.showLocalSaveConfirmation = false
                 self.showICloudSaveConfirmation = false
             }
            return nil
        }

        let tempDirectoryURL = FileManager.default.temporaryDirectory
        let sanitizedTitleComponent = scanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                             .replacingOccurrences(of: "[^a-zA-Z0-9_-]+", with: "_", options: .regularExpression)
                                             .prefix(50)
        let baseFilename = sanitizedTitleComponent.isEmpty ? "Scan" : String(sanitizedTitleComponent)
        let pdfFilename = "\(baseFilename)-\(purpose)-\(UUID().uuidString).pdf"
        let pdfFileURL = tempDirectoryURL.appendingPathComponent(pdfFilename)

        do {
            try pdfData.write(to: pdfFileURL, options: .atomic)
            print("Generated temporary PDF for \(purpose) at: \(pdfFileURL.path)")
            return pdfFileURL
        } catch {
            print("Error writing temporary PDF for \(purpose): \(error)")
            // Update error state on MainActor
             Task { @MainActor in
                 self.localSaveError = "Could not prepare file for \(purpose)."
                 self.iCloudSaveError = "Could not prepare file for \(purpose)."
                 self.showLocalSaveConfirmation = false
                 self.showICloudSaveConfirmation = false
             }
            return nil
        }
    }

    /// Action for the Share button.
    private func sharePDF() {
        Task { @MainActor in clearPreviousErrors() } // Clear errors on main thread first
        if let url = generateTemporaryPDF(purpose: "sharing") { // generateTemporaryPDF now handles its own errors on main thread
            self.pdfFileURLForSharing = url
            self.showShareSheet = true
        }
        // Error display is handled by state variables updated within generateTemporaryPDF
    }

    /// Action for the Preview button.
    private func prepareAndShowQLPreview() {
         Task { @MainActor in clearPreviousErrors() } // Clear errors on main thread first
         if let url = generateTemporaryPDF(purpose: "preview") { // generateTemporaryPDF handles errors on main thread
             self.pdfPreviewURL = url
             self.showQLPreview = true
         }
         // Error display handled by state variables
    }

    /// Cleans up the temporary file used for sharing.
    private func cleanupTemporaryFileForSharing() {
        if let url = pdfFileURLForSharing {
            // File operations can be done in background
            Task.detached(priority: .background) {
                do {
                    try FileManager.default.removeItem(at: url)
                    print("Cleaned up temporary PDF for sharing: \(url.lastPathComponent)")
                } catch {
                    print("Error cleaning up temporary sharing PDF: \(error)")
                }
            }
            pdfFileURLForSharing = nil // Reset state var (on main thread is fine)
        }
    }

    /// Cleans up the temporary file used for previewing.
    private func cleanupTemporaryFileForPreview() {
        if let url = pdfPreviewURL {
             // File operations can be done in background
             Task.detached(priority: .background) {
                 do {
                     try FileManager.default.removeItem(at: url)
                     print("Cleaned up temporary PDF for preview: \(url.lastPathComponent)")
                 } catch {
                     print("Error cleaning up temporary preview PDF: \(error)")
                 }
             }
            pdfPreviewURL = nil // Reset state var
        }
    }


    // MARK: - Saving Logic (Local & iCloud) - CORRECTED

    /// Gets the URL for the app's local Documents directory.
    private func getLocalDocumentsURL() -> URL? {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error getting local documents directory.")
            // Ensure error state is updated on main thread if called from background
            Task { @MainActor in self.localSaveError = "Cannot access local storage." }
            return nil
        }
        return url
    }

    /// Gets the URL for the Documents directory within the app's default iCloud container.
    private func getICloudDocumentsURL() -> URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            print("iCloud container URL not found (is iCloud Drive enabled for the app?).")
            // Ensure error state is updated on main thread if called from background
            Task { @MainActor in self.iCloudSaveError = "iCloud Drive unavailable or not configured." }
            return nil
        }
        let documentsURL = containerURL.appendingPathComponent("Documents")
        // Synchronous check/creation before async work is fine
        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            do {
                try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                print("Created iCloud Documents directory.")
            } catch {
                print("Error creating iCloud Documents directory: \(error)")
                // Ensure error state is updated on main thread if called from background
                Task { @MainActor in self.iCloudSaveError = "Could not create iCloud folder." }
                return nil
            }
        }
        return documentsURL
    }

    /// Clears previous save error/confirmation messages. Must run on MainActor.
    @MainActor private func clearPreviousErrors() {
         iCloudSaveError = nil; showICloudSaveConfirmation = false
         localSaveError = nil; showLocalSaveConfirmation = false
     }

    /// Saves the generated PDF to the app's iCloud Documents directory AND indexes it in Spotlight.
    private func saveToICloud() {
        guard !isSavingToICloud && !isSavingLocally else { return }
        guard !imagesToProcess.isEmpty else {
            // Update state directly (safe for @State)
            self.iCloudSaveError = "No scanned content to save."
            return
        }

        // Update state on MainActor before starting background task
        Task { @MainActor in
             isSavingToICloud = true
              clearPreviousErrors() // Call MainActor func
        }

        // Capture state needed for the background task
        let currentTitle = self.scanTitle
        let currentTags = self.tags
        // ocrProcessor.ocrText will be read within the Task

        // Use Task for async background work
        Task.detached(priority: .userInitiated) {
            guard let iCloudDocumentsURL = await getICloudDocumentsURL() else {
                // Error set in getICloudDocumentsURL, ensure UI state is updated
                await MainActor.run { isSavingToICloud = false }
                return
            }
            guard let pdfData = await generatePDFData(scannedDocument: scannedDocument!) else {
                // Error likely set in generateTemporaryPDF via generatePDFData
                // Ensure UI state update happens on main thread
                 await MainActor.run { isSavingToICloud = false }
                return
            }
            // Assuming determineFinalURL is safe for background
            let destinationURL = await determineFinalURL(in: iCloudDocumentsURL)

            do {
                // --- Perform File I/O ---
                try pdfData.write(to: destinationURL, options: .atomic)
                print("Saved PDF to iCloud: \(destinationURL.path)")

                // --- Fetch OCR Text ---
                // Read the property. If ocrProcessor is @MainActor or ocrText requires it, wrap in await MainActor.run
                let finalText = await ocrProcessor.ocrText

                // --- Save Metadata & Index ---
                await saveMetadata(fileName: destinationURL.path, storageLocation: "iCloud", finalOcrText: finalText) // Handles its own MainActor switch internally
                await indexFileInSpotlight(fileURL: destinationURL, title: currentTitle, ocrText: finalText, tags: currentTags) // Assuming this is safe for background or handles its own switch

                // --- Update UI on Main Thread ---
                await MainActor.run {
                    isSavingToICloud = false
                    showICloudSaveConfirmation = true
                    // Hide confirmation after delay using a nested Task
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                        if showICloudSaveConfirmation && !isSavingToICloud { // Check state validity
                            showICloudSaveConfirmation = false
                        }
                    }
                }
            } catch {
                print("Error writing PDF to iCloud: \(error)")
                let errorDesc = error.localizedDescription
                // --- Update UI on Main Thread (Error Case) ---
                await MainActor.run {
                    iCloudSaveError = "Save failed: \(errorDesc)"
                    isSavingToICloud = false
                }
            }
        } // End Task
    }

    /// Saves the generated PDF to the app's local Documents directory AND indexes it in Spotlight.
    private func saveLocally() {
        guard !isSavingLocally && !isSavingToICloud else { return }
        guard !imagesToProcess.isEmpty else {
             // Update state directly (safe for @State)
            self.localSaveError = "No scanned content to save."
            return
        }

         // Update state on MainActor before starting background task
         Task { @MainActor in
             isSavingLocally = true
              clearPreviousErrors() // Call MainActor func
         }

        // Capture state needed for the background task
        let currentTitle = self.scanTitle
        let currentTags = self.tags
        // ocrProcessor.ocrText will be read within the Task

        // Use Task for async background work
        Task.detached(priority: .userInitiated) {
            guard let localDocumentsURL = await getLocalDocumentsURL() else {
                // Error set in getLocalDocumentsURL, ensure UI state is updated
                await MainActor.run { isSavingLocally = false }
                return
            }
            guard let pdfData = await generatePDFData(scannedDocument: scannedDocument!) else {
                 // Error likely set in generateTemporaryPDF via generatePDFData
                 // Ensure UI state update happens on main thread
                 await MainActor.run { isSavingLocally = false }
                return
            }
             // Assuming determineFinalURL is safe for background
            let destinationURL = await determineFinalURL(in: localDocumentsURL)

            do {
                // --- Perform File I/O ---
                try pdfData.write(to: destinationURL, options: .atomic)
                print("Successfully saved PDF locally: \(destinationURL.path)")

                // --- Fetch OCR Text ---
                let finalText = await ocrProcessor.ocrText

                // --- Save Metadata & Index ---
                await saveMetadata(fileName: destinationURL.path, storageLocation: "local", finalOcrText: finalText) // Handles its own MainActor switch internally
                await indexFileInSpotlight(fileURL: destinationURL, title: currentTitle, ocrText: finalText, tags: currentTags) // Assuming this is safe for background or handles its own switch

                // --- Update UI on Main Thread ---
                await MainActor.run {
                    isSavingLocally = false
                    showLocalSaveConfirmation = true
                     // Hide confirmation after delay using a nested Task
                     Task { @MainActor in
                         try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                         if showLocalSaveConfirmation && !isSavingLocally { // Check state validity
                             showLocalSaveConfirmation = false
                         }
                     }
                }
            } catch {
                print("Error writing PDF locally: \(error)")
                 let errorDesc = error.localizedDescription
                // --- Update UI on Main Thread (Error Case) ---
                await MainActor.run {
                    localSaveError = "Save failed: \(errorDesc)"
                    isSavingLocally = false
                }
            }
        } // End Task
    }


    /// Saves the document metadata using SwiftData
    private func saveMetadata(fileName: String, storageLocation: String, finalOcrText: String) {
        // Find the selected folder object based on the stored ID
        // This find operation on 'folders' (@Query) should be done on the MainActor
        Task { @MainActor in
            let selectedFolderObject = folders.first { $0.id == selectedFolderID }

            // Create the ScannedDocument object
            let newDocument = ScannedDocument(
                title: scanTitle, // Read current title (already captured or read on main actor)
                fileName: fileName,
                storageLocation: storageLocation,
                ocrText: finalOcrText,
                tags: tags, // Read current tags
                folder: selectedFolderObject,
//                scannedDate: Date()
            )

            // Insert into the context on the MainActor
            modelContext.insert(newDocument)
            print("Inserted document metadata into context: \(newDocument.title)")
            // SwiftData auto-save is usually sufficient, but explicit save can be added if needed:
            // do {
            //     try modelContext.save()
            // } catch {
            //     print("Error explicitly saving metadata: \(error)")
            // }
        }
    }

    /// Helper function to determine the final unique URL for saving a file.
    /// Safe to call from background thread as it only uses Foundation APIs.
    private func determineFinalURL(in directoryURL: URL) -> URL {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        // Read scanTitle safely - preferably pass as argument if called from background
        // Or ensure read happens before background task starts. Assuming capture is okay here.
        let sanitizedTitle = scanTitle
            .components(separatedBy: invalidChars)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let baseFilename = sanitizedTitle.isEmpty ? "Scan-\(UUID().uuidString)" : sanitizedTitle
        var finalFilename = "\(baseFilename).pdf"
        var destinationURL = directoryURL.appendingPathComponent(finalFilename)
        var counter = 1

        while FileManager.default.fileExists(atPath: destinationURL.path) {
             finalFilename = "\(baseFilename)-\(counter).pdf"
             destinationURL = directoryURL.appendingPathComponent(finalFilename)
             counter += 1
             if counter > 100 {
                  print("Warning: Exceeded 100 attempts to find unique filename for \(baseFilename)")
                  finalFilename = "\(baseFilename)-\(UUID().uuidString).pdf"
                  destinationURL = directoryURL.appendingPathComponent(finalFilename)
                  break
              }
        }
        return destinationURL
    }

    /// Indexes the saved PDF file and its metadata using CoreSpotlight.
    /// Can be called from background thread.
    private func indexFileInSpotlight(fileURL: URL, title: String, ocrText: String, tags: String) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.pdf)
        attributeSet.title = title

        if !ocrText.isEmpty && !ocrText.starts(with: "Processing") && !ocrText.starts(with: "[OCR Error") && ocrText != "No text recognized." {
            attributeSet.contentDescription = ocrText
        } else {
            attributeSet.contentDescription = nil
        }

        attributeSet.keywords = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        attributeSet.contentURL = fileURL // URL of the *saved* file

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: fileURL.path,
            domainIdentifier: spotlightDomainIdentifier,
            attributeSet: attributeSet
        )

        // Indexing API is asynchronous itself
        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error = error {
                print("Error indexing item in Spotlight: \(error.localizedDescription) for \(fileURL.path)")
            } else {
                print("Successfully indexed item: \(title) - \(fileURL.path)")
            }
        }
    }

    // Helper function to dismiss the keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Helper View for Dashed Outline Buttons
struct InfoButton: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        Button { print("\(label) / \(value) button tapped (placeholder)") } label: {
            VStack(spacing: 2) {
                Text(label).font(.caption).italic().foregroundColor(.gray)
                Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    .lineLimit(1).truncationMode(.tail)
            }
            .padding(.vertical, 10).frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4])))
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
         .buttonStyle(.plain)
    }
}

// MARK: - Preview Provider
struct ScanEditView_Previews: PreviewProvider {
    @MainActor static var previewContainer: ModelContainer = {
         let schema = Schema([ Folder.self, ScannedDocument.self ])
         let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
         do {
             let container = try ModelContainer(for: schema, configurations: [configuration])
             // Insert sample folders
             container.mainContext.insert(Folder(name: "Bills"))
             container.mainContext.insert(Folder(name: "Personal"))
             container.mainContext.insert(Folder(name: "Work"))
             container.mainContext.insert(Folder(name: "Unfiled"))
             return container
         } catch {
             fatalError("Failed to create preview model container: \(error)")
         }
     }()

    static var previews: some View {
        NavigationView {
            // Provide nil for scannedDocument for previewing the initial state
            ScanEditView(scannedDocument: nil)
                .modelContainer(previewContainer) // Inject the container
                // Provide a mock OCR Processor if needed for preview states
                // .environmentObject(MockYourOCRProcessor())
        }
    }
}


// Assume YourOCRProcessor exists and has the necessary @Published properties:
// class YourOCRProcessor: ObservableObject {
//     @Published var ocrInProgress: Bool = false
//     @Published var ocrError: String? = nil
//     @Published var ocrText: String = ""
//     @Published var recognizedTexts: [String] = [] // Or whatever structure you use
//     // ... other properties like indicesToRemove ...
//
//     @MainActor // Ensure UI updates happen on main thread
//     func performOCROnImages(images: [CGImage]) {
//         // Implementation using Vision to process images
//         // Update @Published properties accordingly
//     }
// }
