//
//  ObjectDetector.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 24.02.26.
//

import Foundation
import Vision

@Observable
class ObjectDetector {
    
    public var detectedObjects: [DetectedObject] = Array()
    private var fbModel = try! FeedingBuzzSocialDetectorTL(configuration: MLModelConfiguration())
    private var visionModel: VNCoreMLModel? = nil
    
    private var fbYOLOModel = try! FeedingBuzzSocialDetectorYOLO(configuration: MLModelConfiguration())
    private var visionYOLOModel: VNCoreMLModel? = nil
    
    private var requestsFB = [VNRequest]()
    var confidenceLevel: Float = 0.9
    
    var callback: ((_ results: [DetectedObject]?) -> Void)?
    
    init() {
        setupVisionFB()
    }
    
    private func setupVisionFB() {
        
        do {
            let visionModel = try VNCoreMLModel(for: fbModel.model)
            self.visionModel = visionModel
            
            let visionModelYOLO = try VNCoreMLModel(for: fbYOLOModel.model)
            self.visionYOLOModel = visionModelYOLO
            
        } catch {
            print("Vision setup error: \(error.localizedDescription)")
        }
    }
    
    func detectFeedingBuzzes(sonaImg: CGImage) async -> [DetectedObject]? {
        do {
            let model = self.visionModel!
            
            let request = VNCoreMLRequest(model: model)
            request.preferBackgroundProcessing = true
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: sonaImg, orientation: .left)
            try handler.perform([request])
            
            if let results = request.results as? [VNRecognizedObjectObservation] {
                let detectedObjects = results.compactMap { observation -> DetectedObject? in
                    let label = observation.labels.first?.identifier ?? "Unknown"
                    let confidence = observation.confidence
                    let boundingBox = observation.boundingBox
                    
                    if label == "Call" || label == "Parasite" {
                        return nil
                    }
                    
                    return DetectedObject(
                        label: label,
                        confidence: confidence,
                        boundingBox: boundingBox
                    )
                }
                return detectedObjects
            }
        } catch {
            print("Vision setup error: \(error.localizedDescription)")
        }
        return nil
    }
    
    func detectFeedingBuzzesYOLO(sonaImg: CGImage) async -> [DetectedObject]? {
        do {
            let model = self.visionYOLOModel!
            
            let request = VNCoreMLRequest(model: model)
            request.preferBackgroundProcessing = true
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: sonaImg, orientation: .left)
            try handler.perform([request])
            
            if let results = request.results as? [VNRecognizedObjectObservation] {
                let detectedObjects = results.compactMap { observation -> DetectedObject? in
                    let label = observation.labels.first?.identifier ?? "Unknown"
                    let confidence = observation.confidence
                    let boundingBox = observation.boundingBox
                    
                    if label == "Call" || label == "Parasite" {
                        return nil
                    }
                    
                    return DetectedObject(
                        label: label,
                        confidence: confidence,
                        boundingBox: boundingBox
                    )
                }
                return detectedObjects
            }
        } catch {
            print("Vision setup error: \(error.localizedDescription)")
        }
        return nil
    }
}

public struct DetectedObject: Identifiable, Equatable {
    public let id = UUID()
    public let label: String
    public let confidence: Float
    public let boundingBox: CGRect
}
