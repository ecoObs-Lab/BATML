//
//  SonaView.swift
//  FeedingBuzzer
//
//  Created by Volker Runkel on 30.03.26.
//

import SwiftUI
import BatSoundHandling
import Accelerate

struct SonaView: View {
    
    @AppStorage("callSonaSpread") var callSonaSpread: Double = 1.84
    @AppStorage("callSonaGain") var callSonaGain: Double = 84
    @AppStorage("sonaColor") var sonaColorScheme: Int = 5
    
    @State var soundURL: URL
    @State private var sonaImg: CGImage?
    var body: some View {
        Text("Setup sona")
            .task {
                updateSonagram()
            }
        if sonaImg != nil {
            Image(sonaImg!, scale: 1, orientation: .left, label: Text("Sona"))
            HStack {
                Slider(value: $callSonaGain, in: -128...128) { editing in
                    if !editing {
                        updateSonagram()
                    }
                }
                .frame(width: 100)
                Slider(value: $callSonaSpread, in: -5...5) { editing in
                    if !editing {
                        updateSonagram()
                    }
                }
                .frame(width: 100)
                Picker("Color scheme", selection: $sonaColorScheme) {
                    Text("Gray").tag(2)
                    Text("Red").tag(3)
                    Text("Bright").tag(4)
                    Text("RX").tag(5)
                }
                Button("Default sona settings") {
                    callSonaSpread = 1.84
                    callSonaGain = 84
                    sonaColorScheme = 5
                    updateSonagram()
                }
                .onChange(of: sonaColorScheme) {
                    updateSonagram()
                }
            }
            .padding()
        }
    }
    
    private func updateSonagram() {
        if let batRecording = try? BatRecording(audioURL: soundURL), let header = batRecording.soundContainer!.header, header.samplerate >= 384000 {
            var currentProcessingFrame = 0
            
            if currentProcessingFrame < batRecording.soundContainer!.header!.sampleCount {
                var sonaStart = currentProcessingFrame
                let sonaSize = 250000
                
                if sonaStart >= batRecording.soundContainer!.header!.sampleCount { return }
                
                if sonaStart + sonaSize >= batRecording.soundContainer!.header!.sampleCount {
                    sonaStart = batRecording.soundContainer!.header!.sampleCount - sonaSize - 1
                }
                
                //let overlap: Float = 0.93 //0.96
                
                if let sona = batRecording.sonagramImage(from: sonaStart, size: sonaSize, fftParameters: FFTAnalyzer.FFTSettings(fftSize: 1024, overlap: 0.75, window: .hamming), gain: Float(self.callSonaGain), spreadFactor: Float(self.callSonaSpread), colorType: FFTAnalyzer.ColorType(rawValue: sonaColorScheme)!) {
                    if sona.height < 400 { return }
                    if let singleSona = sona.cropping(to: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 480, height: 960))), let newSona = self.histoStretchIn(singleSona: singleSona) {
                        self.sonaImg = newSona
                    }
                }
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
}
