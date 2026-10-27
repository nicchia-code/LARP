import SwiftUI
import UniformTypeIdentifiers

/// A Markdown file to save with `fileExporter`.
struct MarkdownDocument: FileDocument {
    static let markdownType = UTType("net.daringfireball.markdown") ?? .plainText
    static var readableContentTypes: [UTType] { [markdownType] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
            let text = String(data: data, encoding: .utf8)
        else { throw CocoaError(.fileReadCorruptFile) }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
