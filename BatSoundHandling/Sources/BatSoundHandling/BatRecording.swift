//
//  File.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 27.01.26.
//

import Foundation
import SwiftUI
import Accelerate

@Observable
public final class BatRecording : Equatable, ObservableObject {
    
    public static func == (lhs: BatRecording, rhs: BatRecording) -> Bool {
        lhs.audioURL == rhs.audioURL
    }
    
    
    public var soundContainer: BatSoundContainer?
    public var calls: Array<CallMeasurements> = Array()
    public var audioURL: URL?
    
    var fftAnalyzer = FFTAnalyzer()
    
    public init(soundContainer: BatSoundContainer, calls: Array<CallMeasurements> = Array()) {
        self.soundContainer = soundContainer
        self.calls = calls
    }
    
    public init(audioURL: URL) throws {
        self.audioURL = audioURL
        self.soundContainer = try BatSoundContainer(with: audioURL)
        
        if let callArray = self.GetCallMeasurements() {
            self.calls = callArray
        }
    }
    
    public func bcCallsMeasurements() -> NSArray? {
               
        guard let audioURL = self.audioURL else { return nil }
        
        let callsFile = CallsPresenter(withSoundURL: audioURL)
        
        guard let fileURL = callsFile.presentedItemURL, FileManager.default.fileExists(atPath:fileURL.path), let origCallData = NSArray(contentsOf: fileURL) else {
            return nil
        }
        return origCallData
    }
    
    public func GetCallMeasurements() -> Array<CallMeasurements>? {
        guard let origCallData = self.bcCallsMeasurements() else {
            return nil
        }
        
        var dataArray: Array<CallMeasurements> = Array()
        for call in origCallData as! [NSDictionary] {
            
            var tempDict: Dictionary<String,Float> = Dictionary()
            tempDict["Startsample"] = call["Startsample"] as? Float
            tempDict["Start"] = call["Start"] as? Float // besser? call["Startsample"] as! Float / Float(self.mySoundContainer.sampleRate/1000)
            tempDict["SFreq"] = call["SFreq"] as? Float
            tempDict["EFreq"] = call["EFreq"] as? Float
            tempDict["Size"] = call["Size"] as? Float
            tempDict["Sizesample"] = call["Sizesample"] as? Float
            
            var index = 1
            while (call["Time\(index)"] != nil) {
                let time = call["Time\(index)"] as! Float
                let freq = call["Freq\(index)"] as! Float
                tempDict["Time\(index)"] = time
                tempDict["Freq\(index)"] = freq
                index += 1
            }
            
            var callProb: Float = 0.0
            var callSpecies = ""
            if let prob = call["DiscrProb"] as? Float {
                callProb = prob
            }
            if let species = call["DiscrSpecies"] as? String {
                callSpecies = species
            }
            let thisCallMeasures = CallMeasurements(callData: tempDict, callNumber:call["Call"] as! Int, species:callSpecies, speciesProb:callProb, meanFrequency: 0.0)
            dataArray.append(thisCallMeasures)
            
        }
        
        return dataArray
    }
    
    public func batIdentMeasurements() -> Array<Dictionary<String, Float>>? {
        var measuresDict : Array<Dictionary<String, Float>>?
        
        guard let audioURL = self.audioURL, let fileURL = audioURL.batIdentFileURL(), FileManager.default.fileExists(atPath: fileURL.path), var csvString = try? String.init(contentsOf: fileURL) else { return nil }
        
        csvString = csvString.replacingOccurrences(of: ",", with: ".")
        let callLines = csvString.components(separatedBy: CharacterSet.newlines)
        var headers: Array<String>? {
            didSet {
                for (index, aHeader) in headers!.enumerated() {
                    if aHeader.isEmpty {
                        headers![index] = "\(index)"
                    }
                }
            }
        }
        measuresDict = Array()
        for (index, aLine) in callLines.enumerated() {
            if aLine.isEmpty {
                continue
            }
            let callData = aLine.components(separatedBy: "\t")
            if index == 0 {
                headers = callData
                continue
            }
            measuresDict?.append(Dictionary(uniqueKeysWithValues: zip(headers!, callData.map { Float($0) ?? -.infinity })))
        }
        
        return measuresDict
    }
    
    public func batIdentAverages() -> (avgDur: Float, avgBW: Float)? {
        guard let callsData = self.batIdentMeasurements() else {
            return nil
        }
        let averageDuration = (callsData.lazy.compactMap { $0["Dur"] ?? 0.0 }.reduce(0, +)) / Float(callsData.count)
        let averageBandwidth = (callsData.lazy.compactMap { ($0["Sfreq"] ?? 0.0) - ($0["Efreq"] ?? 0.0) }.reduce(0, +)) / Float(callsData.count)
        return (averageDuration, averageBandwidth)
    }
    
    public func exportForbatIdent(calls : Array<CallMeasurements>, newMeasurementsIncluded: Bool = false, toURL: URL, decimalSetting: Int = 0) {
        if self.audioURL == nil {
            return
        }
        var exportString = "Datei\tArt\tRuf\tDur\tSfreq\tEfreq\tStime\tNMod\tFMod\tFRmin\tRmin\ttRmin\tRlastms\tFlastms"
        if newMeasurementsIncluded {
            exportString += "\tFknee\tAlphaknee\tRknee\tptknee\tFmk\tAlphamk\tRmk\tptmk\tFmed\tFmidt\tFmidf\ttmidf\tptmidf\tPFmidt\tRmidt\tRmed\tRges\tDfm\tDqcf\tTyp"
        }
        
        for index in 10..<60 {
            exportString += "\tX\(index)"
        }
        
        for index in stride(from: 60, to: 150, by: 2) {
            exportString += "\tX\(index)"
        }
        
        let nF = NumberFormatter()
        nF.minimumFractionDigits = 1
        nF.maximumFractionDigits = 7
        nF.minimumIntegerDigits = 1

        if decimalSetting == 0 {
            nF.decimalSeparator = ","
            nF.groupingSeparator = "."
        }
        else if decimalSetting == 1 {
            nF.decimalSeparator = "."
            nF.groupingSeparator = ","
        }
        
        for aCall in calls {
            if aCall.identData != nil {
                var aTempCall = aCall
                exportString += "\n" + self.audioURL!.lastPathComponent
                exportString += "\t\(aCall.species)"
                exportString += "\t\(aCall.callNumber)"
                let callSize = aCall.callData["Size"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: callSize))!
                let sFreq = aCall.callData["SFreq"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: sFreq))!
                let eFreq = aCall.callData["EFreq"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: eFreq))!
                let start = aCall.callData["Start"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: start))!
                let nmod = aCall.identData!["NMod"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: nmod))!
                let fmod = aCall.identData!["FMod"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: fmod))!
                let frmin = aCall.identData!["FRmin"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: frmin))!
                let rmin = aCall.identData!["Rmin"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: rmin))!
                let trmin = aCall.identData!["tRmin"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: trmin))!
                let rlastms = aCall.identData!["Rlastms"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: rlastms))!
                let flastms = aCall.identData!["Flastms"]!
                exportString += "\t"
                exportString += nF.string(from: NSNumber(value: flastms))!
                
                if newMeasurementsIncluded {
                    if let kneeFreq = aCall.kneeFreq {
                        exportString += "\t"
                        exportString += nF.string(from: NSNumber(value: kneeFreq))!
                        exportString += "\t"
                        exportString += nF.string(from: NSNumber(value: aCall.kneeAlpha!))!
                        exportString += "\t"
                        exportString += nF.string(from: NSNumber(value: aCall.kneeR!))!
                        exportString += "\t"
                        exportString += nF.string(from: NSNumber(value: aTempCall.kneePosD!))!
                        exportString += "\t"
                    }
                    else {
                        exportString += ""
                        exportString += "\t"
                        exportString += ""
                        exportString += "\t"
                        exportString += ""
                        exportString += "\t"
                        exportString += ""
                        exportString += "\t"
                    }
                    if let myoFreq = aCall.myoFreq {
                        exportString += nF.string(from: NSNumber(value: myoFreq))!
                        exportString += "\t"
                        exportString += nF.string(from: NSNumber(value: aCall.myoAlpha!))!
                        exportString += "\t"
                        exportString += nF.string(from: NSNumber(value: aCall.myoR!))!
                        exportString += "\t"
                        exportString += nF.string(from: NSNumber(value: aTempCall.myoPosD!))!
                        exportString += "\t"
                    }
                    else {
                        exportString += ""
                        exportString += "\t"
                        exportString += ""
                        exportString += "\t"
                        exportString += ""
                        exportString += "\t"
                        exportString += ""
                        exportString += "\t"
                    }
                    
                    if let medianFreq = aCall.medianFreq {
                        exportString += nF.string(from: NSNumber(value: medianFreq))!
                        exportString += "\t"
                    }
                    else {
                        exportString += ""
                        exportString += "\t"
                    }
                    if let middleFreq = aCall.middleFreq {
                        exportString += nF.string(from: NSNumber(value: middleFreq))!
                        exportString += "\t"
                    }
                    else {
                        exportString += ""
                        exportString += "\t"
                    }
                    
                    
                    exportString += nF.string(from: NSNumber(value: aTempCall.Fmidf!))!
                    exportString += "\t"
                    exportString += nF.string(from: NSNumber(value: aTempCall.tmidf!))!
                    exportString += "\t"
                    exportString += nF.string(from: NSNumber(value: aTempCall.tmidf!/aCall.callData["Size"]!))!
                    exportString += "\t"
                    exportString += nF.string(from: NSNumber(value: ((aTempCall.Fmidt! - aTempCall.measurements!.min()!)/(aTempCall.measurements!.max()! -  aTempCall.measurements!.min()!))))!
                    exportString += "\t"
                    exportString += nF.string(from: NSNumber(value: aCall.Rmitte))!
                    exportString += "\t"
                    exportString += nF.string(from: NSNumber(value: aTempCall.medSteig))!
                    exportString += "\t"
                    exportString += nF.string(from: NSNumber(value: aTempCall.avgSteig))!
                    exportString += "\t"
                    
                    if let Dfm = aTempCall.dfm {
                        exportString += nF.string(from: NSNumber(value: Dfm))!
                        exportString += "\t"
                    }
                    else {
                        exportString += ""
                        exportString += "\t"
                    }
                    if let dqcf = aTempCall.dqcf {
                        exportString += nF.string(from: NSNumber(value: dqcf))!
                        exportString += "\t"
                    }
                    else {
                        exportString += ""
                        exportString += "\t"
                    }
                    
                    if aTempCall.dqcf! >= 1 && aTempCall.dfm! >= 1 {
                        aTempCall.callType = 2
                    }
                    else if aTempCall.dqcf! < 1 && aTempCall.dfm! >= 1 {
                        aTempCall.callType = 3
                    }
                    else if aTempCall.dqcf! >= 1 && aTempCall.dfm! < 1 {
                        aTempCall.callType = 1
                    }
                    
                    if let type = aTempCall.callType {
                        exportString += nF.string(from: NSNumber(value: type))!
                    }
                    else {
                        exportString += ""
                    }
                    
                }
                
                for index in 10..<60 {
                    guard let value = aCall.identData!["X\(index)"] else {
                        exportString += "\t0"
                        continue
                    }
                    exportString += "\t"
                    exportString += nF.string(from: NSNumber(value:value))!
                }
                
                for index in stride(from: 60, to: 150, by: 2) {
                    guard let value = aCall.identData!["X\(index)"] else {
                        exportString += "\t0"
                        continue
                    }
                    exportString += "\t"
                    exportString += nF.string(from: NSNumber(value:value))!
                }

            }
        }
        do {
            try exportString.write(to: toURL, atomically: true, encoding: String.Encoding.macOSRoman)
        }
        catch let err as NSError {
            Swift.print("Error occured \(err)")
        }
    }
    
    public func findCalls(threshold: Double = 0.015625) {
        let callFinder = BatCallFinderManager(mySoundContainer: self.soundContainer)
               
        if let bcCalls = callFinder.findCalls(threshold: threshold, quality: 20) {
            self.calls = bcCalls
            self.objectWillChange.send()
        }
    }
    
}

extension BatRecording {
    
    public func overviewSonagram(height: CGFloat = 128, expectedWidth: Double, gain: Float = 0, spreadFactor: Float = 1, colorType: FFTAnalyzer.ColorType = FFTAnalyzer.ColorType.RX) -> CGImage? {
        
        guard let soundContainer = self.soundContainer, let header = soundContainer.header else { return nil }
        
        let fftSize = height * 2
                
        // create sonagramm
        
        let sampleCount = header.sampleCount
        
        var overlap: Float = 0.0
        overlap = 1.0 - (Float(Double(sampleCount) / expectedWidth) / Float(fftSize))
        
        let offset = header.sampleCount * soundContainer.activeChannel
        
        return fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &soundContainer.soundData, startSample: offset, numberOfSamples:sampleCount, FFTSize: Int(fftSize), Overlap: overlap, Window:5, gain: gain, spreadFactor: spreadFactor, colorType: colorType.rawValue)
    }
    
    public func overviewSonagramStereo(height: CGFloat = 128, expectedWidth: Double, gain: Float = 0, spreadFactor: Float = 1, colorType: FFTAnalyzer.ColorType = FFTAnalyzer.ColorType.RX) -> CGImage? {
        
        guard let soundContainer = self.soundContainer, let header = soundContainer.header else { return nil }
        
        let fftSize = 128 * 2
                
        // create sonagramm
        
        let sampleCount = header.sampleCount
        
        var overlap: Float = 0.0
        overlap = 1.0 - (Float(Double(sampleCount) / expectedWidth) / Float(fftSize))
        
        
        var offset = 0
        
        let leftChannel = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &soundContainer.soundData, startSample: offset, numberOfSamples: sampleCount, FFTSize: fftSize, Overlap: overlap, Window: 5, gain: gain, spreadFactor: spreadFactor, colorType: colorType.rawValue)
        
        offset = header.sampleCount
        let rightChannel = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &soundContainer.soundData, startSample: offset, numberOfSamples: sampleCount, FFTSize: fftSize, Overlap: overlap, Window: 5, gain: gain, spreadFactor: spreadFactor, colorType: colorType.rawValue)
        
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.floatComponents.rawValue)
        
        let outputBitmap = CGContext(data: nil, width: leftChannel!.width * 2, height: leftChannel!.height, bitsPerComponent: 32, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        outputBitmap?.draw(leftChannel!, in: CGRect(x: leftChannel!.width * 1, y: 0,width: leftChannel!.width, height: leftChannel!.height))
        outputBitmap?.draw(rightChannel!, in: CGRect(x: 0,y: 0,width: leftChannel!.width, height: leftChannel!.height))
        return outputBitmap?.makeImage() ?? FFTAnalyzer.emptyCGImage
    }

    
    public func sonagramImage(from: Int, size: Int, fftParameters: FFTAnalyzer.FFTSettings, hires: Bool = false, gain: Float = 0, spreadFactor: Float = 1, colorType: FFTAnalyzer.ColorType = FFTAnalyzer.ColorType.RX, expanded: Bool = false) -> CGImage? {
        
        guard let soundContainer = self.soundContainer, let header = soundContainer.header else { return nil }
        
        let offset = header.sampleCount * soundContainer.activeChannel
        return fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &soundContainer.soundData, startSample: from+offset, numberOfSamples: size, FFTSize: fftParameters.fftSize, Overlap: fftParameters.overlap, Window: fftParameters.window.rawValue, gain: gain, spreadFactor: spreadFactor, colorType: colorType.rawValue, expanded: expanded)
    }
    
    public func sonagramImageStereo(from: Int, size: Int, fftParameters: FFTAnalyzer.FFTSettings, hires: Bool = false, gain: Float = 0, spreadFactor: Float = 1, colorType: FFTAnalyzer.ColorType = FFTAnalyzer.ColorType.RX, expanded: Bool = false) -> CGImage? {
        
        guard let soundContainer = self.soundContainer, let header = soundContainer.header else { return nil }
        
        var offset = 0
        
        let leftChannel = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &soundContainer.soundData, startSample: from+offset, numberOfSamples: size, FFTSize: fftParameters.fftSize, Overlap: fftParameters.overlap, Window: fftParameters.window.rawValue, gain: gain, spreadFactor: spreadFactor, colorType: colorType.rawValue, expanded: expanded)
        
        offset = header.sampleCount * soundContainer.activeChannel
        let rightChannel = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &soundContainer.soundData, startSample: from+offset, numberOfSamples: size, FFTSize: fftParameters.fftSize, Overlap: fftParameters.overlap, Window: fftParameters.window.rawValue, gain: gain, spreadFactor: spreadFactor, colorType: colorType.rawValue, expanded: expanded)
        
        let outputBitmap = CGContext(data: nil, width: leftChannel!.width * 2, height: leftChannel!.height, bitsPerComponent: leftChannel!.bitsPerComponent, bytesPerRow: 0, space: leftChannel!.colorSpace!, bitmapInfo: leftChannel!.bitmapInfo.rawValue)
        outputBitmap?.draw(leftChannel!, in: CGRect(x: leftChannel!.width, y: 0,width: leftChannel!.width, height: leftChannel!.height))
        outputBitmap?.draw(rightChannel!, in: CGRect(x: 0 ,y: 0,width: leftChannel!.width, height: leftChannel!.height))
        return outputBitmap?.makeImage() ?? FFTAnalyzer.emptyCGImage
        
    }
    
    public func spectrumData(from: Int, size: Int, fftParameters: FFTAnalyzer.FFTSettings) -> [Float]? {
        guard let soundContainer = self.soundContainer, let header = soundContainer.header else { return nil }
        let offset = header.sampleCount * soundContainer.activeChannel
        return fftAnalyzer.spectrumHiresData(fromSamples: &soundContainer.soundData, startSample: from + offset, numberOfSamples: size, FFTSize: 1024*16, Window: fftParameters.window.rawValue)
    }
}
