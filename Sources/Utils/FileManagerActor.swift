import Foundation

/// Protocol defining asynchronous file management operations.
protocol FileManaging: Actor {
    /// Enumerates and returns a list of file URLs at the specified path.
    /// - Parameter path: The directory path to enumerate files in.
    /// - Returns: An array of URLs representing the files found at the path.
    func enumerateFiles(at path: String) throws -> [URL]

    /// Reads the contents of a file at the specified URL.
    /// - Parameter url: The URL of the file to read.
    /// - Returns: The file's contents as a string.
    func contentsOfFile(at url: URL) throws -> String
}

/// An actor that performs file operations asynchronously, including enumerating files and reading file contents.
final actor FileManagerActor: FileManaging {
    private let fileManager = FileManager.default  // Default file manager instance.

    /// Enumerates files in the directory at the specified path and returns them as an array of URLs.
    /// - Parameter path: The directory path to search for files.
    /// - Returns: An array of URLs for each file found in the directory.
    func enumerateFiles(at path: String) throws -> [URL] {
        var urls: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        // Collect each file URL in an array.
        while let fileUrl = enumerator.nextObject() as? URL {
            urls.append(fileUrl)
        }

        return urls
    }

    /// Reads the content of a file from the specified URL.
    /// - Parameter url: The URL of the file to read.
    /// - Returns: The contents of the file as a string.
    func contentsOfFile(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}
