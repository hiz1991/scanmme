import PDFKit

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
