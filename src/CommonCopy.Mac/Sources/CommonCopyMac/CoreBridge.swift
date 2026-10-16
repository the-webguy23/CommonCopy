import Foundation

struct Phrase: Decodable, Identifiable {
    let id: String
    let categoryId: String
    let title: String
    let text: String
    let isFavorite: Bool
    let isEnabled: Bool
    let useCount: Int
}

struct Category: Decodable, Identifiable {
    let id: String
    let name: String
    let parentId: String?
}

struct CategoryOption: Decodable, Identifiable {
    let id: String?
    let displayName: String
}

struct Settings: Decodable {
    let appearance: String
    let restoreTextClipboardAfterPaste: Bool
    let clipboardRestoreDelayMilliseconds: Int
    let pasteDelayMilliseconds: Int
}

struct Library: Decodable {
    let phrases: [Phrase]
    let categories: [Category]
    let settings: Settings
}

struct CoreState: Decodable {
    let document: Library
    let categoryList: [CategoryOption]
    let favourites: [String]
    let commonlyUsed: [String]
    let categoryPhrases: [String: [String]]
    let captureTitle: String?
}

struct CoreResponse: Decodable {
    let ok: Bool
    let state: CoreState?
    let error: String?
}

enum CoreError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self { case .failed(let message): return message }
    }
}

// The helper runs off the UI thread. It references CommonCopy.Core directly.
// Requests travel over anonymous pipes; there is no HTTP server or network port.
actor CoreBridge {
    func request(_ values: [String: Any]) throws -> CoreState {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/Core/CommonCopy.DesktopBridge")
        guard FileManager.default.isExecutableFile(atPath: helper.path) else {
            throw CoreError.failed("The bundled phrase engine is missing. Use the packaged CommonCopy.app build.")
        }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("CommonCopy")
        let process = Process()
        process.executableURL = helper
        process.arguments = [directory.path]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let timeout = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: timeout)
        defer { timeout.cancel() }
        do {
            try input.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: values))
            try input.fileHandleForWriting.close()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let response = try JSONDecoder().decode(CoreResponse.self, from: data)
            guard process.terminationStatus == 0, response.ok, let state = response.state else {
                throw CoreError.failed(response.error ?? "The phrase engine could not complete the operation.")
            }
            return state
        } catch {
            if process.isRunning { process.terminate() }
            throw error
        }
    }
}
