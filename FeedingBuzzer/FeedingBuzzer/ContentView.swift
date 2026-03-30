//
//  ContentView.swift
//  FeedingBuzzer
//
//  Created by Volker Runkel on 27.03.26.
//

import SwiftUI
import UniformTypeIdentifiers
import BatSoundHandling
import Accelerate
import SwiftImage
import Vision

struct DetectionObject: Identifiable, Hashable {
    let id = UUID()
    let imageData: Data
    let detections: Array<DetectedObject>
    
    var cgImage: CGImage? {
        if let jpgDataProvider = CGDataProvider(data: self.imageData as CFData) {
            return CGImage(jpegDataProviderSource: jpgDataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
        return nil
    }
    
    static func == (lhs: DetectionObject, rhs: DetectionObject) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Detections: Identifiable, Hashable  {
    
    let id: UUID = UUID()
    let url: URL
    let detectedObjects: Array<DetectionObject>
    
    static func == (lhs: Detections, rhs: Detections) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
}

struct ContentView: View {
    
    private let objDetector = ObjectDetector()
    @State private var detections: Array<Detections> = []
    @State private var selectedDetection: Detections? = nil
    @State private var idx = 0
    
    @State private var progress = 0.0
    @State private var running = false
    
    var body: some View {
        VStack {
            if !running {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
            } else {
                ProgressView()
            }
            Text("Feeding buzz detector!")
            
            Button {
                self.searchFolderTree()
            } label: {
                Label("Choose folder", systemImage: "waveform.badge.magnifyingglass")
            }
            
            if progress > 0.0 {
                ProgressView(value: progress)
                    .frame(width: 100)
            }
            if !detections.isEmpty {
                HStack {
                    List(detections, id: \.self, selection: $selectedDetection) { aDetection in
                        Text(aDetection.url.lastPathComponent)
                            .id(aDetection.id)
                            .font(.footnote)
                    }
                    .frame(width: 200)
                    .border(.gray)
                    .onChange(of: selectedDetection) {
                        self.idx = 0
                    }
                    if self.selectedDetection != nil {
                        VStack {
                            HStack {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([self.selectedDetection!.url])
                                } label: {
                                    Label("Show in Finder", systemImage: "finder")
                                }
                                Text("Found events in \(self.selectedDetection!.detectedObjects.count) blocks of sound")
                                Stepper("Detection \(idx + 1)", value: $idx, in: 0...self.selectedDetection!.detectedObjects.count-1, step: 1) { _ in
                                }
                            }
                            let max = self.selectedDetection!.detectedObjects.count
                            let displIdx = idx >= max ? 0 : idx
                            Image(self.selectedDetection!.detectedObjects[displIdx].cgImage!, scale: 1, label: Text("Sonagram"))
                                .overlay(
                                    ForEach(self.selectedDetection!.detectedObjects[displIdx].detections) { detectedObject in
                                            let bounds = self.observationToRect2(box: detectedObject.boundingBox, imgWidth: self.selectedDetection!.detectedObjects[displIdx].cgImage!.width, imgHeight: self.selectedDetection!.detectedObjects[displIdx].cgImage!.height)
                                            Rectangle()
                                                .border(.white, width: 2)
                                                .frame(width: bounds.width, height:  bounds.height)
                                                .position(x: bounds.midX, y: bounds.midY)
                                                .foregroundColor(.clear)
                                                .overlay(
                                                    Text("\(detectedObject.label) \(detectedObject.confidence * 100.0, format: .number.precision(.fractionLength(0)))%")
                                                        .lineLimit(1)
                                                        .fixedSize()
                                                        .font(.footnote)
                                                        .foregroundColor(.secondary)
                                                        .background(Color.blue)
                                                        .position(x: bounds.midX, y: bounds.minY)
                                                        .offset(x: bounds.width / 2, y: -10)
                                                )
                                        }
                                )
                        }
                    } else {
                        Rectangle()
                            .frame(width: 960, height: 480)
                    }
                }
            }
        }
        .padding()
    }

    func observationToRect2(box: CGRect, imgWidth: Int, imgHeight: Int)->CGRect
    {
        
        var bbBox = VNImageRectForNormalizedRect(box, imgWidth, imgHeight)
        bbBox.origin.y = CGFloat(imgHeight) - bbBox.origin.y - bbBox.size.height
        let rect = bbBox
  
        return rect
    }
    
    private func searchFolderTree() {
        let op = NSOpenPanel()
        op.allowedContentTypes = [.folder]
        op.allowsMultipleSelection = false
        op.canChooseFiles = false
        op.canChooseDirectories = true
        
        if op.runModal() == .OK {
            self.progress = 0
            self.detections.removeAll()
            let group = DispatchGroup()
            let fileURLs = getFiles(directoryURL: op.url!)
            let progressMax = Double(fileURLs.count)
            if fileURLs.count < 1 {
                self.progress = -1.0
            }
            self.running = true
            for url in fileURLs {
                Task.detached() {
                    var detectedObjects: Array<DetectionObject> = []
                    group.enter()
                    defer {
                        DispatchQueue.main.async {
                            progress += 1.0 / progressMax
                            if !detectedObjects.isEmpty {
                                let newDetection = Detections(url: url, detectedObjects: detectedObjects)
                                self.detections.append(newDetection)
                            }
                            group.leave()
                        }
                    }
                    
                    if let batRecording = try? BatRecording(audioURL: url), let header = batRecording.soundContainer!.header, header.samplerate >= 384000 {
                        var currentProcessingFrame = 0
                        
                        while currentProcessingFrame < batRecording.soundContainer!.header!.sampleCount {
                            var sonaStart = currentProcessingFrame
                            let sonaSize = 250000
                            
                            if sonaStart >= batRecording.soundContainer!.header!.sampleCount { break }
                            
                            if sonaStart + sonaSize >= batRecording.soundContainer!.header!.sampleCount {
                                sonaStart = batRecording.soundContainer!.header!.sampleCount - sonaSize - 1
                            }
                            
                            //let overlap: Float = 0.93 //0.96
                            
                            if let sona = batRecording.sonagramImage(from: sonaStart, size: sonaSize, fftParameters: FFTAnalyzer.FFTSettings(fftSize: 1024, overlap: 0.75, window: .hamming), gain: Float(52), spreadFactor: Float(1.84), colorType: .RX) {
                                if sona.height < 400 { break }
                                if let singleSona = sona.cropping(to: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 480, height: 960))), let newSona = self.histoStretchIn(singleSona: singleSona) {
                                    if let results = await objDetector.detectFeedingBuzzes(sonaImg: newSona), !results.isEmpty {
                                        let newSonaImage = Image<RGBA<Float>>(cgImage: newSona)
                                        let bitmapRep = NSBitmapImageRep(cgImage: newSonaImage.rotated(byDegrees: -90).cgImage)
                                        if let data = bitmapRep.representation(using: .jpeg, properties: [:]) {
                                            let newDetection = DetectionObject(imageData: data, detections: results)
                                            detectedObjects.append(newDetection)
                                        }
                                    }
                                }
                            }
                            
                            currentProcessingFrame += Int(Double(200000) * 0.75)
                        }
                        
                    }
                }
            }
            group.notify(queue: DispatchQueue.main) {
                progress = 0.0
                self.running = false
            }
        }
    }
    
    private func histoStretchIn(singleSona: CGImage) -> CGImage? {
        guard var imgBuffer = try? vImage_Buffer(cgImage: singleSona), var destinationBuffer = try? vImage_Buffer(cgImage: singleSona)  else {
            return nil
        }
        let percLow: UInt32 = 90
        let percentLow: [UInt32]  = [percLow, percLow, percLow, percLow]
        let percentHigh: [UInt32] = [0, 0, 0, 0]
        
        
        // Histogram bins for float images (commonly 32768 in vImage sample code).
        let histogramBins: UInt32 = 32768
        
        let _ = percentLow.withUnsafeBufferPointer { lowPtr in
            percentHigh.withUnsafeBufferPointer { highPtr in
                vImageEndsInContrastStretch_ARGBFFFF(
                    &imgBuffer,
                    &destinationBuffer,
                    nil,
                    lowPtr.baseAddress!,
                    highPtr.baseAddress!,
                    histogramBins,
                    0.0,
                    0.9,
                    vImage_Flags(kvImageNoFlags)
                )
            }
        }
        
        let rgbImageFormat = vImage_CGImageFormat( bitsPerComponent: 32, bitsPerPixel: 32 * 3, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: kCGBitmapByteOrder32Host.rawValue | CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.none.rawValue))!
        
        if let img = try? destinationBuffer.createCGImage(format: rgbImageFormat) {
            imgBuffer.data.deallocate()
            destinationBuffer.data.deallocate()
            return img
        }
        else {
            return nil
        }
    }
    
    
    private func getFolders(directoryURL: URL) -> Array<URL> {
        var folders: [URL] = []
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            for aFile in directoryContents {
                if (try aFile.resourceValues(forKeys: [.isDirectoryKey])).isDirectory ?? false {
                    folders.append(aFile)
                }
            }
            
        } catch {
            print(error)
        }
        return folders
    }
    
    private func getFiles(directoryURL: URL) -> Array<URL> {
        var files: [URL] = []
       do {
          let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
           
              let listOfFiles = directoryContents.filter{ ["raw", "wav"].contains($0.pathExtension.lowercased()) }
           
           for aFile in listOfFiles {
               files.append(aFile)
           }
           
       } catch {
           print(error)
       }
       return files
      }
}

#Preview {
    ContentView()
}
