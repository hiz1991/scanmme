import PDFKit
import SwiftUI

func checkForDuplicateTextPages(ocrTexts: [String]) -> [(Int, Int)] {
    var duplicates: [(Int, Int)] = []
    
    // Optional: use a hash to optimize comparison
    var hashes: [Int: Int] = [:] // [hash: firstPageIndex]

    for i in 0..<ocrTexts.count {
        let currentText = ocrTexts[i].trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = currentText.hashValue

        if let duplicateIndex = hashes[hash], ocrTexts[duplicateIndex] == currentText {
            duplicates.append((duplicateIndex + 1, i + 1)) // 1-based page index
        } else {
            hashes[hash] = i
        }
    }

    return duplicates
}

func checkForDuplicatePages(in pdfDocument: PDFDocument) -> [(Int, Int)] {
    var duplicates: [(Int, Int)] = []

    let pageCount = pdfDocument.pageCount
    var pageImages: [UIImage] = []
    
    debugPrint("Starting checkForDuplicatePages...")

    // Render each page as an image
    for i in 0..<pageCount {
        guard let page = pdfDocument.page(at: i) else { continue }

        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        pageImages.append(image)
    }

    // Compare pages for duplicates
    for i in 0..<pageImages.count {
        for j in i+1..<pageImages.count {
            if pageImages[i].pngData() == pageImages[j].pngData() {
                duplicates.append((i + 1, j + 1)) // 1-based indexing
            }
        }
    }

    return duplicates
}



// MARK: - Helper: Levenshtein Distance

/// Computes the Levenshtein distance between two strings.
func levenshtein(_ s1: String, _ s2: String) -> Int {
    if s1.isEmpty || s2.isEmpty {
        return 0
    }
    let a = Array(s1)
    let b = Array(s2)
    let m = a.count
    let n = b.count

    var dist = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    for i in 0...m { dist[i][0] = i }
    for j in 0...n { dist[0][j] = j }

    for i in 1...m {
        for j in 1...n {
            if a[i - 1] == b[j - 1] {
                dist[i][j] = dist[i - 1][j - 1]
            } else {
                dist[i][j] = min(dist[i - 1][j] + 1,
                                 min(dist[i][j - 1] + 1,
                                     dist[i - 1][j - 1] + 1))
            }
        }
    }
    return dist[m][n]
}

/// Returns a similarity index (0.0 to 0.99) between two strings based on the Levenshtein distance.
func similarityIndex(between s1: String, and s2: String) -> Double {
    if s1.isEmpty || s2.isEmpty {
        return 0
    }
    let distance = Double(levenshtein(s1, s2))
    let maxLength = Double(max(s1.count, s2.count))
    guard maxLength > 0 else { return 0.0 }
    
    // Similarity as a value between 0 and 1 (capped at 0.99)
    let similarity = 1.0 - (distance / maxLength)
    return min(similarity, 0.99)
}

// MARK: - Quality Index

/// A stub function that computes a quality index (0.0 to 0.99) for a given text.
/// Replace this with your own quality-evaluation logic.
func qualityIndex(for text: String) -> Double {
    // For demonstration, we'll assume quality is provided or computed by some heuristic.
    // Here, as an example, we return a fixed value or compute it based on text length.
    // In practice, this might analyze OCR errors or use other criteria.
    let computedQuality = min(Double(text.count) / 100.0, 0.99)
    return computedQuality
}

// MARK: - Data Model

/// A simple data model representing a text copy.
struct TextCopy: Identifiable {
    let id = UUID()
    let content: String
    // You can either precompute quality or compute it on the fly.
    let quality: Double
}

// MARK: - Filtering Function

/// Filters out copies that are similar (similarity > 0.92) to another copy and have low quality (quality < 0.9).
func filterCopies(_ copies: [TextCopy]) -> [TextCopy] {
    var toRemove = Set<UUID>()
    // Compare each unique pair.
    for i in 0..<copies.count {
        for j in (i + 1)..<copies.count {
            let sim = similarityIndex(between: copies[i].content, and: copies[j].content)
            if sim > 0.92 {
                // Remove the one with quality below threshold.
                if copies[i].quality < 0.9 && copies[j].quality >= 0.9 {
                    toRemove.insert(copies[i].id)
                } else if copies[j].quality < 0.9 && copies[i].quality >= 0.9 {
                    toRemove.insert(copies[j].id)
                } else if copies[i].quality < 0.9 && copies[j].quality < 0.9 {
                    // If both are low quality, remove the one with lower quality.
                    if copies[i].quality < copies[j].quality {
                        toRemove.insert(copies[i].id)
                    } else {
                        toRemove.insert(copies[j].id)
                    }
                }
            }
        }
    }
    return copies.filter { !toRemove.contains($0.id) }
}
