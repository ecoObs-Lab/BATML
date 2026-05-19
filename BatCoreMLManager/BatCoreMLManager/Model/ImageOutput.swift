//
//  Item.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 04.02.26.
//

import Foundation
import SwiftData
import CoreGraphics

/*
// JSON file
[
 {
   "imagefilename": "cat and dog.png",
   "annotation":
   [
     {
       "label": "cat",
       "coordinates":
       {
         "y": 2.0,
         "x": 3.9,
         "height": 40.1,
         "width": 20.0
       }
     }, {
       "label": "dog",
       "coordinates":
       {
         "y": 40.0,
         "x": 38.9,
         "height": 100.1,
         "width": 70.0
       }
     }
   ]
 },
 ...
]
*/

@Model
final class ImageOutput: Hashable {
    
    private enum CodingKeys: String, CodingKey {
      case imagefilename
      case annotation
    }
    
    var timestamp: Date
    var name: String
    @Attribute(.externalStorage) var imageData: Data
    // Relationship to annotation models
    var annotations: [CoreMLAnnotation] = []
    
    var cgImage: CGImage? {
        if let jpgDataProvider = CGDataProvider(data: self.imageData as CFData) {
            return CGImage(jpegDataProviderSource: jpgDataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
        return nil
    }

    init(timestamp: Date, name: String, imageData: Data) {
        self.timestamp = timestamp
        self.name = name
        self.imageData = imageData
    }
}

extension ImageOutput: Encodable {
    // NOTE: Only Encodable. Remove Decodable until we know how to populate timestamp and imageData.
    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(name + ".jpeg", forKey: .imagefilename)
      try container.encode(annotations, forKey: .annotation)
    }
}

// Persistable model for a single annotation

private enum CodingKeys: String, CodingKey {
  case label
  case coordinates
}

@Model
final class CoreMLAnnotation {
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
    
    private struct JsonCoordinates: Codable {
      let x: CGFloat
      let y: CGFloat
      let width: CGFloat
      let height: CGFloat
      
      var asCgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
      }
    }
    
    private var jsonCoordinates: JsonCoordinates {
        JsonCoordinates(x: center.x, y: center.y, width: width, height: height)
        //JsonCoordinates(x: center.x, y: 0, width: width, height: 463)
    }

    init(annotationCoordinates: CGRect, annotationLabel: String) {
        self.x = annotationCoordinates.origin.x
        self.y = annotationCoordinates.origin.y
        self.width = annotationCoordinates.size.width
        self.height = annotationCoordinates.size.height
        self.annotationLabel = annotationLabel
    }
}

extension CoreMLAnnotation: Codable {
    
    // Decodable
    convenience init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      let label = try values.decode(String.self, forKey: .label)
      let coords = try values.decode(JsonCoordinates.self, forKey: .coordinates)
      self.init(annotationCoordinates: coords.asCgRect, annotationLabel: label)
    }

    // Encodable
    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(annotationLabel, forKey: .label)
      try container.encode(jsonCoordinates, forKey: .coordinates)
    }
  }

