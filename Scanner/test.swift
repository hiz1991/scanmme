import SwiftUI
import PDFKit // For PDF Generation if needed later
import VisionKit // For VNDocumentCameraScan
import Vision // For OCR
import QuickLook // For PDF Preview
import CoreSpotlight // For Spotlight indexing
import UniformTypeIdentifiers // For UTType
import SwiftData // For @Query, @Environment, Models

// MARK: - SwiftData Model Definitions (Assumed)
// Ensure these @Model classes are defined elsewhere in your project
/*
 @Model final class Folder { ... } // As defined previously
 @Model final class ScannedDocument { ... } // As defined previously
*/

// MARK: - Activity View Representable (for Share Sheet)
// Wraps UIActivityViewController for SwiftUI
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
// Wraps QLPreviewController for SwiftUI
struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookView
        init(_ parent: QuickLookView) { self.parent = parent }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            parent.url as QLPreviewItem
        }
    }
}


// Enum for OCR Text Editor State
enum OcrEditorState {
    case disabled
    case enabled
}

// Default folder options constant (can be removed if Picker only uses fetched Folders)
// private let defaultFolderOptions = ["Bills", "Personal", "Work", "Unfiled"]

// MARK: - Scan Edit View with Vision OCR
struct ScanEditView: View {

    // --- SwiftData ---
    @Environment(\.modelContext) private var modelContext
    // Fetch available folders to populate the picker
    @Query(sort: \Folder.name) private var folders: [Folder]
    // State for the selected folder (using its ID for persistence stability)
    @State private var selectedFolderID: UUID? = nil // Start with no folder selected

    // --- Input ---
    let scannedDocument: VNDocumentCameraScan?

    // --- Form State ---
    @State private var scanTitle: String = "Scan \(Date().formatted(date: .abbreviated, time: .shortened))"
    // Removed redundant: @State private var selectedFolder = "Unfiled"
    @State private var tags: String = ""
    @State private var reminderDate = Date()

    // --- OCR State ---
    @State private var ocrText: String = "Processing scan..."
    @State private var ocrInProgress: Bool = false
    @State private var ocrError: String? = nil
    @State private var ocrEditorState: OcrEditorState = .disabled
    @State private var imagesToProcess: [CGImage] = []
    @State private var recognizedTexts: [String] = [] // Holds results from OCR

    // --- UI State ---
    @State private var selectedTab = 0 // Details = 0, OCR = 1

    // --- Share Sheet State ---
    @State private var showShareSheet = false
    @State private var pdfFileURLForSharing: URL? = nil

    // --- iCloud Saving State ---
    @State private var isSavingToICloud = false
    @State private var showICloudSaveConfirmation = false
    @State private var iCloudSaveError: String? = nil

    // --- Local Saving State ---
    @State private var isSavingLocally = false
    @State private var showLocalSaveConfirmation = false
    @State private var localSaveError: String? = nil

    // --- QuickLook State ---
    @State private var showQLPreview = false
    @State private var pdfPreviewURL: URL? = nil

    // --- Spotlight ---
    private let spotlightDomainIdentifier = "me.scan.now.here.Scanner" // TODO: Replace with your actual identifier base

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // --- Preview Area ---
                ZStack(alignment: .bottomTrailing) {
                    // Image Preview
                    if !imagesToProcess.isEmpty {
                         Image(imagesToProcess[0], scale: 1.0, label: Text("Scanned Page 1"))
                             .resizable().aspectRatio(1.0, contentMode: .fit)
                             .frame(height: 250).cornerRadius(10)
                             .padding(.horizontal)
                             .padding(.bottom, 40) // Space for button
                    } else if scannedDocument == nil {
                         Rectangle().fill(Color(.systemGray4)) // Placeholder
                             .aspectRatio(1.0, contentMode: .fit).frame(height: 250)
                             .cornerRadius(10).overlay(Text("No Scan Data").foregroundColor(.gray))
                             .padding(.horizontal)
                             .padding(.bottom, 40)
                    } else {
                         ProgressView("Processing Scan...") // Loading
                             .frame(height: 250)
                             .padding(.horizontal)
                             .padding(.bottom, 40)
                    }

                    // Preview PDF Button
                    Button {
                        prepareAndShowQLPreview()
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Preview PDF")
                    }
                    .buttonStyle(.bordered)
                    .padding([.bottom, .trailing])
                    .disabled(scannedDocument == nil)
                }
                // --- END Preview Area ---


                 // --- Info Buttons ---
                 HStack(spacing: 12) {
                     InfoButton(label: "Category", value: "Personal", color: .blue)
                     InfoButton(label: "Events", value: "5th of May 2025", color: .green)
                 }
                 .padding(.horizontal)
                 HStack(spacing: 12) {
                     InfoButton(label: "Keep", value: "Months", color: .purple)
                     InfoButton(label: "Language", value: "English", color: .red)
                 }
                 .padding(.horizontal).padding(.bottom)
                 // --- END Info Buttons ---

                // --- Tab Selector ---
                Picker("View", selection: $selectedTab) {
                    Text("Details").tag(0)
                    Text("OCR Text").tag(1)
                }
                .pickerStyle(.segmented).padding(.horizontal)


                // --- Tab Content ---
                if selectedTab == 0 {
                    // Details Tab
                    VStack(spacing: 15) {
                         TextField("Title", text: $scanTitle)
                             .textFieldStyle(RoundedBorderTextFieldStyle())

                         // Folder Picker using SwiftData @Query result
                         Picker("Folder", selection: $selectedFolderID) {
                             Text("Unfiled").tag(UUID?.none) // Option for no folder
                             ForEach(folders) { folder in
                                 Text(folder.name).tag(folder.id as UUID?) // Tag with ID
                             }
                         }
                         .padding(.vertical, 5).background(Color(.systemGray6)).cornerRadius(8)

                         TextField("Tags (comma separated)", text: $tags)
                             .textFieldStyle(RoundedBorderTextFieldStyle())
                         DatePicker("Reminder", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    .padding()

                } else {
                    // OCR Text Tab
                    VStack(alignment: .leading, spacing: 10) {
                        if ocrInProgress {
                             ProgressView("Performing OCR...")
                                .frame(height: 200).frame(maxWidth: .infinity)
                        } else if let errorMsg = ocrError {
                            VStack { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red); Text("OCR Error:"); Text(errorMsg).font(.caption).foregroundColor(.gray) }
                            .frame(height: 200).frame(maxWidth: .infinity)
                        } else {
                            TextEditor(text: $ocrText)
                                 .frame(height: 200).border(Color(.systemGray5), width: 1).cornerRadius(5)
                                 .disabled(ocrEditorState == .disabled)
                                 .foregroundColor(ocrText.starts(with: "Processing scan...") || ocrText == "No text recognized." ? .gray : .primary)
                                 .background(ocrEditorState == .disabled ? Color.clear : Color(.systemGray6))
                        }
                        // Edit Text Button
                         if ocrEditorState == .disabled && !ocrInProgress && ocrError == nil && !ocrText.isEmpty && ocrText != "No text recognized." && !ocrText.starts(with: "Processing scan...") {
                             Button("Edit Text") { ocrEditorState = .enabled }.padding(.top, 5)
                         }
                    }
                    .padding()
                }
                // --- End Tab Content ---

                // --- Save Buttons and Feedback ---
                VStack(spacing: 10) {
                    // iCloud Save Button
                    Button { saveToICloud() } label: {
                        HStack { Image(systemName: "icloud.and.arrow.up"); Text(isSavingToICloud ? "Saving to iCloud..." : "Save to iCloud") }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).disabled(isSavingToICloud || isSavingLocally || scannedDocument == nil)

                    // Local Save Button
                    Button { saveLocally() } label: {
                         HStack { Image(systemName: "iphone.and.arrow.down"); Text(isSavingLocally ? "Saving Locally..." : "Save Locally") }.frame(maxWidth: .infinity) // Corrected Icon
                    }
                    .buttonStyle(.bordered).disabled(isSavingLocally || isSavingToICloud || scannedDocument == nil)

                    // Feedback Area
                    if showICloudSaveConfirmation { Text("Saved to iCloud Successfully!").font(.caption).foregroundColor(.green) }
                    else if let error = iCloudSaveError { Text("iCloud Save Error: \(error)").font(.caption).foregroundColor(.red).multilineTextAlignment(.center) }

                    if showLocalSaveConfirmation { Text("Saved Locally Successfully!").font(.caption).foregroundColor(.green) }
                    else if let error = localSaveError { Text("Local Save Error: \(error)").font(.caption).foregroundColor(.red).multilineTextAlignment(.center) }
                }
                .padding(.horizontal)
                .padding(.bottom)
                // --- END Save Buttons ---

                Spacer() // Pushes content up
            } // End Root VStack
        } // End ScrollView
        .background(Color(.systemGray6).ignoresSafeArea()) // Background for the whole view
        .navigationTitle("Edit Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Share Button (Trailing)
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Button { sharePDF() } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(scannedDocument == nil || isSavingToICloud || isSavingLocally) // Disable if no data or saving
                }
            }
            // Done Button (Leading - conditional)
            ToolbarItem(placement: .navigationBarLeading) {
                 if ocrEditorState == .enabled {
                     Button("Done") { ocrEditorState = .disabled; hideKeyboard() }
                 }
            }
        }
        .onAppear {
            // Process scan when view appears if needed
            if imagesToProcess.isEmpty && scannedDocument != nil {
                 processScannedDocument()
            }
        }
        // Share Sheet Presentation
        .sheet(isPresented: $showShareSheet, onDismiss: {
            // Clean up temporary share file
            if let url = pdfFileURLForSharing {
                try? FileManager.default.removeItem(at: url) // Uncommented cleanup
                print("Cleaned up temporary PDF for sharing: \(url)")
                pdfFileURLForSharing = nil
            }
        }) {
            if let url = pdfFileURLForSharing { ActivityView(activityItems: [url]) }
            else { Text("Error preparing share data.") }
        }
        // QuickLook Presentation (Using fullScreenCover now)
        .fullScreenCover(isPresented: $showQLPreview, onDismiss: {
            // Clean up temporary preview file
            if let url = pdfPreviewURL {
                try? FileManager.default.removeItem(at: url) // Uncommented cleanup
                print("Cleaned up temporary PDF for preview: \(url)")
                pdfPreviewURL = nil
            }
        }) {
            if let url = pdfPreviewURL { QuickLookView(url: url).ignoresSafeArea() }
            else { Text("Error preparing preview data.") } // Corrected fallback
        }
    } // End body

    // MARK: - Document Processing and OCR Functions

    /// Extracts images from the `scannedDocument` and triggers OCR.
    private func processScannedDocument() {
        guard let scan = scannedDocument else { ocrError = "No scan data available."; ocrText = ""; return }
        print("Processing scanned document with \(scan.pageCount) pages.")
        var extractedImages: [CGImage] = []
        // Perform extraction on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<scan.pageCount {
                let originalImage = scan.imageOfPage(at: i)
                if let cgImage = originalImage.cgImage { extractedImages.append(cgImage) }
                else { print("Warning: Could not get CGImage for page \(i)") }
            }
            // Update UI on main thread
            DispatchQueue.main.async {
                self.imagesToProcess = extractedImages
                print("Extracted \(self.imagesToProcess.count) images.")
                // Check if images were extracted and trigger OCR
                if !self.imagesToProcess.isEmpty {
                    performOCROnImages(images: self.imagesToProcess)
                } else {
                    // Handle case where no images could be extracted
                    self.ocrText = "Error: Could not extract images from scan."
                    self.ocrError = "Image extraction failed."
                }
                // Removed stray semicolon and fixed placement of the if/else block
            }
        }
    }

    /// Performs OCR using the Vision framework on an array of CGImage objects.
    private func performOCROnImages(images: [CGImage]) {
        guard !images.isEmpty else { ocrError = "No images provided for OCR."; ocrText = ""; return }
        ocrInProgress = true; ocrError = nil; ocrText = "Performing OCR..."
        var recognizedTextAggregator: [Int: String] = [:]
        let group = DispatchGroup()

        // Reset recognizedTexts array for this OCR run
        self.recognizedTexts = []

        DispatchQueue.global(qos: .userInitiated).async {
            for (i, cgImage) in images.enumerated() {
                group.enter()
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                // Setup OCR Request
                let recognizeTextRequest = VNRecognizeTextRequest { (request, error) in
                    var pageText = ""
                    if let error = error {
                        print("Error performing OCR on page \(i): \(error.localizedDescription)")
                        pageText = "[OCR Error on page \(i + 1)]"
                    } else if let observations = request.results as? [VNRecognizedTextObservation] {
                        pageText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                    }
                    recognizedTextAggregator[i] = pageText
                    group.leave() // Leave group after OCR request completes
                }
                recognizeTextRequest.recognitionLevel = .accurate
                recognizeTextRequest.usesLanguageCorrection = true

                // Perform OCR Request
                do {
                    try requestHandler.perform([recognizeTextRequest])
                } catch {
                    print("Failed to perform text recognition request on page \(i): \(error)")
                    recognizedTextAggregator[i] = "[Request Error on page \(i + 1)]"
                    group.leave() // Ensure group is left even if perform fails
                }
                // Removed the second request handler and classification request logic
            }

            // After all requests in the group are done
            group.notify(queue: .main) {
                let finalCombinedText = recognizedTextAggregator.sorted(by: { $0.key < $1.key }).map({ $0.value }).joined(separator: "\n\n--- Page Break ---\n\n")
                let trimmedText = finalCombinedText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.ocrText = trimmedText.isEmpty ? "No text recognized." : trimmedText
                self.ocrInProgress = false

                // Store individual page results if needed (ensure this state var is desired)
                self.recognizedTexts = recognizedTextAggregator.sorted(by: { $0.key < $1.key }).map({ $0.value })
                print("Vision OCR on scanned images complete. Total pages processed: \(self.recognizedTexts.count)")
            }
        }
    }

    // MARK: - PDF Generation, Sharing, Previewing

    /// Generates PDF data from the scanned document.
    private func generatePDFData() -> Data? {
        guard let scan = scannedDocument, scan.pageCount > 0 else {
            print("No scanned document or pages available to generate PDF data.")
            return nil
        }
        let pdfDocument = PDFDocument()
        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            guard let pdfPage = PDFPage(image: image) else {
                print("Warning: Could not create PDFPage for page \(i)")
                continue
            }
            pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
        }
        return pdfDocument.dataRepresentation()
    }

    /// Generates a temporary PDF file. Reusable for sharing and previewing.
    private func generateTemporaryPDF(purpose: String) -> URL? {
        guard let pdfData = generatePDFData() else { return nil }
        let tempDirectoryURL = FileManager.default.temporaryDirectory
        let pdfFilename = "\(scanTitle.isEmpty ? "Scan" : scanTitle)-\(purpose)-\(UUID().uuidString).pdf"
        let pdfFileURL = tempDirectoryURL.appendingPathComponent(pdfFilename)
        do {
            try pdfData.write(to: pdfFileURL)
            return pdfFileURL
        } catch {
            print("Error writing temporary PDF for \(purpose): \(error)")
            // Update appropriate error state based on purpose if needed
            if purpose == "sharing" { self.localSaveError = "Could not prepare PDF for sharing." } // Example
            else if purpose == "preview" { self.localSaveError = "Could not prepare PDF for preview." }
            return nil
        }
    }

    /// Action for the Share button.
    private func sharePDF() {
        if let url = generateTemporaryPDF(purpose: "sharing") {
            self.pdfFileURLForSharing = url
            self.showShareSheet = true
            print("Generated temporary PDF for sharing at: \(url)")
        }
    }

    /// Action for the Preview button.
    private func prepareAndShowQLPreview() {
         if let url = generateTemporaryPDF(purpose: "preview") {
            self.pdfPreviewURL = url
            self.showQLPreview = true
            print("Generated temporary PDF for preview at: \(url)")
        }
    }

    // MARK: - Saving (iCloud & Local) & Spotlight Indexing

    /// Gets the URL for the app's local Documents directory.
    private func getLocalDocumentsURL() -> URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if documentsURL == nil { print("Error getting local documents directory.") }
        return documentsURL
    }

    /// Gets the URL for the Documents directory within the app's default iCloud container.
    private func getICloudDocumentsURL() -> URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            print("iCloud container URL not found."); return nil }
        let documentsURL = containerURL.appendingPathComponent("Documents")
        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            do { try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil) }
            catch { print("Error creating iCloud Documents directory: \(error)"); return nil }
        }
        return documentsURL
    }

    /// Saves the generated PDF to the app's iCloud Documents directory AND indexes it in Spotlight.
    private func saveToICloud() {
        guard !isSavingToICloud && !isSavingLocally else { return }
        isSavingToICloud = true; iCloudSaveError = nil; showICloudSaveConfirmation = false
        localSaveError = nil; showLocalSaveConfirmation = false // Clear other status

        DispatchQueue.global(qos: .userInitiated).async {
            guard let iCloudDocumentsURL = getICloudDocumentsURL() else {
                DispatchQueue.main.async { iCloudSaveError = "iCloud Drive unavailable."; isSavingToICloud = false }
                return
            }
            guard let pdfData = generatePDFData() else {
                DispatchQueue.main.async { iCloudSaveError = "Failed to generate PDF."; isSavingToICloud = false }
                return
            }
            let destinationURL = determineFinalURL(in: iCloudDocumentsURL)

            do {
                try pdfData.write(to: destinationURL, options: .atomic)
                print("Saved PDF to iCloud: \(destinationURL.path)")

                // --- Save Metadata & Index ---
                let finalOCRText = self.ocrText // Capture current OCR text
                let finalTags = self.tags       // Capture current tags
                saveMetadata(fileName: destinationURL.path, storageLocation: "icloud") // Save metadata first
                indexFileInSpotlight(fileURL: destinationURL, title: scanTitle, ocrText: finalOCRText, tags: finalTags) // Then index

                DispatchQueue.main.async {
                    isSavingToICloud = false; showICloudSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showICloudSaveConfirmation = false }
                }
            } catch {
                print("Error writing PDF to iCloud: \(error)")
                DispatchQueue.main.async {
                    iCloudSaveError = "Save failed: \(error.localizedDescription)"; isSavingToICloud = false
                }
            }
        }
    }

    /// Saves the generated PDF to the app's local Documents directory AND indexes it in Spotlight.
    private func saveLocally() {
        guard !isSavingLocally && !isSavingToICloud else { return }
        isSavingLocally = true; localSaveError = nil; showLocalSaveConfirmation = false
        iCloudSaveError = nil; showICloudSaveConfirmation = false // Clear other status

        DispatchQueue.global(qos: .userInitiated).async {
            guard let localDocumentsURL = getLocalDocumentsURL() else {
                DispatchQueue.main.async { localSaveError = "Could not access local documents."; isSavingLocally = false }
                return
            }
            guard let pdfData = generatePDFData() else {
                DispatchQueue.main.async { localSaveError = "Failed to generate PDF."; isSavingLocally = false }
                return
            }
            let destinationURL = determineFinalURL(in: localDocumentsURL)

            do {
                try pdfData.write(to: destinationURL, options: .atomic)
                print("Saved PDF locally: \(destinationURL.path)")

                // --- Save Metadata & Index ---
                let finalOCRText = self.ocrText // Capture current OCR text
                let finalTags = self.tags       // Capture current tags
                saveMetadata(fileName: destinationURL.path, storageLocation: "local") // Save metadata first
                indexFileInSpotlight(fileURL: destinationURL, title: scanTitle, ocrText: finalOCRText, tags: finalTags) // Then index

                DispatchQueue.main.async {
                    isSavingLocally = false; showLocalSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showLocalSaveConfirmation = false }
                }
            } catch {
                print("Error writing PDF locally: \(error)")
                DispatchQueue.main.async {
                    localSaveError = "Save failed: \(error.localizedDescription)"; isSavingLocally = false
                }
            }
        }
    }


    /// Saves the document metadata (title, folder relationship, etc.) to SwiftData.
    private func saveMetadata(fileName: String, storageLocation: String) {
        // Find the selected folder object based on the stored ID
        let selectedFolderObject = folders.first { $0.id == selectedFolderID }

        // Create the ScannedDocument object
        let newDocument = ScannedDocument(
            title: scanTitle,
            fileName: fileName, // Store the path/name where the file was saved
            storageLocation: storageLocation, // "local" or "icloud"
            ocrText: ocrText, // Make sure ocrText state holds the final text
            tags: tags,
            folder: selectedFolderObject // Assign the relationship
        )

        // Insert into the context
        modelContext.insert(newDocument)

        // Optional: Force save if needed
        // Consider error handling for the SwiftData save operation
        do {
            try modelContext.save()
            print("Saved document metadata to SwiftData: \(newDocument.title)")
        } catch {
            print("Error saving document metadata to SwiftData: \(error)")
            // Update UI to show metadata save error if desired
            if storageLocation == "local" { localSaveError = "Metadata save failed." }
            else { iCloudSaveError = "Metadata save failed." }
        }
    }

    /// Helper function to determine the final unique URL for saving a file.
    private func determineFinalURL(in directoryURL: URL) -> URL {
        let sanitizedTitle = scanTitle.replacingOccurrences(of: "[^a-zA-Z0-9\\s-]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        let baseFilename = sanitizedTitle.isEmpty ? "Scan-\(UUID().uuidString)" : sanitizedTitle
        var finalFilename = "\(baseFilename).pdf"
        var destinationURL = directoryURL.appendingPathComponent(finalFilename)
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
             finalFilename = "\(baseFilename)-\(counter).pdf"
             destinationURL = directoryURL.appendingPathComponent(finalFilename)
             counter += 1
        }
        return destinationURL
    }


    /// Indexes the saved PDF file and its metadata using CoreSpotlight.
    private func indexFileInSpotlight(fileURL: URL, title: String, ocrText: String, tags: String) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.pdf)
        attributeSet.title = title
        // Index OCR text only if it's valid content
        if !ocrText.isEmpty && !ocrText.starts(with: "Processing scan...") && !ocrText.starts(with: "[OCR Error") && ocrText != "No text recognized." {
            attributeSet.contentDescription = ocrText
        }
        // Index tags as keywords
        attributeSet.keywords = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        attributeSet.contentURL = fileURL // Link to the file

        // Use file path as unique ID (ensure file management handles potential ID changes if files move/rename)
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: fileURL.path,
            domainIdentifier: spotlightDomainIdentifier,
            attributeSet: attributeSet
        )
        // Perform indexing
        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error = error { print("Error indexing item in Spotlight: \(error.localizedDescription)") }
            else { print("Successfully indexed item: \(title) - \(fileURL.path)") }
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
        Button { print("\(label) / \(value) button tapped") } label: {
            VStack(spacing: 2) {
                Text(label).font(.caption).italic().foregroundColor(.gray)
                Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
            }
            .padding(.vertical, 10).frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
        .background(Color.clear).cornerRadius(8)
    }
}

// MARK: - Preview Provider for ScanEditView
struct ScanEditView_Previews: PreviewProvider {
    // --- ADDED: MainActor and Preview Container Setup ---
    @MainActor static var previewContainer: ModelContainer = {
         let schema = Schema([ Folder.self, ScannedDocument.self ]) // Add your models
         let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
         do {
             let container = try ModelContainer(for: schema, configurations: [configuration])
             // Optional: Insert sample folders for the picker
             let sampleFolder = Folder(name: "Preview Folder")
             container.mainContext.insert(sampleFolder)
             return container
         } catch {
             fatalError("Failed to create preview model container: \(error)")
         }
     }()

    static var previews: some View {
        NavigationView {
            ScanEditView(scannedDocument: nil)
                // --- ADDED: ModelContainer for Preview ---
                .modelContainer(previewContainer)
        }
    }
}
