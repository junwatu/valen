import Foundation
import UniformTypeIdentifiers

enum SupportedSubtitleTypes {
    static let fileExtensions = [
        "srt",
        "ass",
        "ssa",
        "vtt",
        "sub",
        "sup",
    ]

    static let contentTypes: [UTType] = fileExtensions.compactMap { UTType(filenameExtension: $0) }

    static func supports(fileExtension: String) -> Bool {
        fileExtensions.contains(fileExtension.lowercased())
    }

    static func supports(url: URL) -> Bool {
        supports(fileExtension: url.pathExtension)
    }

    /// Common case: `Movie.mkv` with `Movie.srt` in the same folder.
    static func matchingSubtitleURL(for mediaURL: URL) -> URL? {
        let directory = mediaURL.deletingLastPathComponent()
        let stem = mediaURL.deletingPathExtension().lastPathComponent
        guard !stem.isEmpty else { return nil }

        for ext in fileExtensions {
            let candidate = directory.appendingPathComponent("\(stem).\(ext)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate.standardizedFileURL
            }
        }
        return nil
    }
}