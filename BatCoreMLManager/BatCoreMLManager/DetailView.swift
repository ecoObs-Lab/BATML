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
import UniformTypeIdentifiers

import Vision
internal import Combine

struct DetailView: View {
    
    @Environment(\.modelContext) private var modelContext
    
    @State var recordingEntry: RecordingInput?
    @State private var batRecording: BatRecording?
    @State private var calls: Array<CallMeasurements>? = nil
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
    
    @State private var tapLocX: Int = 0
    @State private var findFB: Bool = false
    
    @State private var lowValue: Float = 0.2
    @State private var highValue: Float = 0.9
        
    @State private var creatingAnnotation = false
    @State private var movingAnnotation = false
    //@State private var newAnnotationCenter = CGPoint.zero
    @State private var newAnnotationOrigin = CGPoint.zero
    //@State private var newAnnotationCorner = CGPoint.zero
    @State private var movingAnnotationSize = CGSize.zero
    
    @AppStorage("LastAnnotationLabel") private var annotLabel: String = "Label"
    
    @State private var newAnnotationSize:CGSize = CGSize.zero
    /*{
      CGSize(
        width: abs(newAnnotationCenter.x - newAnnotationCorner.x) * 2,
        height: abs(newAnnotationCenter.y - newAnnotationCorner.y) * 2
      )
    }*/
    
    private var newAnnotationCenter : CGPoint {
        CGPoint(x: newAnnotationOrigin.x + 0.5 * newAnnotationSize.width, y: newAnnotationOrigin.y + 0.5 * newAnnotationSize.height)
    }
    
    var newAnnotation: CGRect {
      CGRect(origin: newAnnotationOrigin, size: newAnnotationSize)
    }
    
    @State private var annotations: [CoreMLAnnotation] = []
    
    @State private var currentProcessingFrame = 0
    @State private var autoContinue: Bool = false
    
    private let objDetector = ObjectDetector()
    
    var body: some View {
        VStack {
            if self.batRecording == nil {
                Text("No audio data")
            }
            else {
                BatSoundOverView(batRecording: $batRecording, selectedCall: $selectedCall, sonaWidth: 800, waveFillColor: .blue, waveHeight: 64)
                    .frame(width: 800)
                    .onTapGesture() { location in
                        if let batRecording = self.batRecording, let samplecount = batRecording.soundContainer?.header?.sampleCount {
                            let midSample = location.x/800.0 * Double(samplecount)
                            self.tapLocX = Int(midSample)
                            self.updateViewDataFromTap(location: Int(midSample))
                            inspectorShown = true
                            self.annotations.removeAll()
                        }
                    }
                HStack {
#if VIEWER
                    /*Button {
                        findFB = false
                        processSound()
                    } label: {
                        Label("Find calls", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent) */
                    
                    Button {
                        findFB = true
                        processSoundFB()
                    } label: {
                        Label("Find feeding buzzes", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    /*Button {
                        let op = NSOpenPanel()
                        op.allowedContentTypes = [.image]
                        if op.runModal() == .OK, let url = op.url, let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            let newSonaImage = Image<RGBA<Float>>(cgImage: image)
                            
                            objDetector.detectObjectsFB(in: newSonaImage.rotated(byDegrees: 90).cgImage)
                        }
                    } label: {
                        Label("Use image", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)*/

#elseif !VIEWER
                    Button {
                        self.findCalls()
                        if !(batRecording?.calls.isEmpty ?? true) {
                            inspectorShown = true
                        }
                    } label: {
                        Label("Find calls", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
#endif
                }
            }
            if self.singleSona != nil {
                HStack {
                    VStack {
#if VIEWER
                        Image(singleSona!,
                              scale: 1.0,
                              orientation: .left,
                              label: Text("Call Sonagram"))
                        .overlay(
                            ForEach(objDetector.detectedObjects) { detectedObject in
                                if detectedObject.confidence >= 0.9 {
                                    let bounds = self.observationToRect2(box: detectedObject.boundingBox)
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
                                                .position(x: bounds.midX, y: bounds.midY)
                                                .offset(x: bounds.width / 2, y: -10)
                                        )
                                }
                            }
                        )
                        
#elseif !VIEWER
                        Image(singleSona!,
                              scale: 1.0,
                              orientation: .left,
                              label: Text("Call Sonagram"))
                        .gesture(
                            DragGesture()
                                .onChanged {
                                    if !self.creatingAnnotation {
                                        self.creatingAnnotation.toggle()
                                        //self.newAnnotationOrigin = CGPoint(x: min($0.startLocation.x, $0.location.x), y: min($0.startLocation.y, $0.location.y))
                                    }
                                    self.newAnnotationOrigin = CGPoint(x: min($0.startLocation.x, $0.location.x), y: min($0.startLocation.y, $0.location.y))
                                    self.newAnnotationSize = CGSize(width: abs($0.location.x - $0.startLocation.x), height: abs($0.location.y - $0.startLocation.y))
                                }
                                .onEnded { _ in
                                    let newAnnotation = CoreMLAnnotation(annotationCoordinates: newAnnotation, annotationLabel: annotLabel)
                                    //modelContext.insert(newAnnotation)
                                    annotations.append(newAnnotation)
                                    self.creatingAnnotation.toggle()
                                }
                        )
                        .overlay(
                            self.annotationsBody
                        )
                        .border(.blue)
#endif // !VIEWER
                        
#if !VIEWER
                        HStack {
                            Slider(value: $callSonaGain, in: -128...128) { editing in
                                if !editing {
                                    if selectedCall != nil {
                                        self.updateViewData()
                                    }
                                    else {
                                        self.updateViewDataFromTap(location: self.tapLocX)
                                    }
                                }
                            }
                            .frame(width: 80)
                            Slider(value: $callSonaSpread, in: -5...5) { editing in
                                if !editing {
                                    if selectedCall != nil {
                                        self.updateViewData()
                                    }
                                    else {
                                        self.updateViewDataFromTap(location: self.tapLocX)
                                    }
                                }
                            }
                            .frame(width: 80)
                            TextField("Before", value: self.$samplesAhead, formatter:NumberFormatter())
                                .frame(width: 75)
                            TextField("After", value: self.$samplesAfter, formatter:NumberFormatter())
                                .frame(width: 75)
                            Button("IN") {
                                self.histoStretchIn()
                            }
                            TextField("Low", value: self.$lowValue, format: .number)
                                .frame(width: 33)
                            TextField("High", value: self.$highValue, format: .number)
                                .frame(width: 33)
                        }
                        .border(.blue)
// !VIEWER
#elseif VIEWER
                        HStack {
                            Slider(value: $callSonaGain, in: -128...128) { editing in
                                if !editing {
                                    if !findFB {
                                        if self.currentProcessingFrame > 0 {
                                            self.currentProcessingFrame -= Int(Double(recommendedSize) * 0.75)
                                        }
                                        self.processSound()
                                    }
                                }
                            }
                            .frame(width: 100)
                            Slider(value: $callSonaSpread, in: -5...5) { editing in
                                if !editing {
                                    if !findFB {
                                        if self.currentProcessingFrame > 0 {
                                            self.currentProcessingFrame -= Int(Double(recommendedSize) * 0.75)
                                        }
                                        self.processSound()
                                    }
                                }
                            }
                            .frame(width: 100)
                        }
                        #endif
                    }
#if !VIEWER
                    VStack {
                        Button("Identify") {
                            var img = Image<RGBA<Float>>(cgImage: singleSona!)
                            
                            objDetector.detectObjects(in: img.rotated(byDegrees: -90).cgImage)
                        }
                        //ext("\(self.objDetector.detectedObjects)")
                        Text("Annotation")
                        TextField("Label", text: $annotLabel)
                            .frame(width: 100)
                    }
                    .border(.blue)
#elseif VIEWER
                    VStack {
                        Button("Continue") {
                            if !findFB {
                                processSound()
                            } else {
                                processSoundFB()
                            }
                        }
                        Toggle("Auto-Continue", isOn: $autoContinue)
                        List(objDetector.detectedObjects) { object in
                            Text("\(object.label) \(object.confidence * 100.0, format: .number.precision(.fractionLength(0)))%")
                        }
                        .frame(height: 200)
                    }
                    .frame(height: 400)
#endif // !VIEWER
                }
                .border(.blue)
                //.frame(minWidth: 800)
                //.border(.gray)
            }
            Spacer()
        }
        .inspector(isPresented: $inspectorShown) {
            if batRecording != nil {
                InspectorView(batRecording: batRecording!, selectedCall: $selectedCall, annotations: $annotations, singleSona: $singleSona)
                    .padding()
                    .inspectorColumnWidth(min: 150, ideal: 225, max: 350)
            }
        }
        .onAppear() {
            self.updateBatRecording()
        }
        .onChange(of: recordingEntry) {
            self.updateBatRecording()
        }
        .onChange(of: selectedCall) {
            self.annotations.removeAll()
            self.objDetector.detectedObjects.removeAll()
            if self.selectedCall != nil {
                    self.updateViewData()
            }
        }
        .onChange(of: [samplesAfter, samplesAhead]) {
            if self.selectedCall != nil {
                if self.singleSona != nil {
                    self.updateViewData()
                }
            }
        }
    }
    
    func updateBatRecording() {
        guard let secBookmark = recordingEntry?.secBookmark else {
            return
        }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: secBookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            
            if !stale {
                let accessing = url.startAccessingSecurityScopedResource()
                
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                if let batRecording = try? BatRecording(audioURL: url) {
                    self.batRecording = batRecording
                    self.selectedCall = nil
                    self.calls = batRecording.calls
                    findFB = true
                    processSoundFB()
                }
            } else {
                print("Not stale")
            }
        }
        else {
            print("Access error")
        }
    }
    
    func callBackFromDetection(_ results: [DetectedObject]?) {
        
        if results?.isEmpty ?? true || self.autoContinue {
            if !findFB {
                processSound()
            } else {
                processSoundFB()
            }
        }
    }
    
    func processSound() {
        if objDetector.callback == nil {
            objDetector.callback = callBackFromDetection(_:)
        }
        guard let batRecording = self.batRecording else {
            self.singleSona = nil
            return
        }
        
        //let recommendedSize = 35000//20000
        let sonaStart = currentProcessingFrame
        let sonaSize = recommendedSize
        
        
        if sonaStart + sonaSize + recommendedSize >= batRecording.soundContainer!.header!.sampleCount {
            return
        }
        
        //let overlap: Float = 0.93 //0.96
                
        if let sona = batRecording.sonagramImage(from: sonaStart, size: sonaSize, fftParameters: FFTAnalyzer.FFTSettings(fftSize: 1024, overlap: overlap, window: .seventermharris), gain: Float(self.callSonaGain), spreadFactor: Float(self.callSonaSpread), colorType: .RX) {
            self.singleSona = sona.cropping(to: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 463, height: 463)))
            
            self.histoStretchIn()
            //self.histoStretchIn()
        }

        let img = Image<RGBA<Float>>(cgImage: singleSona!)
        objDetector.detectObjects(in: img.rotated(byDegrees: -90).cgImage)
        self.currentProcessingFrame += Int(Double(recommendedSize) * 0.75)
    }
    
    func processSoundFB() {
        if objDetector.callback == nil {
            objDetector.callback = callBackFromDetection(_:)
        }
        guard let batRecording = self.batRecording else {
            self.singleSona = nil
            return
        }
        
        //let recommendedSize = 35000//20000
        var sonaStart = currentProcessingFrame
        let sonaSize = 250000
        
        if sonaStart >= batRecording.soundContainer!.header!.sampleCount { return }
        
        if sonaStart + sonaSize >= batRecording.soundContainer!.header!.sampleCount {
            sonaStart = batRecording.soundContainer!.header!.sampleCount - sonaSize
        }
        
        //let overlap: Float = 0.93 //0.96
        
        if let sona = batRecording.sonagramImage(from: sonaStart, size: sonaSize, fftParameters: FFTAnalyzer.FFTSettings(fftSize: 1024, overlap: 0.75, window: .hamming), gain: Float(self.callSonaGain), spreadFactor: Float(self.callSonaSpread), colorType: .RX) {
            if sona.height < 400 { return }
            self.singleSona = sona.cropping(to: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 480, height: 960)))
            
            self.histoStretchIn()
        }
        //let newSonaImage = Image<RGBA<Float>>(cgImage: singleSona!)
        //objDetector.detectObjectsFB(in: newSonaImage.rotated(byDegrees: -90).cgImage )
        objDetector.detectObjectsFB(in: singleSona!)
        self.currentProcessingFrame += Int(Double(200000) * 0.75)
        
        /*let newSonaImage = Image<RGBA<Float>>(cgImage: singleSona!)
        let bitmapRep = NSBitmapImageRep(cgImage: newSonaImage.rotated(byDegrees: -90).cgImage)
        if let data = bitmapRep.representation(using: .jpeg, properties: [:]) {
            try? data.write(to: batRecording.audioURL!.deletingLastPathComponent().appendingPathComponent("\(Int.random(in: 0..<10000)).jpg"))
        }*/
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
            
            self.histoStretchIn()
            //self.histoStretchIn()
        }
    }
    
    func updateViewDataFromTap(location: Int) {
        guard let batRecording = self.batRecording else {
            self.singleSona = nil
            return
        }
        let callStart = location - 125000
        let callSize = 250000
        var sonaStart = max(callStart,0)
        var sonaSize = callSize
        if sonaSize + sonaStart > batRecording.soundContainer!.header!.sampleCount {
            sonaSize = batRecording.soundContainer!.header!.sampleCount - sonaStart
        }
        
        if let sona = batRecording.sonagramImage(from: sonaStart, size: sonaSize, fftParameters: FFTAnalyzer.FFTSettings(fftSize: 1024, overlap: 0.75, window: .hamming), gain: Float(self.callSonaGain), spreadFactor: Float(self.callSonaSpread), colorType: .RX) {
            self.singleSona = sona.cropping(to: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 480, height: 960)))
            
            self.histoStretchIn()
            //self.histoStretchIn()
        }
    }
    
    func histoStretchIn() {
        guard var imgBuffer = try? vImage_Buffer(cgImage: self.singleSona!), var destinationBuffer = try? vImage_Buffer(cgImage: self.singleSona!)  else {
            return
        }
        let percLow: UInt32 = 90
        var percentLow: [UInt32]  = [percLow, percLow, percLow, percLow]
        var percentHigh: [UInt32] = [0, 0, 0, 0]
        
        
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
                    0.0,
                    highValue,
                    vImage_Flags(kvImageNoFlags)
                )
            }
        }
        
        let rgbImageFormat = vImage_CGImageFormat( bitsPerComponent: 32, bitsPerPixel: 32 * 3, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: kCGBitmapByteOrder32Host.rawValue | CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.none.rawValue))!
        
        if let img = try? destinationBuffer.createCGImage(format: rgbImageFormat) {
            self.singleSona = img
        }
        else {
            print("Error")
        }
    }
    
    func findCalls() {
        guard let secBookmark = recordingEntry?.secBookmark else {
            return
        }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: secBookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            
            if !stale {
                let accessing = url.startAccessingSecurityScopedResource()
                
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                guard self.batRecording != nil else { return }
                self.batRecording!.findCalls()
                self.calls = batRecording!.calls
            } else {
                print("Not stale")
            }
        }
        else {
            print("Access error")
        }
    }
    
    var annotationsBody: some View {
        ZStack { // (alignment: .topLeading) {
            if creatingAnnotation {
                Rectangle()
                    .frame(width: newAnnotationSize.width, height: newAnnotationSize.height)
                    .position(newAnnotationCenter)
                    .foregroundColor(.blue)
                    .opacity(0.5)
            }
            ForEach(annotations) { annotation in
                Rectangle()
                    .frame(width: annotation.width, height: annotation.height)
                    .position(annotation.center)
                    .foregroundColor(.blue)
                    .opacity(0.5)
                    .overlay(
                        Text("\(annotation.annotationLabel)")
                            .lineLimit(1)
                            .fixedSize()
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .background(Color.blue)
                            .position(annotation.center)
                            .offset(x: annotation.width / 2, y: annotation.height / 2)
                    )
                /*.onTapGesture {
                 self.image.toggle(annotation: annotation)
                 }
                 .gesture(
                 DragGesture()
                 .onChanged {
                 if !self.movingAnnotation {
                 self.movingAnnotation.toggle()
                 self.image.beginMoving(annotation: annotation)
                 self.movingAnnotationSize = annotation.size.scaledBy(self.scaleFactor)
                 }
                 self.newAnnotationCenter = $0.location
                 }
                 .onEnded { _ in
                 self.image.move(annotation: annotation, to: self.newAnnotationCenter.scaledBy(1 / self.scaleFactor))
                 self.movingAnnotation.toggle()
                 }
                 )*/
            }
        }
      //.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func observationToRect2(box: CGRect)->CGRect
    {
        
        var bbBox = VNImageRectForNormalizedRect(box, Int(singleSona!.height), Int(singleSona!.width))
        bbBox.origin.y = CGFloat(self.singleSona!.width) - bbBox.origin.y - bbBox.size.height
        let rect = bbBox
        print("\(box)")
        print("\(bbBox)")
        print("\(rect)")
        return rect
        /*let bbBox = box
        let bottomToTopTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
        let rect = bbBox.applying(bottomToTopTransform)
        let returnBounds = VNImageRectForNormalizedRect(rect, Int(singleSona!.width), Int(singleSona!.height))
        print("\(singleSona!.width) \(singleSona!.height)")
        print("\(box) \(returnBounds)")
        return returnBounds*/
    }
    
}

struct InspectorView: View {
    @Environment(\.modelContext) private var modelContext
    
    @ObservedObject var batRecording: BatRecording
    @Binding var selectedCall: CallMeasurements?
    @Binding var annotations: Array<CoreMLAnnotation>
    @Binding var singleSona: CGImage?
    @State private var selectedAnnotation: CoreMLAnnotation?
    
    var body: some View {
        VStack {
            Text("Calls")
            if !(self.batRecording.calls.isEmpty) {
                List(self.batRecording.calls, id: \.self, selection: $selectedCall) { aCall in
                    HStack {
                        Text("\(aCall.callNumber)")
                        Text("\(aCall.getCallStart())")
                    }
                }
                .frame(minHeight: 200, idealHeight: 300, maxHeight: 400)
            }
            Text("Annotations")
            if !self.annotations.isEmpty {
                List(self.annotations, id: \.self, selection: $selectedAnnotation) { anAnnotation in
                    HStack {
                        Text("\(anAnnotation.annotationLabel)")
                    }
                }
                .frame(minHeight: 100, idealHeight: 200, maxHeight: 300)
            }
            if !self.annotations.isEmpty {
                Button {
                    
                    let newSonaImage = Image<RGBA<Float>>(cgImage: singleSona!)
                    
                    let bitmapRep = NSBitmapImageRep(cgImage: newSonaImage.rotated(byDegrees: -90).cgImage)
                    guard let data = bitmapRep.representation(using: .jpeg, properties: [:]), let urlNoExt = self.batRecording.audioURL?.deletingPathExtension() else { return }
                    
                    for anAnnotation in annotations {
                        modelContext.insert(anAnnotation)
                    }
                    
                    let name = urlNoExt.lastPathComponent.appending("-call-\(self.selectedCall?.callNumber ?? Date().hashValue)")
                    let newImage = ImageOutput(timestamp: Date(), name: name, imageData: data)
                    newImage.annotations = annotations
                    modelContext.insert(newImage)
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
            if self.selectedAnnotation != nil {
                @Bindable var annon = self.selectedAnnotation!
                TextField("Label", text: $annon.annotationLabel)
                let r = selectedAnnotation!.rect
                Text("x: \(r.origin.x), y: \(r.origin.y), w: \(r.size.width), h: \(r.size.height)")
                    .font(.footnote)
                Button {
                    annotations.removeAll { annot in
                        annot == self.selectedAnnotation!
                    }
                    self.selectedAnnotation = nil
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                
            }
            Spacer()
        }
    }
}


/*
 #Preview {
 DetailView()
 }
 */
