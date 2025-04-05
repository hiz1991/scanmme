import SwiftUI
import PDFKit // Still potentially useful for PDFDocument operations if needed later
import VisionKit // For VNDocumentCameraScan
import Vision // For OCR
import QuickLook // <-- Import QuickLook
import CoreSpotlight // For Spotlight indexing
import UniformTypeIdentifiers // For UTType
import SwiftData

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
// This struct wraps QLPreviewController for use in SwiftUI
struct QuickLookView: UIViewControllerRepresentable {
    // The URL of the file to preview
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator // Set the Coordinator as the data source
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No update needed typically
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator acts as the data source for QLPreviewController
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookView

        init(_ parent: QuickLookView) {
            self.parent = parent
        }

        // Tells the preview controller how many items to preview
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1 // We are only previewing one item (the PDF)
        }

        // Provides the preview item (the URL) for a given index
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem // Cast the URL to QLPreviewItem
        }
    }
}


// Enum for OCR Text Editor State
enum OcrEditorState {
    case disabled
    case enabled
}

// Default folder options constant
private let defaultFolderOptions = ["Bills", "Personal", "Work", "Unfiled"]

// MARK: - Scan Edit View with Vision OCR
struct ScanEditView: View {

    // Access the ModelContext
    @Environment(\.modelContext) private var modelContext

    // Fetch available folders to populate the picker
    @Query(sort: \Folder.name) private var folders: [Folder]

    // State for the selected folder (using its ID for persistence stability)
    @State private var selectedFolderID: UUID? = nil // Start with no folder selected

    // Input property for the scanned document
    let scannedDocument: VNDocumentCameraScan?

    // State for form inputs
    @State private var scanTitle: String = "Scan \(Date().formatted(date: .abbreviated, time: .shortened))"
    @State private var selectedFolder = "Unfiled"
    @State private var tags: String = ""
    @State private var reminderDate = Date()

    // State related to OCR processing
    @State private var ocrText: String = "Processing scan..."
    @State private var ocrInProgress: Bool = false
    @State private var ocrError: String? = nil
    @State private var ocrEditorState: OcrEditorState = .disabled
    @State private var imagesToProcess: [CGImage] = []

    // State for tabs (Details vs OCR Text)
    @State private var selectedTab = 0

    // State for Share Sheet
    @State private var showShareSheet = false
    @State private var pdfFileURLForSharing: URL? = nil // URL for *sharing*

    // State for iCloud Saving Feedback
    @State private var isSavingToICloud = false
    @State private var showICloudSaveConfirmation = false // Renamed for clarity
    @State private var iCloudSaveError: String? = nil      // Renamed for clarity

    // --- ADDED: State for Local Saving Feedback ---
    @State private var isSavingLocally = false
    @State private var showLocalSaveConfirmation = false
    @State private var localSaveError: String? = nil

    // State for QuickLook Preview
    @State private var showQLPreview = false
    @State private var pdfPreviewURL: URL? = nil
    
    @State var recognizedTexts: [String] = [
                                            "Test me, allo",
                                            "Hi",
                                            "Test ne now",
                                            "Test me, allo",
                                            "Test me, allo"
                                            ]
    

    // Spotlight Domain Identifier
    private let spotlightDomainIdentifier = "me.scan.now.here.Scanner"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // --- Preview Area ---
                ZStack(alignment: .bottomTrailing) { // Use ZStack to overlay button
                    // Existing preview logic: Shows first scanned image or placeholders
                    if !imagesToProcess.isEmpty {
                         Image(imagesToProcess[0], scale: 1.0, label: Text("Scanned Page 1"))
                             .resizable().aspectRatio(1.0, contentMode: .fit)
                             .frame(height: 250).cornerRadius(10)
                             .padding(.horizontal)
                             .padding(.bottom, 40) // Space for the button below
                    } else if scannedDocument == nil {
                         Rectangle().fill(Color(.systemGray4)) // Placeholder if no scan data
                             .aspectRatio(1.0, contentMode: .fit).frame(height: 250)
                             .cornerRadius(10).overlay(Text("No Scan Data").foregroundColor(.gray))
                             .padding(.horizontal)
                             .padding(.bottom, 40) // Space for the button below
                    } else {
                         ProgressView("Processing Scan...") // Loading indicator
                             .frame(height: 250)
                             .padding(.horizontal)
                             .padding(.bottom, 40) // Space for the button below
                    }

                    // --- ADDED: Preview PDF Button ---
                    // Button overlaid on the preview area
                    Button {
                        prepareAndShowQLPreview() // Action to generate PDF and show QuickLook
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Preview PDF")
                    }
                    .buttonStyle(.bordered) // Style for visibility
                    .padding([.bottom, .trailing]) // Position in bottom-right
                    .disabled(scannedDocument == nil) // Disable if no scan data
                }
                // --- END Preview Area ---


                 // --- Buttons (Two Rows, Dashed Outline) ---
                 // Placeholder buttons for potential actions
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
                         DatePicker("Reminder", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    .padding()

                } else {
                    // OCR Text Tab Content
                    VStack(alignment: .leading, spacing: 10) {
                        // Show progress, error, or text editor based on OCR state
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
                        // Show "Edit Text" button conditionally
                         if ocrEditorState == .disabled && !ocrInProgress && ocrError == nil && !ocrText.isEmpty && ocrText != "No text recognized." && !ocrText.starts(with: "Processing scan...") {
                             Button("Edit Text") { ocrEditorState = .enabled }.padding(.top, 5)
                         }
                    }
                    .padding()
                }

                // --- Save Buttons and Feedback ---
                VStack(spacing: 10) { // Increased spacing slightly
                    // iCloud Save Button
                    Button { saveToICloud() } label: {
                        HStack { Image(systemName: "icloud.and.arrow.up"); Text(isSavingToICloud ? "Saving to iCloud..." : "Save to iCloud") }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).disabled(isSavingToICloud || isSavingLocally || scannedDocument == nil)

                    // --- ADDED: Local Save Button ---
                    Button { saveLocally() } label: {
                         HStack { Image(systemName: "icloud.and.arrow.down"); Text(isSavingLocally ? "Saving Locally..." : "Save Locally") }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).disabled(isSavingLocally || isSavingToICloud || scannedDocument == nil) // Use bordered style, disable if saving

                    // Display Saving Feedback (Combined)
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
                .padding(.horizontal) // Add horizontal padding to the VStack
                .padding(.bottom)
                // --- END Save Buttons ---

                Spacer()
            } // End VStack
        } // End ScrollView
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Edit Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { // Navigation Bar items
            ToolbarItem(placement: .navigationBarTrailing) { // Right side
                HStack(spacing: 4) {
                    // Share button
                    Button {
                        sharePDF() // Call share function
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(scannedDocument == nil || isSavingToICloud) // Disable if no data or saving
                }
            }
            ToolbarItem(placement: .navigationBarLeading) { // Left side
                 // Show "Done" button only when editing OCR text
                 if ocrEditorState == .enabled {
                     Button("Done") { ocrEditorState = .disabled; hideKeyboard() }
                 }
            }
        }
        .onAppear { // When the view first appears
            // Process the scanned document if images aren't already loaded
            if imagesToProcess.isEmpty && scannedDocument != nil {
                 processScannedDocument()
            }
        }
        // Sheet Modifier for Share Sheet presentation
        .sheet(isPresented: $showShareSheet, onDismiss: {
            // Clean up the temporary PDF file used for sharing
            if let url = pdfFileURLForSharing {
//                try? FileManager.default.removeItem(at: url)
                print("Cleaned up temporary PDF for sharing: \(url)")
//                pdfFileURLForSharing = nil
            }
        }) {
            // Provide the ActivityView with the URL to share
            if let url = pdfFileURLForSharing {
                ActivityView(activityItems: [url])
            } else {
                Text("Error preparing share data.") // Fallback view
            }
        }
        // --- ADDED: Full Screen Cover Modifier for QuickLook ---
        // Presents the QuickLook preview modally
        .sheet(isPresented: $showQLPreview, onDismiss: {
            // Clean up the temporary PDF file used for preview
            if let url = pdfPreviewURL {
//                try? FileManager.default.removeItem(at: url)
                print("Cleaned up temporary PDF for preview: \(url)")
                pdfPreviewURL = nil // Reset the URL
            }
        }) {
            // Provide the QuickLookView with the URL to preview
            if let url = pdfPreviewURL {
                QuickLookView(url: url)
                    .ignoresSafeArea() // Make preview edge-to-edge
            } else {
//                QuickLookView(url: nil)
                Text("Error preparing preview data.") // Fallback view
            }
        }
    }

    // MARK: - Document Processing and OCR Functions

   
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
        DispatchQueue.global(qos: .userInitiated).async {
            for (i, cgImage) in images.enumerated() {
                group.enter()
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                let requestHandler2 = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                let recognizeTextRequest = VNRecognizeTextRequest { (request, error) in
                    var pageText = ""
                    if let error = error { print("Error performing OCR on page \(i): \(error.localizedDescription)"); pageText = "[OCR Error on page \(i + 1)]" }
                    else if let observations = request.results as? [VNRecognizedTextObservation] { pageText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") }
                    recognizedTextAggregator[i] = pageText; group.leave()
                }
                recognizeTextRequest.recognitionLevel = .accurate; recognizeTextRequest.usesLanguageCorrection = true
                
                let recog = VNClassifyImageRequest { (request, error) in
                    if let error = error { print("Error performing Classify on page \(i): \(error.localizedDescription)"); }
                    else if let observations = request.results as? [VNClassificationObservation]  {
                        for classification in observations {
                            if classification.confidence > 0.5 {
                                print("Classified \(classification.identifier)")
                                print("Con \(classification.confidence)")
                            }
                           
                        }
                    }
                          
                }
//                recog; recognizeTextRequest.usesLanguageCorrection = true
                
                do { try requestHandler.perform([recognizeTextRequest]) }
                catch { print("Failed to perform text recognition request on page \(i): \(error)"); recognizedTextAggregator[i] = "[Request Error on page \(i + 1)]"; group.leave() }
                do { try requestHandler2.perform([recog]) } catch { print("VNClassifyImageRequest Failed to perform text recognition reque")}
            }
            group.notify(queue: .main) {
                let finalCombinedText = recognizedTextAggregator.sorted(by: { $0.key < $1.key }).map({ $0.value }).joined(separator: "\n\n--- Page Break ---\n\n")
                let trimmedText = finalCombinedText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.ocrText = trimmedText.isEmpty ? "No text recognized." : trimmedText
                self.ocrInProgress = false;
                self.recognizedTexts.append(contentsOf: recognizedTextAggregator.sorted(by: { $0.key < $1.key }).map({ $0.value }))
                print("Vision OCR on scanned images complete. Total: \(self.recognizedTexts.count)")
            }
        }
    }

    // MARK: - PDF Generation, Sharing, Previewing
    /// Generates PDF data from the scanned document.
    /// - Returns: The PDF data, or nil if generation fails.
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
    /// - Parameter purpose: A string like "sharing" or "preview" for logging.
    /// - Returns: The URL of the temporary PDF file, or nil on failure.
    private func generateTemporaryPDF(purpose: String) -> URL? {
        guard let pdfData = generatePDFData() else { return nil }

        let tempDirectoryURL = FileManager.default.temporaryDirectory
        // Create a unique filename including the purpose
        let pdfFilename = "\(scanTitle.isEmpty ? "Scan" : scanTitle)-\(purpose)-\(UUID().uuidString).pdf"
        let pdfFileURL = tempDirectoryURL.appendingPathComponent(pdfFilename)

        do {
            try pdfData.write(to: pdfFileURL) // Write data to the temporary file
            return pdfFileURL
        } catch {
            print("Error writing temporary PDF for \(purpose): \(error)")
            localSaveError = "Could not prepare PDF for \(purpose)." // Update error state for UI feedback
            showLocalSaveConfirmation = false
            return nil
        }
    }

    /// Action for the Share button. Generates PDF and triggers share sheet.
    private func sharePDF() {
        if let url = generateTemporaryPDF(purpose: "sharing") {
            self.pdfFileURLForSharing = url // Store URL for the sheet
            self.showShareSheet = true // Show the sheet
            print("Generated temporary PDF for sharing at: \(url)")
        }
        // Error handling is managed within generateTemporaryPDF
    }

    /// --- ADDED: Action for the Preview button ---
    /// Prepares the PDF and sets state to show the QuickLook preview.
    private func prepareAndShowQLPreview() {
         if let url = generateTemporaryPDF(purpose: "preview") {
            self.pdfPreviewURL = url // Store URL for QuickLook
            self.showQLPreview = true // Trigger the fullScreenCover
            print("Generated temporary PDF for preview at: \(url)")
        }
         // Error handling is managed within generateTemporaryPDF
    }

    /// Gets the URL for the app's local Documents directory.
    private func getLocalDocumentsURL() -> URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if documentsURL == nil {
            print("Error getting local documents directory.")
        }
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
        // Clear local save status if shown
        localSaveError = nil; showLocalSaveConfirmation = false

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
                indexFileInSpotlight(fileURL: destinationURL, title: scanTitle, ocrText: self.ocrText, tags: self.tags) // Index after save
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

    // --- ADDED: Function to Save Locally ---
    /// Saves the generated PDF to the app's local Documents directory AND indexes it in Spotlight.
    private func saveLocally() {
        guard !isSavingLocally && !isSavingToICloud else { return } // Prevent concurrent saves
        isSavingLocally = true; localSaveError = nil; showLocalSaveConfirmation = false
        // Clear iCloud save status if shown
        iCloudSaveError = nil; showICloudSaveConfirmation = false
        
    

        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Get Local Documents URL
            guard let localDocumentsURL = getLocalDocumentsURL() else {
                DispatchQueue.main.async {
                    localSaveError = "Could not access local documents directory."
                    isSavingLocally = false
                }
                return
            }
            // 2. Generate PDF Data
            guard let pdfData = generatePDFData() else {
                DispatchQueue.main.async {
                    localSaveError = "Failed to generate PDF data."
                    isSavingLocally = false
                }
                return
            }
            // 3. Determine Destination URL (using helper function)
            let destinationURL = determineFinalURL(in: localDocumentsURL)

            // 4. Write Data to Local URL
            do {
                try pdfData.write(to: destinationURL, options: .atomic)
                print("Successfully saved PDF locally: \(destinationURL.path)")
                saveMetadata(fileName: destinationURL.path, storageLocation: "local")

                // --- ADDED: Spotlight Indexing ---
                // Index *after* successful save
                indexFileInSpotlight(fileURL: destinationURL, title: scanTitle, ocrText: self.ocrText, tags: self.tags)
                // ---------------------------------

                // Update UI on main thread
                DispatchQueue.main.async {
                    isSavingLocally = false
                    showLocalSaveConfirmation = true
                    // Optionally hide confirmation after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showLocalSaveConfirmation = false
                    }
                }
            } catch {
                print("Error writing PDF locally: \(error)")
                // Update UI on main thread
                DispatchQueue.main.async {
                    localSaveError = "Failed to save file locally. \(error.localizedDescription)"
                    isSavingLocally = false
                }
            }
        }
    }


  // Function to save the document metadata using SwiftData
    private func saveMetadata(fileName: String, storageLocation: String) {
        // Find the selected folder object based on the stored ID
        let selectedFolder = folders.first { $0.id == selectedFolderID }

        // Create the ScannedDocument object
        let newDocument = ScannedDocument(
            title: scanTitle,
            fileName: fileName,
            storageLocation: storageLocation,
            ocrText: ocrText, // Make sure ocrText state holds the final text
            tags: tags,
            folder: selectedFolder // Assign the relationship
        )

        // Insert into the context
        modelContext.insert(newDocument)

        // Optional: Force save if needed, though autosave is common
        // do {
        //     try modelContext.save()
        //     print("Saved document metadata: \(newDocument.title)")
        //     // Handle successful save (e.g., dismiss view)
        // } catch {
        //     print("Error saving document metadata: \(error)")
        //     // Handle error
        // }

         // Trigger Spotlight indexing *after* saving metadata and file
         // indexFileInSpotlight(...) // Pass appropriate URL and data
    }

    /// Helper function to determine the final unique URL for saving a file.
    /// - Parameter directoryURL: The directory (local or iCloud) to save into.
    /// - Returns: A unique URL within the directory.
    private func determineFinalURL(in directoryURL: URL) -> URL {
        let sanitizedTitle = scanTitle.replacingOccurrences(of: "[^a-zA-Z0-9\\s-]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        let baseFilename = sanitizedTitle.isEmpty ? "Scan-\(UUID().uuidString)" : sanitizedTitle
        var finalFilename = "\(baseFilename).pdf"
        var destinationURL = directoryURL.appendingPathComponent(finalFilename)
        var counter = 1
        // Check if file exists and append counter if needed
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
        if !ocrText.isEmpty && !ocrText.starts(with: "Processing scan...") && !ocrText.starts(with: "[OCR Error") && ocrText != "No text recognized." {
            attributeSet.contentDescription = ocrText
        }
        attributeSet.keywords = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        attributeSet.contentURL = fileURL

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: fileURL.path,
            domainIdentifier: spotlightDomainIdentifier,
            attributeSet: attributeSet
        )
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

//// MARK: - Preview Provider for ScanEditView
//struct ScanEditView_Previews: PreviewProvider {
//    // --- ADDED: MainActor and Preview Container Setup ---
//    @MainActor static var previewContainer: ModelContainer = {
//         let schema = Schema([ Folder.self, ScannedDocument.self ]) // Add your models
//         let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
//         do {
//             let container = try ModelContainer(for: schema, configurations: [configuration])
//             // Optional: Insert sample folders for the picker
//             let sampleFolder = Folder(name: "Preview Folder")
//             container.mainContext.insert(sampleFolder)
//             return container
//         } catch {
//             fatalError("Failed to create preview model container: \(error)")
//         }
//     }()
//
//    static var previews: some View {
//        NavigationView {
//            ScanEditView(scannedDocument: nil)
//                // --- ADDED: ModelContainer for Preview ---
//                .modelContainer(previewContainer)
//        }
//    }
//}
