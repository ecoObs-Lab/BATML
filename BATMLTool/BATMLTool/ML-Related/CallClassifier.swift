//
//  CallClassifier.swift
//  BATMLTool
//
//  Created by Volker Runkel on 13.03.26.
//

import Foundation
import CoreML
import Vision
import CoreImage

class PerCallClassifier {
    var sonaImg: CGImage!
    /** Sonagram classifier results */
    var result: String = ""
    var confidence: Float = 0.0
    
    func classifyImage() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierGeneraRN
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImageGFP() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierGeneraFP
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImagePip() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierPip
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImageNyc() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierNyc
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImageMyo() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierMyo
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImageOth() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierOth
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImagePipFP() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierPipFP
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImageNycFP() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierNycFP
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImageMyoFP() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierMyoFP
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
    func classifyImageOthFP() async -> (String, Float)? {
        let model = ImagePredictor.imageClassifierOthFP
        let request = VNCoreMLRequest(model: model)
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: self.sonaImg)
        do {
            try handler.perform([request])
            
            if let observations = request.results as? [VNClassificationObservation] {
                let observation = observations.first!
                var confidence = observation.confidence
                if confidence > 1 {
                    let confArr = observations.map { $0.confidence }
                    confidence = softmax(confArr).max() ?? 0
                }
                
                return (observation.identifier, confidence)
            }
        } catch {
            Swift.print("Error: \(error)")
        }
        return nil
    }
    
}
