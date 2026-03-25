//
//  DetailView.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 04.02.26.
//

import SwiftUI
import BatSoundHandling
import Accelerate
import SwiftData
import SwiftImage
import Vision

struct DetailView: View {
    
    @Environment(\.modelContext) private var modelContext
    
    @State var recordingEntry: RecordingInput?
    @State private var batRecording: BatRecording?
    //@State private var calls: Array<CallMeasurements>? = nil
    @State var selectedCall: CallMeasurements?
    @State private var inspectorShown: Bool = true
    
    @AppStorage("sonaGain") var sonaGain: Double = 0.0
    @AppStorage("sonaSpread") var sonaSpread: Double = 1.0
    
    let overlap: Float = 0.93 //0.96
    let recommendedSize = 37000//20000
    
    @State private var singleSona: CGImage?
    @AppStorage("callSonaSpread") var callSonaSpread: Double = 1.0
    @AppStorage("callSonaGain") var callSonaGain: Double = 1.0
    @AppStorage("samplesAhead") var samplesAhead: Int = 2500
    @AppStorage("samplesAfter") var samplesAfter: Int = 5000
    
    @State private var lowValue: Float = 0.2
    @State private var highValue: Float = 0.9
    
    @State private var predictorResults: (String, Float)?
    @State private var predictorSpeciesResults: (String, Float)?
    
    @State private var predictorResultsFP: (String, Float)?
    @State private var predictorSpeciesResultsFP: (String, Float)?
    
    @State private var batchResults: Dictionary<String, Int>?
    
    var body: some View {
        VStack(alignment: .center) {
            if self.batRecording == nil {
                Text("No audio data")
            }
            else {
                GeometryReader { proxy in
                    BatSoundOverView(batRecording: $batRecording, selectedCall: $selectedCall, sonaWidth: proxy.size.width, waveFillColor: .blue, waveHeight: 64)
                        .frame(width: proxy.size.width)
                }
                .frame(maxWidth: .infinity, maxHeight: 350)
            }
            
            if self.singleSona != nil {
                HStack() {
                    VStack(alignment: .leading) {
                        GeometryReader { proxy in
                            Image(singleSona!,
                                  scale: 1.0,
                                  orientation: .left,
                                  label: Text("Call Sonagram"))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: CGFloat(singleSona!.width), height: proxy.size.height, alignment: .bottom)
                            .clipped()
                        }
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.5 }
                        HStack {
                            Slider(value: $callSonaGain, in: -128...128) { editing in
                                if !editing {
                                    self.updateViewData()
                                }
                            }
                            .frame(width: 100)
                            Text(self.callSonaGain, format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0)))
                            Slider(value: $callSonaSpread, in: -5...5) { editing in
                                if !editing {
                                    self.updateViewData()
                                }
                            }
                            .frame(width: 100)
                            Text(self.callSonaSpread, format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0)))
                            Button("Identify") {
                                classify()
                            }
                            Button("Batch Identify") {
                                batchClassify()
                            }
                        }
                    }
                    Grid {
                        GridRow {
                            ColorSquare(color: .green, result: predictorResults)
                        }
                        GridRow {
                            ColorSquare(color: .orange, result: predictorSpeciesResults)
                        }
                    }
                    .frame(width: 175)
                    
                    Grid {
                        GridRow {
                            ColorSquare(color: .green, result: predictorResultsFP)
                        }
                        GridRow {
                            ColorSquare(color: .orange, result: predictorSpeciesResultsFP)
                        }
                    }
                    .frame(width: 175)
                    
                    Spacer()
                }
                .padding()
            }
            Spacer()
        }
        //.padding()
        .inspector(isPresented: $inspectorShown) {
            if batRecording != nil {
                InspectorView(batRecording: batRecording!, selectedCall: $selectedCall, batchResults: $batchResults)
                    .padding()
                    .inspectorColumnWidth(min: 200, ideal: 200, max: 200)
            }
        }
        .onAppear() {
            self.updateBatRecording()
        }
        .onChange(of: recordingEntry) {
            self.batchResults = nil
            self.updateBatRecording()
        }
        .onChange(of: selectedCall) {
            if self.selectedCall != nil {
                    self.updateViewData()
                classify()
            }
        }
        .onChange(of: [samplesAfter, samplesAhead]) {
            if self.selectedCall != nil {
                if self.singleSona != nil {
                    self.updateViewData()
                    classify()
                }
            }
        }
    }
    
    struct ColorSquare: View {
        let color: Color
        let result: (String, Float)?
        
        var body: some View {
            ZStack {
                color
                Text("\(result?.0 ?? "Not Identified") \((result?.1 ?? 0) * 100.0, format: .number.precision(.fractionLength(0)))%")
                   .fixedSize(horizontal: false, vertical: true)
                       .multilineTextAlignment(.center)
                       .padding()
            }
            .frame(width: 150, height: 50)
        }
    }
    
    func classify() {
        guard let img = self.generateAIImage() else { return }
        let callClassifier = PerCallClassifier()
        callClassifier.sonaImg = img
                
        Task {
            if let result = await callClassifier.classifyImage() {
                self.predictorResults = result
                self.classifySpecies(img: img)
            }
            else {
                self.predictorResults = nil
                self.predictorSpeciesResults = nil
            }
            classifyFP(img: img)
        }
    }
    
    func batchClassify() {
        guard let batRecording = batRecording else { return }
        let group = DispatchGroup()
        var results: Array<String> = []
        for (index, _) in batRecording.calls.enumerated() {
            guard let img = self.generateAIImageBatch(call: index) else { continue }
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
            Task {
                group.enter()
                defer { group.leave() }
                if let result = await callClassifier.classifyImage() {
                    
                    if result.0 == "Pipistrelloid" {
                        let callClassifier = PerCallClassifier()
                        callClassifier.sonaImg = img
                        
                        if let result = await callClassifier.classifyImagePip() {
                            results.append(result.0)
                            batRecording.calls[index].species = result.0
                            batRecording.calls[index].speciesProb = result.1
                        }
                    }
                    else if result.0 == "Nyctaloid" {
                        let callClassifier = PerCallClassifier()
                        callClassifier.sonaImg = img
                        
                        if let result = await callClassifier.classifyImageNyc() {
                            results.append(result.0)
                            batRecording.calls[index].species = result.0
                            batRecording.calls[index].speciesProb = result.1
                        }
                        
                    }
                    else if result.0 == "Myotis" {
                        let callClassifier = PerCallClassifier()
                        callClassifier.sonaImg = img
                        
                        if let result = await callClassifier.classifyImageMyo() {
                            results.append(result.0)
                            batRecording.calls[index].species = result.0
                            batRecording.calls[index].speciesProb = result.1
                        }
                        
                    }
                    else if result.0 == "Other" {
                        let callClassifier = PerCallClassifier()
                        callClassifier.sonaImg = img
                        
                        if let result = await callClassifier.classifyImageOth() {
                            results.append(result.0)
                            batRecording.calls[index].species = result.0
                            batRecording.calls[index].speciesProb = result.1
                        }
                    }
                }
                //classifyFP(img: img)
            }
        }
        group.notify(queue: DispatchQueue.main) {
            let counts = results.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }

            self.batchResults = counts
        }
    }
    
    func classifyFP(img: CGImage) {
        let callClassifier = PerCallClassifier()
        callClassifier.sonaImg = img
                
        Task {
            if let result = await callClassifier.classifyImageGFP() {
                self.predictorResultsFP = result
                self.classifySpeciesFP(img: img)
            }
            else {
                self.predictorResultsFP = nil
                self.predictorSpeciesResultsFP = nil
            }
        }
    }
    
    func classifySpecies(img: CGImage) {
        guard let predictorResults = predictorResults else { return }
        if predictorResults.0 == "Pipistrelloid" {
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
                    
            Task {
                if let result = await callClassifier.classifyImagePip() {
                    self.predictorSpeciesResults = result
                    //self.classifySpecies(img: img)
                }
                else {
                    self.predictorSpeciesResults = nil
                }
            }
        }
        else if predictorResults.0 == "Nyctaloid" {
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
                    
            Task {
                if let result = await callClassifier.classifyImageNyc() {
                    self.predictorSpeciesResults = result
                    //self.classifySpecies(img: img)
                }
                else {
                    self.predictorSpeciesResults = nil
                }
            }
        }
        else if predictorResults.0 == "Myotis" {
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
                    
            Task {
                if let result = await callClassifier.classifyImageMyo() {
                    self.predictorSpeciesResults = result
                    //self.classifySpecies(img: img)
                }
                else {
                    self.predictorSpeciesResults = nil
                }
            }
        }
        else if predictorResults.0 == "Other" {
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
                    
            Task {
                if let result = await callClassifier.classifyImageOth() {
                    self.predictorSpeciesResults = result
                    //self.classifySpecies(img: img)
                }
                else {
                    self.predictorSpeciesResults = nil
                }
            }
        }
    }
    
    func classifySpeciesFP(img: CGImage) {
        guard let predictorResults = predictorResultsFP else { return }
        if predictorResults.0 == "Pipistrelloid" {
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
                    
            Task {
                if let result = await callClassifier.classifyImagePipFP() {
                    self.predictorSpeciesResultsFP = result
                    //self.classifySpecies(img: img)
                }
                else {
                    self.predictorSpeciesResultsFP = nil
                }
            }
        }
        else if predictorResults.0 == "Nyctaloid" {
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
                    
            Task {
                if let result = await callClassifier.classifyImageNycFP() {
                    self.predictorSpeciesResultsFP = result
                    //self.classifySpecies(img: img)
                }
                else {
                    self.predictorSpeciesResultsFP = nil
                }
            }
        }
        else if predictorResults.0 == "Myotis" {
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
                    
            Task {
                if let result = await callClassifier.classifyImageMyoFP() {
                    self.predictorSpeciesResultsFP = result
                    //self.classifySpecies(img: img)
                }
                else {
                    self.predictorSpeciesResultsFP = nil
                }
            }
        }
        else if predictorResults.0 == "Other" {
            let callClassifier = PerCallClassifier()
            callClassifier.sonaImg = img
                    
            Task {
                if let result = await callClassifier.classifyImageOthFP() {
                    self.predictorSpeciesResultsFP = result
                    //self.classifySpecies(img: img)
                }
                else {
                    self.predictorSpeciesResultsFP = nil
                }
            }
        }
    }
    
    func updateBatRecording() {
        guard let recordingEntry = recordingEntry else { return }
        var fileURL = recordingEntry.fileURL
        var accessing: Bool = false
        if recordingEntry.secBookmark != nil {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: recordingEntry.secBookmark!, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
                
                if !stale {
                    accessing = url.startAccessingSecurityScopedResource()
                    fileURL = url
                }
            }
        }
        
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        if let batRecording = try? BatRecording(audioURL: fileURL) {
            self.batRecording = batRecording
            self.selectedCall = nil
            //self.calls = batRecording.calls
            if batRecording.calls.count > 0 {
                self.selectedCall = batRecording.calls.first!
                var species = Array<String>()
                for aCall in batRecording.calls {
                    if !aCall.species.isEmpty{
                        species.append(aCall.species)
                    }
                }
                if !species.isEmpty{
                    let counts = species.reduce(into: [:]) { counts, word in counts[word, default: 0] += 1 }

                    self.batchResults = counts
                }
            }
        }
    }
    
    func updateViewData() {
        guard let batRecording = self.batRecording, let selectedCall = self.selectedCall else {
            self.singleSona = nil
            return
        }
        let callStart = selectedCall.getCallStartsample()
        let callSize = selectedCall.getCallSizesample()
        var sonaStart = max(Int(callStart) - samplesAhead,0)
        var sonaSize = min(Int(callSize) + samplesAfter, batRecording.soundContainer!.header!.sampleCount)
        
        if sonaSize > recommendedSize {
            let diff = sonaSize - recommendedSize
            sonaStart += diff / 2
            sonaSize = recommendedSize
        } else if sonaSize < recommendedSize {
            let diff = recommendedSize - sonaSize
            sonaStart -= diff / 2
            sonaSize = recommendedSize
        }
        
        if let sona = batRecording.sonagramImage(from: sonaStart, size: sonaSize, fftParameters: FFTAnalyzer.FFTSettings(fftSize: 1024, overlap: overlap, window: .seventermharris), gain: Float(self.callSonaGain), spreadFactor: Float(self.callSonaSpread), colorType: .RX) {
            self.singleSona = sona.cropping(to: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 463, height: 463)))
            
            //self.histoStretchIn()
            //self.histoStretchIn()
        }
    }
    
    func generateAIImage() -> CGImage? {
        guard let batRecording = batRecording, let call = selectedCall else {
            return nil
        }

        let fullSampleCount = batRecording.soundContainer!.header!.sampleCount
        let callStart = Int(call.getCallStartsample())
        let callSize = Int(call.getCallSizesample())
                
        let fftAnalyzer = batRecording.fftAnalyzer
        
                
        //let overlap: Float = windowSize > 8000 ? 0.96875: 0.984375
        var overlap: Float = 0.98
        if callSize > Int(ceil(6.1*500.0)) {
            overlap = 0.96
        }
        if callSize > Int(ceil(12.1*500.0)) {
            overlap = 0.93
        }
        
        let imgWidth = Float(256.0)
        let sampleDur =  ceil((Float(1024)*(1.0-overlap)))
        
        let size = imgWidth * sampleDur + 1024
        let before = Int(size) / 2  - callSize / 2
        var sonaStart = max(Int(callStart) - Int(before),0)
        //var sonaSize = min(size, fullSampleCount)
        let sonaSize = size
        if sonaStart + Int(sonaSize) >= fullSampleCount {
            let correct = (sonaStart + Int(sonaSize)) - fullSampleCount
            sonaStart -= (correct + 1)
        }
        
        let fftParameters = FFTAnalyzer.FFTSettings(fftSize: 1024, overlap: overlap, window: .powersin)
        
        //default gain is 80
        //default spread is 2
        
        let sonaImage = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &batRecording.soundContainer!.soundData, startSample: sonaStart, numberOfSamples: Int(sonaSize), FFTSize: fftParameters.fftSize, Overlap: fftParameters.overlap, Window: fftParameters.window.rawValue, gain: Float(self.callSonaGain), spreadFactor: Float(self.callSonaSpread), colorType: 2, expanded: false)
        
        if let sonaImg = sonaImage, let img = self.histoStretchIn(img: sonaImg) {
            //if let img2 = self.histoStretchIn(img: img) {
                let newImage = Image<RGBA<Float>>(cgImage: img.cropping(to: CGRect(x: 0, y: 0, width: 256, height: 256))!)
                
                let exportImg = newImage.rotated(byDegrees: -90).cgImage
                
            return exportImg
        }
        
        return nil
    }
    
    func generateAIImageBatch(call: Int) -> CGImage? {
        guard let batRecording = batRecording else {
            return nil
        }

        let call = batRecording.calls[call]
        let fullSampleCount = batRecording.soundContainer!.header!.sampleCount
        let callStart = Int(call.getCallStartsample())
        let callSize = Int(call.getCallSizesample())
                
        let fftAnalyzer = batRecording.fftAnalyzer
        
                
        //let overlap: Float = windowSize > 8000 ? 0.96875: 0.984375
        var overlap: Float = 0.98
        if callSize > Int(ceil(6.1*500.0)) {
            overlap = 0.96
        }
        if callSize > Int(ceil(12.1*500.0)) {
            overlap = 0.93
        }
        
        let imgWidth = Float(256.0)
        let sampleDur =  ceil((Float(1024)*(1.0-overlap)))
        
        let size = imgWidth * sampleDur + 1024
        let before = Int(size) / 2  - callSize / 2
        var sonaStart = max(Int(callStart) - Int(before),0)
        //var sonaSize = min(size, fullSampleCount)
        let sonaSize = size
        if sonaStart + Int(sonaSize) >= fullSampleCount {
            let correct = (sonaStart + Int(sonaSize)) - fullSampleCount
            sonaStart -= (correct + 1)
        }
        
        let fftParameters = FFTAnalyzer.FFTSettings(fftSize: 1024, overlap: overlap, window: .powersin)
        
        //default gain is 80
        //default spread is 2
        
        let sonaImage = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &batRecording.soundContainer!.soundData, startSample: sonaStart, numberOfSamples: Int(sonaSize), FFTSize: fftParameters.fftSize, Overlap: fftParameters.overlap, Window: fftParameters.window.rawValue, gain: Float(self.callSonaGain), spreadFactor: Float(self.callSonaSpread), colorType: 2, expanded: false)
        
        if let sonaImg = sonaImage, let img = self.histoStretchIn(img: sonaImg) {
            //if let img2 = self.histoStretchIn(img: img) {
                let newImage = Image<RGBA<Float>>(cgImage: img.cropping(to: CGRect(x: 0, y: 0, width: 256, height: 256))!)
                
                let exportImg = newImage.rotated(byDegrees: -90).cgImage
                
            return exportImg
        }
        
        return nil
    }
    
    func histoStretchIn(img: CGImage) -> CGImage? {
        guard var imgBuffer = try? vImage_Buffer(cgImage: img), var destinationBuffer = try? vImage_Buffer(cgImage: img)  else {
            return nil
        }
        let percLow: UInt32 = 25
        let percentLow: [UInt32]  = [percLow, percLow, percLow, percLow]
        let percentHigh: [UInt32] = [0, 0, 0, 0]
        
        
        // Histogram bins for float images (commonly 32768 in vImage sample code).
        let histogramBins: UInt32 = 32768
        
        percentLow.withUnsafeBufferPointer { lowPtr in
            percentHigh.withUnsafeBufferPointer { highPtr in
                vImageEndsInContrastStretch_ARGBFFFF(
                    &imgBuffer,
                    &destinationBuffer,
                    nil,
                    lowPtr.baseAddress!,
                    highPtr.baseAddress!,
                    histogramBins,
                    0.2,
                    0.9,
                    vImage_Flags(kvImageNoFlags)
                )
            }
        }
        
        let rgbImageFormat = vImage_CGImageFormat( bitsPerComponent: 32, bitsPerPixel: 32 * 3, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: kCGBitmapByteOrder32Host.rawValue | CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.none.rawValue))!
        
        defer {
            imgBuffer.data.deallocate()
            destinationBuffer.data.deallocate()
        }
        let returnImage = try? destinationBuffer.createCGImage(format: rgbImageFormat)
        return returnImage
    }
    
}

struct InspectorView: View {
    @Environment(\.modelContext) private var modelContext
    
    @ObservedObject var batRecording: BatRecording
    @Binding var selectedCall: CallMeasurements?
    @Binding var batchResults: Dictionary<String, Int>?
    
    var body: some View {
        VStack {
            Text("Calls")
            Button {
                self.findCalls()
            } label: {
                Label("Find calls", systemImage: "waveform.badge.magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            if !(self.batRecording.calls.isEmpty) {
                List(self.batRecording.calls, id: \.self, selection: $selectedCall) { aCall in
                    HStack {
                        Text("\(aCall.callNumber)")
                        if !aCall.species.isEmpty {
                            Text("\(aCall.species) \(aCall.speciesProb, specifier: "%.2f")")
                                .font(.footnote)
                        } else {
                            Text("No species")
                        }
                    }
                    
                }
                .frame(minHeight: 200, idealHeight: 200, maxHeight: 400)
            }
            if let batchResults {
                // Convert keys to an Array (and sort for stable ordering) to satisfy List's requirements
                let sortedKeys = Array(batchResults.keys).sorted(by: { batchResults[$0]! > batchResults[$1]! })
                //let sortedKeys = Array(batchResults.keys).sorted()
                List(sortedKeys, id: \.self) { key in
                    if let count = batchResults[key] {
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(count)")
                        }
                    }
                }
            }
            Spacer()
        }
    }
    
    func findCalls() {
        self.batRecording.findCalls()
    }
}


/*
 #Preview {
 DetailView()
 }
 */
