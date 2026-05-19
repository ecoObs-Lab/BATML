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
    private var mlModel = try! ObjDetV2TL(configuration: MLModelConfiguration())
    private var fbModel = try! FeedingBuzzSocialDetectorTL(configuration: MLModelConfiguration())
    
    private var requests = [VNRequest]()
    private var requestsFB = [VNRequest]()
    var callback: ((_ results: [DetectedObject]?) -> Void)?
    
    init() {
        setupVision()
        setupVisionFB()
    }
    
    func convertToArray(from mlMultiArray: MLMultiArray) -> [Float] {
        
        // Init our output array
        var array: [Float] = []
        
        // Get length
        let length = mlMultiArray.count
        
        // Set content of multi array to our out put array
        for i in 0...length - 1 {
            array.append(Float(truncating: mlMultiArray[[0,NSNumber(value: i)]]))
        }
        
        return array
    }
    
    private func setupVision() {
        
        do {
            let visionModel = try VNCoreMLModel(for: mlModel.model)
            let objectRecognition = VNCoreMLRequest(model: visionModel) { request, error in
                
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    self.processResults(results)
                } else if let results = request.results as? [VNCoreMLFeatureValueObservation] {
                    if let m = results.first?.featureValue.multiArrayValue as? MLMultiArray {
                        let c = self.convertToArray(from: m)
                        print(c)
                    }
                }
                
            }
            objectRecognition.imageCropAndScaleOption = .scaleFill
            requests = [objectRecognition]
        } catch {
            print("Vision setup error: \(error.localizedDescription)")
        }
    }
    
    private func setupVisionFB() {
        
        do {
            let visionModel = try VNCoreMLModel(for: fbModel.model)
            let objectRecognition = VNCoreMLRequest(model: visionModel) { request, error in
                
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    self.processResultsFB(results)
                } else if let results = request.results as? [VNCoreMLFeatureValueObservation] {
                    if let m = results.first?.featureValue.multiArrayValue as? MLMultiArray {
                        let c = self.convertToArray(from: m)
                        print(c)
                    }
                }
                
            }
            objectRecognition.imageCropAndScaleOption = .scaleFill
            requestsFB = [objectRecognition]
        } catch {
            print("Vision setup error: \(error.localizedDescription)")
        }
    }
    
    func detectObjects(in image: CGImage) {
        let handler = VNImageRequestHandler(cgImage: image)
        
        do {
            try handler.perform(requests)
        } catch {
            print("Detection error: \(error.localizedDescription)")
        }
    }
    
    func detectObjectsFB(in image: CGImage) {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .left)
        
        do {
            try handler.perform(requestsFB)
        } catch {
            print("Detection error: \(error.localizedDescription)")
        }
    }
    
    private func processResults(_ results: [VNRecognizedObjectObservation]) {
        let detectedObjects = results.map { observation -> DetectedObject in
            let label = observation.labels.first?.identifier ?? "Unknown"
            let confidence = observation.confidence
            let boundingBox = observation.boundingBox
            return DetectedObject(
                label: label,
                confidence: confidence,
                boundingBox: boundingBox
            )
        }
        self.detectedObjects = detectedObjects
        if callback != nil {
            DispatchQueue.main.async {
                self.callback!(detectedObjects)
            }
        }
    }
    
    private func processResultsFB(_ results: [VNRecognizedObjectObservation]) {
        let detectedObjects = results.compactMap { observation -> DetectedObject? in
            let label = observation.labels.first?.identifier ?? "Unknown"
            let confidence = observation.confidence
            let boundingBox = observation.boundingBox
            
            if confidence < 0.8 || label == "Call " { return nil }
            
            return DetectedObject(
                label: label,
                confidence: confidence,
                boundingBox: boundingBox
            )
        }
        self.detectedObjects = detectedObjects
        if callback != nil {
            DispatchQueue.main.async {
                self.callback!(detectedObjects)
            }
        }
    }
}

struct DetectedObject: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
