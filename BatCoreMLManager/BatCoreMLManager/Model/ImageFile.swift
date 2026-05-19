//
//  ImageFile.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 26.02.26.
//

import Foundation
import CoreGraphics

struct ImageFile: Equatable, Hashable {
    var id: UUID = UUID()
    var fileName: String
    var image: CGImage
    var annotations: [ImageAnnotation]
}


struct ImageAnnotation: Equatable, Hashable {
    // CGRect isn’t directly persistable; store components explicitly
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var annotationLabel: String

    var rect: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set {
            x = newValue.origin.x
            y = newValue.origin.y
            width = newValue.size.width
            height = newValue.size.height
        }
    }
    
    var center : CGPoint {
        CGPoint(x: self.x + 0.5 * self.width, y: self.y + 0.5 * self.height)
    }
    
    init(annotationCoordinates: CGRect, annotationLabel: String) {
        self.x = annotationCoordinates.origin.x
        self.y = annotationCoordinates.origin.y
        self.width = annotationCoordinates.size.width
        self.height = annotationCoordinates.size.height
        self.annotationLabel = annotationLabel
    }
}
