// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import OSLog

extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static let subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like a view that appeared.
    static let soundFile = Logger(subsystem: subsystem, category: "soundFile")

    /// All logs related to tracking and analytics.
    static let soundAnalysis = Logger(subsystem: subsystem, category: "soundAnalysis")
}

extension URL {
    
    public func measurementFileURL() -> URL? {
        if !self.isFileURL {
            return nil
        }
        return self.deletingPathExtension().appendingPathExtension("bcCalls")
    }
    
    public func batIdentFileURL() -> URL? {
        if !self.isFileURL {
            return nil
        }
        return self.deletingPathExtension().appendingPathExtension("csv")
    }
    
}

package class CallsPresenter: NSObject, NSFilePresenter {
    lazy package var presentedItemOperationQueue = OperationQueue.main
    package var primaryPresentedItemURL: URL?
    package var presentedItemURL: URL?
    
    init(withSoundURL audioURL: URL) {
        primaryPresentedItemURL = audioURL
        presentedItemURL = audioURL.deletingPathExtension().appendingPathExtension("bcCalls")
    }
    
    func readData() -> Data? {
        var data: Data?
        var error: NSError?
        
        let coordinator = NSFileCoordinator.init(filePresenter: self)
        NSFileCoordinator.addFilePresenter(self)
        coordinator.coordinate(readingItemAt: presentedItemURL!, options: [], error: &error) {
            url in
            data = try? Data.init(contentsOf: url)
        }
        NSFileCoordinator.removeFilePresenter(self)
        return data
    }
}
