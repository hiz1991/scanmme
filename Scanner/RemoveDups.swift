import Vision
import UIKit // Or AppKit if needed
import Foundation // For NSLock

// Define a structure to hold results for each page
struct PageOCRResult: Identifiable { // Make identifiable if needed later
    let id = UUID() // Add if needed for lists, etc.
    let text: String
    let averageConfidence: Float
    let originalIndex: Int // Keep track of the original index
}

class YourOCRProcessor: ObservableObject {

    @Published var ocrInProgress: Bool = false
    @Published var ocrError: String? = nil
    @Published var ocrText: String = ""
    @Published var recognizedTexts: [String] = []
    // @Published var finalImages: [CGImage] = [] // Uncomment if needed
    
    @Published var keptPageIndices: [Int] = [] // <--- ADD THIS PROPERTY

    // Lock only for writing to the aggregator during concurrent OCR phase
    private let aggregatorLock = NSLock()

    // Similarity Function (Using basic Levenshtein placeholder)
    func similarityIndex(between s1: String, and s2: String) -> Double {
        guard !s1.isEmpty || !s2.isEmpty else { return (s1.isEmpty && s2.isEmpty) ? 1.0 : 0.0 }
        guard !s1.isEmpty, !s2.isEmpty else { return 0.0 }

        let s1Array = Array(s1.unicodeScalars)
        let s2Array = Array(s2.unicodeScalars)
        let (len1, len2) = (s1Array.count, s2Array.count)
        var d: [[Int]] = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        for i in 0...len1 { d[i][0] = i }
        for j in 0...len2 { d[0][j] = j }
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                d[i][j] = min(d[i-1][j] + 1, d[i][j-1] + 1, d[i-1][j-1] + cost)
            }
        }
        let distance = Double(d[len1][len2])
        let maxLength = Double(max(len1, len2))
        return maxLength == 0 ? 1.0 : max(0.0, 1.0 - (distance / maxLength))
    }

    /// Performs OCR concurrently, then filters duplicates sequentially based on similarity and confidence.
    func performOCROnImages(images: [CGImage]) {
        guard !images.isEmpty else {
            Task { @MainActor in
                ocrError = "No images provided for OCR."
                ocrText = ""
                ocrInProgress = false
            }
            return
        }

        Task { @MainActor in
            ocrInProgress = true
            ocrError = nil
            ocrText = "Performing OCR..."
            recognizedTexts.removeAll()
            // finalImages.removeAll() // Uncomment if needed
        }

        // Temporary storage for results from concurrent tasks
        var pageResultsAggregator: [Int: PageOCRResult] = [:]

        let group = DispatchGroup()
        let visionQueue = DispatchQueue(label: "com.yourapp.visionQueue", qos: .userInitiated, attributes: .concurrent)

        print("Starting concurrent OCR for \(images.count) images...")

        // --- PHASE 1: Concurrent OCR ---
        for (i, cgImage) in images.enumerated() {
            group.enter()
            visionQueue.async {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let recognizeTextRequest = VNRecognizeTextRequest { [weak self] (request, error) in
                    // No comparison logic here anymore
                    defer { group.leave() } // Ensure leave is called
                    guard let self = self else { return }

                    var pageText = ""
                    var averageConfidence: Float = 0.0

                    if let error = error {
                        print("Error OCR Page \(i + 1): \(error.localizedDescription)")
                        pageText = "[OCR Error page \(i + 1)]"; averageConfidence = 0.0
                    } else if let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty {
                        var filteredStrings: [String] = []
                        var combinedConfidence: Float = 0.0
                        var totalCharacters: Int = 0
                        for obs in observations {
                            if let top = obs.topCandidates(1).first {
                                combinedConfidence += top.confidence * Float(top.string.unicodeScalars.count)
                                totalCharacters += top.string.unicodeScalars.count
                                filteredStrings.append(top.string)
                            }
                        }
                        pageText = filteredStrings.joined(separator: "\n")
                        averageConfidence = totalCharacters > 0 ? (combinedConfidence / Float(totalCharacters)) : 0.0
                         // Optional: Log individual page completion here if needed
                         // print("Page \(i + 1): OCR completed.")
                    } else {
                        pageText = ""; averageConfidence = 0.0 // No text
                    }

                    // Create result
                    let result = PageOCRResult(text: pageText, averageConfidence: averageConfidence, originalIndex: i)

                    // Store result thread-safely
                    self.aggregatorLock.lock()
                    pageResultsAggregator[i] = result
                    self.aggregatorLock.unlock()

                } // End of completion handler

                recognizeTextRequest.recognitionLevel = .accurate
                recognizeTextRequest.usesLanguageCorrection = true

                do {
                    try requestHandler.perform([recognizeTextRequest])
                } catch {
                    print("Failed to perform Vision request on page \(i + 1): \(error)")
                    // Store error result thread-safely
                    let errorResult = PageOCRResult(text: "[Request Error page \(i + 1)]", averageConfidence: 0.0, originalIndex: i)
                    self.aggregatorLock.lock()
                    pageResultsAggregator[i] = errorResult
                    self.aggregatorLock.unlock()
                    group.leave() // Ensure leave is called on perform error
                }
            } // End visionQueue.async
        } // End image loop

        // --- PHASE 2: Sequential Comparison and Final Update (on Main Thread) ---
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            print("--- All OCR tasks finished. Starting sequential comparison (Main Thread)... ---")

            // 1. Get sorted results
            let sortedResults: [PageOCRResult] = pageResultsAggregator
                .sorted { $0.key < $1.key }
                .map { $0.value }

            guard !sortedResults.isEmpty else {
                print("No OCR results gathered.")
                self.ocrText = "No text recognized."; self.recognizedTexts = []; self.ocrInProgress = false
                return
            }

            // 2. Perform sequential comparison
            var keptPageResults: [PageOCRResult] = []
            var indicesActuallyRemoved: Set<Int> = []
            let SIMILARITY_THRESHOLD = 0.90 // Adjust as needed

            if let firstPage = sortedResults.first {
                keptPageResults.append(firstPage) // Always keep the first page initially
                print("Kept Page \(firstPage.originalIndex + 1) (First Page)")
            }

            for i in 1..<sortedResults.count {
                let currentPageResult = sortedResults[i]
                // IMPORTANT: Compare against the *last page actually kept*, not just sortedResults[i-1]
                guard let lastKeptPageResult = keptPageResults.last else { continue }

                let similarity = self.similarityIndex(between: lastKeptPageResult.text, and: currentPageResult.text)
                print("Comparing Page \(currentPageResult.originalIndex + 1) [Conf \(String(format: "%.3f", currentPageResult.averageConfidence))] vs LAST KEPT Page \(lastKeptPageResult.originalIndex + 1) [Conf \(String(format: "%.3f", lastKeptPageResult.averageConfidence))]: Similarity \(String(format: "%.3f", similarity))")

                if similarity > SIMILARITY_THRESHOLD {
                    print("-> High similarity detected!")
                    // If current is better, replace the last kept one
                    if currentPageResult.averageConfidence > lastKeptPageResult.averageConfidence {
                        print("--> Replacing Page \(lastKeptPageResult.originalIndex + 1) with Page \(currentPageResult.originalIndex + 1)")
                        indicesActuallyRemoved.insert(lastKeptPageResult.originalIndex)
                        keptPageResults.removeLast()
                        keptPageResults.append(currentPageResult)
                    } else {
                        // Otherwise, discard the current page
                        print("--> Discarding Page \(currentPageResult.originalIndex + 1) (keeping Page \(lastKeptPageResult.originalIndex + 1))")
                        indicesActuallyRemoved.insert(currentPageResult.originalIndex)
                        // Do nothing else - current page is not added
                    }
                } else {
                    // Similarity is low, keep the current page
                    print("--> Low similarity. Keeping Page \(currentPageResult.originalIndex + 1)")
                    keptPageResults.append(currentPageResult)
                }
            }

            print("Indices ACTUALLY removed during sequential check: \(indicesActuallyRemoved.sorted())")
            print("Final number of pages after filtering: \(keptPageResults.count)")
            

            

            // 3. Update published properties
            let finalCombinedText = keptPageResults.map { $0.text }.joined(separator: "\n\n--- Page Break ---\n\n")
            let trimmedText = finalCombinedText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.ocrText = trimmedText.isEmpty ? "No text recognized (or all pages removed)." : trimmedText
            self.recognizedTexts = keptPageResults.map { $0.text }
            
            
            // ---> ADD THIS LINE <---
            // Publish the original indices of the pages that were kept
            self.keptPageIndices = keptPageResults.map { $0.originalIndex }
            print("Indices kept for final PDF: \(self.keptPageIndices.sorted())")

            // --- Optionally update final images ---
            /*
            let finalIndices = Set(keptPageResults.map { $0.originalIndex })
            Task { // Ensure image access happens on correct thread if needed, main is likely fine
                let finalImages = images.enumerated()
                    .filter { finalIndices.contains($0.offset) }
                    .map { $0.element }
                // await MainActor.run { self.finalImages = finalImages } // Update if finalImages is @MainActor
                 print("Original image count: \(images.count), Final image count: \(finalImages.count)")
            }
            */

            self.ocrInProgress = false
            print("Vision OCR and Sequential Similarity Filtering complete.")
        } // End group.notify
    } // End performOCROnImages
}
