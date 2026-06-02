import Foundation
import UniformTypeIdentifiers

enum SupportedMediaTypes {
    static let fileExtensions = [
        "mkv",
        "mka",
        "webm",
        "mp4",
        "mov",
        "m4v",
        "avi",
        "flv",
        "wmv",
        "mp3",
        "flac",
        "ogg",
        "wav"
    ]

    static let contentTypes: [UTType] = [
        .movie,
        .video,
        .audio,
        .audiovisualContent,
        .mpeg4Movie,
        .quickTimeMovie,
        .mp3,
        .wav
    ] + fileExtensions.compactMap { UTType(filenameExtension: $0) }

    static func supports(fileExtension: String) -> Bool {
        fileExtensions.contains(fileExtension.lowercased())
    }
}
