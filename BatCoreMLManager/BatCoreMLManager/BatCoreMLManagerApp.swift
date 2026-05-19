//
//  BatCoreMLManagerApp.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 04.02.26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct BatCoreMLManagerApp: App {
    var body: some Scene {
#if !VIEWER
        DocumentGroup(editing: .coremlDocument, migrationPlan: BatCoreMLManagerMigrationPlan.self) {
            ContentView()
                .frame(minWidth: 1024, minHeight: 900)
        }
    #else
        WindowGroup {
            ContentView()
        }
    #endif
    }
}

extension CGImage {
    func image(withRotation radians: CGFloat) -> CGImage {
        let cgImage = self
        let LARGEST_SIZE = CGFloat(max(self.width, self.height))
        let context = CGContext.init(data: nil, width:Int(LARGEST_SIZE), height:Int(LARGEST_SIZE), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: cgImage.colorSpace!, bitmapInfo: cgImage.bitmapInfo.rawValue)!
        
        var drawRect = CGRect.zero
        drawRect.size = NSSize(width: self.width, height: self.height)
        let drawOrigin = CGPoint(x: (LARGEST_SIZE - CGFloat(self.width)) * 0.5,y: (LARGEST_SIZE - CGFloat(self.height)) * 0.5)
        drawRect.origin = drawOrigin
        var tf = CGAffineTransform.identity
        tf = tf.translatedBy(x: LARGEST_SIZE * 0.5, y: LARGEST_SIZE * 0.5)
        tf = tf.rotated(by: CGFloat(radians))
        tf = tf.translatedBy(x: LARGEST_SIZE * -0.5, y: LARGEST_SIZE * -0.5)
        context.concatenate(tf)
        context.draw(cgImage, in: drawRect)
        var rotatedImage = context.makeImage()!
        
        drawRect = drawRect.applying(tf)
        
        rotatedImage = rotatedImage.cropping(to: drawRect)!
        return rotatedImage
        
        
    }
}

extension UTType {
    static var coremlDocument: UTType {
        UTType(importedAs: "de.ecoObs.coreml-document")
    }
}

struct BatCoreMLManagerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        BatCoreMLManagerVersionedSchema.self,
    ]

    static var stages: [MigrationStage] = [
        // Stages of migration between VersionedSchema, if required.
    ]
}

struct BatCoreMLManagerVersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        ImageOutput.self,
        CoreMLAnnotation.self,
    ]
}
