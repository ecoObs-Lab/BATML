//
//  Item.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 04.02.26.
//

import Foundation
import SwiftData

struct RecordingInput: Hashable {
    var id: UUID = UUID()
    var timestamp: Date
    var fileURL: URL
    var secBookmark: Data?

    init(timestamp: Date, fileURL: URL) {
        self.timestamp = timestamp
        self.fileURL = fileURL
    }
}
