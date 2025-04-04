import SwiftUI
import PDFKit // Needed for PDF Generation
import VisionKit // Needed for VNDocumentCameraScan
import Vision // Needed for OCR

// MARK: - Activity View Representable (for Share Sheet)
// This struct wraps the UIKit UIActivityViewController for use in SwiftUI
struct ActivityView: UIViewControllerRepresentable {
    // Items to share (in our case, the URL of the generated PDF)
    var activityItems: [Any]
    // Excluded activity types (optional)
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
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
    // Input property for the scanned document
    let scannedDocument: VNDocumentCameraScan?

    // State for form inputs
    @State private var scanTitle: String = "Electricity Bill - March"
    @State private var selectedFolder = "Bills"
    @State private var tags: String = "Bill, Urgent"
    @State private var reminderDate = Date()

    // State related to OCR processing
    @State private var ocrText: String = "Processing scan..."
    @State private var ocrInProgress: Bool = false
    @State private var ocrError: String? = nil
    @State private var ocrEditorState: OcrEditorState = .disabled
    @State private var imagesToProcess: [CGImage] = []

    // State for tabs (Details vs OCR Text)
    @State private var selectedTab = 0

    // --- ADDED: State for Share Sheet ---
    @State private var showShareSheet = false
    @State private var pdfFileURL: URL? = nil // Holds the URL of the generated PDF

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // --- Preview Area ---
                if !imagesToProcess.isEmpty {
                     Image(imagesToProcess[0], scale: 1.0, label: Text("Scanned Page 1"))
                         .resizable()
                         .aspectRatio(1.0, contentMode: .fit)
                         .frame(height: 250)
                         .cornerRadius(10)
                         .padding(.horizontal)
                } else if scannedDocument == nil {
                     Rectangle()
                         .fill(Color(.systemGray4))
                         .aspectRatio(1.0, contentMode: .fit)
                         .frame(height: 250)
                         .cornerRadius(10)
                         .overlay(Text("No Scan Data").foregroundColor(.gray))
                         .padding(.horizontal)
                } else {
                     ProgressView("Processing Scan...")
                         .frame(height: 250)
                         .padding(.horizontal)
                }
                // --- END Preview Area ---

                 // --- Buttons (Two Rows, Dashed Outline) ---
                 HStack(spacing: 12) {
                     InfoButton(label: "Category", value: "Personal", color: .blue)
                     InfoButton(label: "Events", value: "5th of May 2025", color: .green)
                 }
                 .padding(.horizontal)

                 HStack(spacing: 12) {
                     InfoButton(label: "Keep", value: "Months", color: .purple)
                     InfoButton(label: "Language", value: "English", color: .red)
                 }
                 .padding(.horizontal)
                 .padding(.bottom)
                 // --- END BUTTONS ---

                // Tabs for switching between Details and OCR Text
                Picker("View", selection: $selectedTab) {
                    Text("Details").tag(0)
                    Text("OCR Text").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)


                // Tab Content Area
                if selectedTab == 0 {
                    // Details Tab Content (Form fields)
                    VStack(spacing: 15) {
                         TextField("Title", text: $scanTitle)
                             .textFieldStyle(RoundedBorderTextFieldStyle())

                         Picker("Folder", selection: $selectedFolder) {
                             ForEach(defaultFolderOptions, id: \.self) { option in
                                 Text(option)
                             }
                         }
                         .padding(.vertical, 5)
                         .background(Color(.systemGray6))
                         .cornerRadius(8)

                         TextField("Tags (comma separated)", text: $tags)
                             .textFieldStyle(RoundedBorderTextFieldStyle())

                         DatePicker("Reminder", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    .padding()

                } else {
                    // OCR Text Tab Content
                    VStack(alignment: .leading, spacing: 10) {
                        if ocrInProgress {
                             ProgressView("Performing OCR...")
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                        } else if let errorMsg = ocrError {
                            VStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                Text("OCR Error:")
                                Text(errorMsg).font(.caption).foregroundColor(.gray)
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                        } else {
                            TextEditor(text: $ocrText)
                                 .frame(height: 200)
                                 .border(Color(.systemGray5), width: 1)
                                 .cornerRadius(5)
                                 .disabled(ocrEditorState == .disabled)
                                 .foregroundColor(ocrText.starts(with: "Processing scan...") || ocrText == "No text recognized." ? .gray : .primary)
                                 .background(ocrEditorState == .disabled ? Color.clear : Color(.systemGray6))
                        }

                         if ocrEditorState == .disabled && !ocrInProgress && ocrError == nil && !ocrText.isEmpty && ocrText != "No text recognized." && !ocrText.starts(with: "Processing scan...") {
                             Button("Edit Text") {
                                 print("Edit OCR Text Tapped - Enabling Editor")
                                 ocrEditorState = .enabled
                             }
                             .padding(.top, 5)
                         }
                    }
                    .padding()
                }

                Spacer()
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Edit Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Text("Saved") // Placeholder - Implement save logic
                        .font(.body)
                        .foregroundColor(.gray)
                    // --- MODIFIED: Share Button Action ---
                    Button {
                        // Generate PDF and prepare for sharing
                        if let url = generatePDF() {
                            self.pdfFileURL = url // Store the URL
                            self.showShareSheet = true // Trigger the share sheet
                            print("Generated PDF for sharing at: \(url)")
                        } else {
                            print("Error: Could not generate PDF for sharing.")
                            // Optionally show an error alert to the user
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .padding(.leading, 4)
                    // Disable share button if there's no scan data
                    .disabled(scannedDocument == nil)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                 if ocrEditorState == .enabled {
                     Button("Done") {
                         ocrEditorState = .disabled
                         hideKeyboard()
                     }
                 }
            }
        }
        .onAppear {
            if imagesToProcess.isEmpty && scannedDocument != nil {
                 processScannedDocument()
             }
        }
        // --- ADDED: Sheet Modifier for Share Sheet ---
        // Presents the ActivityView when showShareSheet is true and pdfFileURL is set
        .sheet(isPresented: $showShareSheet, onDismiss: {
            // Optional: Clean up the temporary PDF file after the sheet is dismissed
            if let url = pdfFileURL {
                try? FileManager.default.removeItem(at: url)
                print("Cleaned up temporary PDF: \(url)")
                pdfFileURL = nil // Reset the URL
            }
        }) {
            // Ensure pdfFileURL is valid before presenting the ActivityView
            if let url = pdfFileURL {
                ActivityView(activityItems: [url])
            } else {
                // Fallback or error view if URL is somehow nil when sheet is shown
                Text("Error preparing share data.")
            }
        }
    }

    // MARK: - Document Processing and OCR Functions

    /// Extracts images from the `scannedDocument` and triggers OCR.
    private func processScannedDocument() {
        guard let scan = scannedDocument else {
            print("ScanEditView: No scanned document provided.")
            ocrError = "No scan data available."
            ocrText = ""
            return
        }
        print("Processing scanned document with \(scan.pageCount) pages.")
        var extractedImages: [CGImage] = []
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<scan.pageCount {
                let originalImage = scan.imageOfPage(at: i)
                if let cgImage = originalImage.cgImage {
                    extractedImages.append(cgImage)
                } else {
                    print("Warning: Could not get CGImage for page \(i)")
                }
            }
            DispatchQueue.main.async {
                self.imagesToProcess = extractedImages
                print("Extracted \(self.imagesToProcess.count) images.")
                if !self.imagesToProcess.isEmpty {
                     performOCROnImages(images: self.imagesToProcess)
                } else {
                     self.ocrText = "Error: Could not extract images from scan."
                     self.ocrError = "Image extraction failed."
                }
            }
        }
    }

    /// Performs OCR using the Vision framework on an array of CGImage objects.
    private func performOCROnImages(images: [CGImage]) {
        guard !images.isEmpty else {
            ocrError = "No images provided for OCR."
            ocrText = ""
            return
        }
        ocrInProgress = true
        ocrError = nil
        ocrText = "Performing OCR..."
        var recognizedTextAggregator: [Int: String] = [:]
        let group = DispatchGroup()
        DispatchQueue.global(qos: .userInitiated).async {
            for (i, cgImage) in images.enumerated() {
                group.enter()
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let recognizeTextRequest = VNRecognizeTextRequest { (request, error) in
                    var pageText = ""
                    if let error = error {
                        print("Error performing OCR on page \(i): \(error.localizedDescription)")
                        pageText = "[OCR Error on page \(i + 1)]"
                    } else if let observations = request.results as? [VNRecognizedTextObservation] {
                        let pageStrings = observations.compactMap { $0.topCandidates(1).first?.string }
                        pageText = pageStrings.joined(separator: "\n")
                        debugPrint("pageText and i: \(pageText)")
                    }
                    recognizedTextAggregator[i] = pageText
                    group.leave()
                }
                recognizeTextRequest.recognitionLevel = .accurate
                recognizeTextRequest.usesLanguageCorrection = true
                do {
                    try requestHandler.perform([recognizeTextRequest])
                } catch {
                    print("Failed to perform text recognition request on page \(i): \(error)")
                    recognizedTextAggregator[i] = "[Request Error on page \(i + 1)]"
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                let finalCombinedText = recognizedTextAggregator
                                        .sorted(by: { $0.key < $1.key })
                                        .map({ $0.value })
                                        .joined(separator: "\n\n--- Page Break ---\n\n")
                let trimmedText = finalCombinedText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.ocrText = trimmedText.isEmpty ? "No text recognized." : trimmedText
                self.ocrInProgress = false
                print("Vision OCR on scanned images complete.")
            }
        }
    }

    // MARK: - PDF Generation

    // --- ADDED: Function to generate PDF ---
    /// Generates a PDF document from the scanned images.
    /// - Returns: The URL of the temporary PDF file, or nil if generation fails.
    private func generatePDF() -> URL? {
        guard let scan = scannedDocument, scan.pageCount > 0 else {
            print("No scanned document or pages available to generate PDF.")
            return nil
        }

        let pdfDocument = PDFDocument()

        // Add each scanned page to the PDF document
        for i in 0..<scan.pageCount {
            // Get the UIImage from the scan
            let image = scan.imageOfPage(at: i)
            // Create a PDF page instance from the image
            guard let pdfPage = PDFPage(image: image) else {
                print("Warning: Could not create PDFPage for page \(i)")
                continue // Skip this page if conversion fails
            }
            // Insert the page into the PDF document
            pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
        }

        // Get the app's temporary directory URL
        let tempDirectoryURL = FileManager.default.temporaryDirectory
        // Create a unique filename for the PDF
        let pdfFilename = "\(scanTitle.isEmpty ? "Scan" : scanTitle)-\(UUID().uuidString).pdf"
        let pdfFileURL = tempDirectoryURL.appendingPathComponent(pdfFilename)

        // Write the PDF document data to the temporary file URL
        // Note: For large documents, consider writing asynchronously.
        let success = pdfDocument.write(to: pdfFileURL)

        if success {
            return pdfFileURL // Return the URL if writing was successful
        } else {
            print("Error: Failed to write PDF data to file.")
            return nil // Return nil if writing failed
        }
    }


    // Helper function to dismiss the keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Helper View for Dashed Outline Buttons
struct InfoButton: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        Button {
            print("\(label) / \(value) button tapped")
            // TODO: Implement action for these buttons
        } label: {
            VStack(spacing: 2) {
                Text(label).font(.caption).italic().foregroundColor(.gray)
                Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .background(Color.clear)
        .cornerRadius(8)
    }
}


// MARK: - Preview Provider for ScanEditView
struct ScanEditView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScanEditView(scannedDocument: nil)
        }
    }
}
