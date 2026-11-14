import Foundation
import ZIPFoundation

/// A failed unzip, with the code the JavaScript side receives.
public struct UnzipError: Error, Equatable {
    public let code: String
    public let message: String
}

/// Extracts a zip archive with ZIPFoundation. Knows nothing of Capacitor, so XCTest can drive it directly.
public enum Unzipper {
    /// An absolute path or a `file://` URL as a file URL; anything else is refused.
    public static func resolve(_ value: String?, name: String) throws -> URL {
        guard let value = value, !value.isEmpty else {
            throw UnzipError(code: "INVALID_ARGUMENT", message: "\(name) is required")
        }
        if value.hasPrefix("file:") {
            guard let url = URL(string: value), url.isFileURL, !url.path.isEmpty else {
                throw UnzipError(code: "INVALID_ARGUMENT", message: "\(name) is not a valid file URL: \(value)")
            }
            return url.standardizedFileURL
        }
        if value.contains("://") {
            throw UnzipError(code: "INVALID_ARGUMENT", message: "\(name) must be a path or a file:// URL: \(value)")
        }
        guard value.hasPrefix("/") else {
            throw UnzipError(code: "INVALID_ARGUMENT", message: "\(name) must be an absolute path: \(value)")
        }
        return URL(fileURLWithPath: value).standardizedFileURL
    }

    /// True when an entry name would leave the destination: an absolute path, or a `..` segment anywhere.
    public static func isUnsafeEntryName(_ name: String) -> Bool {
        let normalised = name.replacingOccurrences(of: "\\", with: "/")
        if normalised.hasPrefix("/") {
            return true
        }
        return normalised.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    /// Extracts `source` into `destination` and returns how many entries it extracted. `onProgress` is called with
    /// (extracted, total) after each entry. Every entry name is checked before anything is written.
    @discardableResult
    public static func unzip(source: URL, destination: URL, overwrite: Bool = true,
                             onProgress: (Int, Int) -> Void = { _, _ in }) throws -> Int {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw UnzipError(code: "NOT_FOUND", message: "No zip file at \(source.path)")
        }
        let archive: Archive
        do {
            archive = try Archive(url: source, accessMode: .read)
        } catch {
            throw UnzipError(code: "BAD_ARCHIVE", message: "Not a zip archive: \(source.path)")
        }
        let entries = Array(archive)
        if entries.isEmpty {
            throw UnzipError(code: "BAD_ARCHIVE", message: "The archive is empty: \(source.path)")
        }
        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            throw UnzipError(code: "IO", message: "Could not create \(destination.path)")
        }
        let root = destination.standardizedFileURL.path
        let targets = try entries.map { entry -> URL in
            let target = destination.appendingPathComponent(entry.path).standardizedFileURL
            if isUnsafeEntryName(entry.path) || !target.path.hasPrefix(root + "/") {
                throw UnzipError(code: "UNSAFE_ENTRY",
                                 message: "The entry \(entry.path) would be written outside the destination")
            }
            return target
        }
        for (index, entry) in entries.enumerated() {
            let target = targets[index]
            if entry.type == .directory {
                do {
                    try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
                } catch {
                    throw UnzipError(code: "IO", message: "Could not create \(target.path)")
                }
            } else {
                if fileManager.fileExists(atPath: target.path) {
                    guard overwrite else {
                        throw UnzipError(code: "EXISTS", message: "\(target.path) already exists")
                    }
                    do {
                        try fileManager.removeItem(at: target)
                    } catch {
                        throw UnzipError(code: "IO", message: "Could not replace \(target.path)")
                    }
                }
                do {
                    // ZIPFoundation creates the parent directories, and refuses a link that points outside the destination
                    _ = try archive.extract(entry, to: target)
                } catch let error as Archive.ArchiveError {
                    throw UnzipError(code: "BAD_ARCHIVE", message: "The entry \(entry.path) is corrupt: \(error)")
                } catch {
                    throw UnzipError(code: "IO", message: "Could not write \(target.path): \(error.localizedDescription)")
                }
            }
            onProgress(index + 1, entries.count)
        }
        return entries.count
    }
}
