//
//  Item.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 04.02.26.
//

import Foundation
import SwiftData

class RecordingInput: Hashable, Identifiable {
    static func == (lhs: RecordingInput, rhs: RecordingInput) -> Bool {
        return lhs.fileURL == rhs.fileURL
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(fileURL)
    }
    
    var id: UUID = UUID()
    var fileURL: URL
    var isFolder: Bool
    var secBookmark: Data?
    
    var recordings: [RecordingInput]? = nil
    var sortedRecordings: [RecordingInput]? {
        get {
            if recordings == nil {
                return nil
            }
            return recordings?.sorted(by: { a, b in
                a.fileURL.lastPathComponent < b.fileURL.lastPathComponent
            })
        }
        set {
            ()
        }
    }

    init(fileURL: URL, isFolder: Bool) {
        self.fileURL = fileURL
        self.isFolder = isFolder
    }
}
