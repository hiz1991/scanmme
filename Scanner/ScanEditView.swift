import SwiftUI
import PDFKit // For loading PDF
import Vision // For OCR

// MARK: - PDF Viewer Representable
// Wrapper to use UIKit's PDFView in SwiftUI
// (Remains the same as before)
struct PDFKitView: UIViewRepresentable {
    let url: URL // URL of the PDF file

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: self.url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.backgroundColor = UIColor.systemGray5
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != self.url {
             uiView.document = PDFDocument(url: self.url)
        }
    }
}

// MARK: - Scan Edit View with Vision OCR
struct ScanEditView: View {
    // State for inputs
    @State private var scanTitle: String = "Electricity Bill - March"
    @State private var selectedFolder = "Bills"
    @State private var tags: String = "Bill, Urgent"
    @State private var reminderDate = Date()
    // Initialize ocrText state
    @State private var ocrText: String = "Performing OCR..."
    @State private var ocrInProgress: Bool = false
    // --- ADDED State to control OCR text editing ---
    @State private var ocrError: String? = nil
    @State private var isOcrTextEditorDisabled: Bool = true

    // State for tabs
    @State private var selectedTab = 0 // 0 for Details, 1 for OCR

    let folderOptions = ["Bills", "Personal", "Work", "Unfiled"]

    // Computed property to safely get the PDF URL from the bundle
    private var pdfUrl: URL? {
        Bundle.main.url(forResource: "preview", withExtension: "pdf")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // --- PDF Preview Area ---
                if let url = pdfUrl {
                    PDFKitView(url: url)
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(height: 250)
                        .cornerRadius(10)
                        .padding(.horizontal)
                } else {
                    // Fallback placeholder if PDF is not found
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(height: 250)
                        .cornerRadius(10)
                        .overlay(
                            VStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                                Text("preview.pdf not found").font(.caption).foregroundColor(.gray)
                            }
                        )
                        .padding(.horizontal)
                }
                // --- END PDF Preview Area ---

                 // --- Buttons (Two Rows, Dashed Outline) ---
                 // First Row
                 HStack(spacing: 12) {
                     InfoButton(label: "Category", value: "Personal", color: .blue)
                     InfoButton(label: "Events", value: "5th of May 2025", color: .green)
                 }
                 .padding(.horizontal)

                 // Second Row
                 HStack(spacing: 12) {
                     InfoButton(label: "Keep", value: "Months", color: .purple)
                     InfoButton(label: "Language", value: "English", color: .red)
                 }
                 .padding(.horizontal)
                 .padding(.bottom)
                 // --- END BUTTONS ---

                // Tabs
                Picker("View", selection: $selectedTab) {
                    Text("Details").tag(0)
                    Text("OCR Text").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)


                // Tab Content
                if selectedTab == 0 {
                    // Details Tab Content
                    VStack(spacing: 15) {
                         TextField("Title", text: $scanTitle)
                             .textFieldStyle(RoundedBorderTextFieldStyle())

                         Picker("Folder", selection: $selectedFolder) {
                             ForEach(folderOptions, id: \.self) { option in
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
                    VStack(alignment: .leading, spacing: 10) { // Added spacing
                        if ocrInProgress {
                             ProgressView("Performing OCR...") // Show progress indicator
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                        } else if let errorMsg = ocrError { // --- ADDED: Display OCR Error ---
                            VStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                Text("OCR Error:")
                                Text(errorMsg).font(.caption).foregroundColor(.gray)
                            }.frame(height: 200)
                                .frame(maxWidth: .infinity)
                        } else {
                            TextEditor(text: $ocrText) // Displays the extracted text
                                 .frame(height: 200)
                                 .border(Color(.systemGray5), width: 1)
                                 .cornerRadius(5)
                                 // --- UPDATED disabled modifier ---
                                 .disabled(isOcrTextEditorDisabled) // Use state variable
                                 .foregroundColor(ocrText.starts(with: "Performing OCR") || ocrText.starts(with: "Error") || ocrText == "No text recognized." ? .gray : .primary)
                                 // Add a subtle background change when enabled
                                 .background(isOcrTextEditorDisabled ? Color.clear : Color(.systemGray6))

                        }

                         // --- UPDATED Edit Text Button ---
                         // Only show the button if the editor is disabled and OCR is not in progress
                         if isOcrTextEditorDisabled && !ocrInProgress && ocrError == nil && !ocrText.isEmpty && ocrText != "No text recognized." {
                             Button("Edit Text") {
                                 print("Edit OCR Text Tapped - Enabling Editor")
                                 // Set state to enable the TextEditor
                                 isOcrTextEditorDisabled = false
                             }
                             .padding(.top, 5)
                         }
                         // --- END UPDATED Edit Text Button ---
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
                    Text("Saved")
                        .font(.body)
                        .foregroundColor(.gray)
                    Button { print("Share Tapped") } label: { Image(systemName: "square.and.arrow.up") }
                    .padding(.leading, 4)
                }
            }
            // --- Optional: Add Done button to toolbar when editing OCR ---
            ToolbarItem(placement: .navigationBarLeading) {
                 if !isOcrTextEditorDisabled { // Show Done button only when editing
                     Button("Done") {
                         isOcrTextEditorDisabled = true // Disable editor again
                         // Optionally dismiss keyboard here if needed
                         UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                     }
                 }
            }
        }
        // Perform OCR when the view appears
        .onAppear {
            // Avoid running OCR again if it was already successful or in progress
            if ocrText == "Performing OCR..." && !ocrInProgress {
                 performOCROnPDF()
            }
        }
    }

    // MARK: - Vision OCR Functionality
    // (performOCROnPDF and renderPageToImage functions remain the same)

    private func performOCROnPDF() {
        guard let url = pdfUrl else {
            // --- UPDATED: Set error state ---
            ocrError = "preview.pdf not found in bundle."
            ocrText = "" // Clear text
            return
        }
        guard let pdfDocument = PDFDocument(url: url) else {
            ocrError = "Could not load PDF document."
            ocrText = ""
            return
        }

        ocrInProgress = true; ocrError = nil // Reset error state
        ocrText = "Performing OCR..." // Reset text
        let pageCount = pdfDocument.pageCount
        var recognizedTextAggregator: [Int: String] = [:] // Dictionary to store page results in order

        // Use a DispatchGroup to wait for all page OCR tasks to complete
        let group = DispatchGroup()

        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<pageCount {
                group.enter() // Enter group for this page
                guard let page = pdfDocument.page(at: i) else {
                    print("Error getting page \(i)")
                    recognizedTextAggregator[i] = "[Error getting page \(i)]"
                    group.leave() // Leave group if page fails
                    continue
                }

                // Render page to image (adjust scale for better OCR if needed)
                guard let pageImage = renderPageToImage(page: page, scale: 2.0)?.cgImage else {
                    print("Error rendering page \(i) to image")
                    recognizedTextAggregator[i] = "[Error rendering page \(i)]"
                    group.leave() // Leave group if render fails
                    continue
                }

                // Create Vision request for this page's image
                let requestHandler = VNImageRequestHandler(cgImage: pageImage, options: [:])
                let recognizeTextRequest = VNRecognizeTextRequest { (request, error) in
                    // Handle completion for THIS page's request
                    var pageText = ""
                    if let error = error {
                        print("Error on page \(i): \(error.localizedDescription)")
                        pageText = "[OCR Error on page \(i + 1)]"
                    } else if let observations = request.results as? [VNRecognizedTextObservation] {
                        let pageStrings = observations.compactMap { $0.topCandidates(1).first?.string }
                        pageText = pageStrings.joined(separator: "\n")
                    }
                    recognizedTextAggregator[i] = pageText // Store result with page index
                    group.leave() // Leave group for this page
                }

                recognizeTextRequest.recognitionLevel = .accurate
                recognizeTextRequest.usesLanguageCorrection = true

                // Perform the request for this page
                do {
                    try requestHandler.perform([recognizeTextRequest])
                } catch {
                    print("Failed to perform request on page \(i): \(error)")
                    recognizedTextAggregator[i] = "[Request Error on page \(i + 1)]"
                    group.leave() // Leave group if perform fails
                }
            }

            // Notify main thread when ALL pages are processed
            group.notify(queue: .main) {
                // Combine results in page order
                let finalCombinedText = recognizedTextAggregator.sorted(by: { $0.key < $1.key }).map({ $0.value }).joined(separator: "\n\n--- Page Break ---\n\n")
                let trimmedText = finalCombinedText.trimmingCharacters(in: .whitespacesAndNewlines)

                // --- UPDATED: Set text or error, handle empty case ---
                self.ocrText = trimmedText.isEmpty ? "No text recognized." : trimmedText
                self.ocrInProgress = false
                print("Vision OCR Attempt Complete.")
            }
        }
    }

    // Helper function to render a PDFPage to a UIImage
    // (Remains the same as before)
    private func renderPageToImage(page: PDFPage, scale: CGFloat = 1.0) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: pageRect.width * scale, height: pageRect.height * scale))

        let img = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
            ctx.cgContext.translateBy(x: 0.0, y: renderer.format.bounds.size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return img
    }
}

// MARK: - Helper View for Dashed Outline Buttons
// (Remains the same as before)
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
                Text(label)
                    .font(.caption)
                    .italic()
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
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
            ScanEditView()
        }
    }
}
