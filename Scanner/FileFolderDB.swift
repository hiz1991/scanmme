import SwiftUI
import SwiftData // Import SwiftData

// MARK: - SwiftData Model Definitions

// Represents a Folder that can contain scanned documents
@Model
final class Folder {
    @Attribute(.unique) var id: UUID // Unique identifier for each folder
    var name: String
    var createdAt: Date
    // Optional attributes for customization
    var iconName: String?
    var colorHex: String?

    // Relationship: A folder can have many documents.
    // '.cascade' means deleting a folder also deletes its associated documents.
    // Adjust '.cascade' if you want documents to become "unfiled" instead.
    @Relationship(deleteRule: .cascade, inverse: \ScannedDocument.folder)
    var documents: [ScannedDocument]? // Use optional array or initialize to empty: = []

    init(id: UUID = UUID(), name: String = "New Folder", createdAt: Date = Date(), iconName: String? = nil, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.iconName = iconName
        self.colorHex = colorHex
        self.documents = [] // Initialize documents array
    }
}

// Represents a Scanned Document's metadata
@Model
final class ScannedDocument {
    @Attribute(.unique) var id: UUID // Unique identifier for each document
    var title: String
    var createdAt: Date
    var fileName: String // Filename on disk (local or iCloud)
    var storageLocation: String // e.g., "local", "icloud"
    var ocrText: String? // Optional OCR text
    var tags: String? // Optional comma-separated tags

    // Relationship: A document belongs to one folder (or none if nil).
    var folder: Folder?

    init(id: UUID = UUID(), title: String = "", createdAt: Date = Date(), fileName: String = "", storageLocation: String = "local", ocrText: String? = nil, tags: String? = nil, folder: Folder? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.fileName = fileName
        self.storageLocation = storageLocation
        self.ocrText = ocrText
        self.tags = tags
        self.folder = folder
    }
}
