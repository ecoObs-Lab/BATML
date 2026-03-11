//
//  FFTAnalyzer.swift
//  bcAdmin4
//
//  Created by Volker Runkel on 28.11.16.
//  Copyright © 2016 ecoObs GmbH. All rights reserved.
//

import Foundation
import Accelerate
import CoreGraphics
import SwiftUI
import SwiftImage

#if os(macOS)
import Quartz
import QuartzCore
#endif

#if os(iOS)
import UIKit
#endif


public final class FFTAnalyzer {
    
    public enum WindowFunctions : Int {
        case rectangle
        case hanning
        case hamming
        case bartlet
        case blackman
        case flattop
        case seventermharris
        case hannpoisson
        case powersin
    }
    
    public struct FFTSettings {
        public var fftSize: Int
        public var overlap: Float
        public var window: WindowFunctions
        
        public init(fftSize: Int, overlap: Float, window: WindowFunctions) {
            self.fftSize = fftSize
            self.overlap = overlap
            self.window = window
        }
    }
    
    public enum ColorType: Int {
        case GREY = 2
        case RED = 3
        case BRIGHT = 4
        case RX = 5
    }
    
    private var lastdBGain: Float = 0.0
    
    private var log2N4096: vDSP_Length?
    private var fftsetup4096: FFTSetup?
    
    private var log2N2048: vDSP_Length?
    private var fftsetup2048: FFTSetup?
    
    private var log2N1024: vDSP_Length?
    private var fftsetup1024: FFTSetup?
    
    private var log2N512: vDSP_Length?
    private var fftsetup512: FFTSetup?
    
    private var log2N256: vDSP_Length?
    private var fftsetup256: FFTSetup?
    
    init() {
        log2N4096 = vDSP_Length(log2(Double(4096)))
        fftsetup4096 = vDSP_create_fftsetup(log2N4096!, FFTRadix(kFFTRadix2))
        
        log2N2048 = vDSP_Length(log2(Double(2048)))
        fftsetup2048 = vDSP_create_fftsetup(log2N2048!, FFTRadix(kFFTRadix2))
        
        log2N1024 = vDSP_Length(log2(Double(1024)))
        fftsetup1024 = vDSP_create_fftsetup(log2N1024!, FFTRadix(kFFTRadix2))
        
        log2N512 = vDSP_Length(log2(Double(512)))
        fftsetup512 = vDSP_create_fftsetup(log2N512!, FFTRadix(kFFTRadix2))
        
        log2N256 = vDSP_Length(log2(Double(256)))
        fftsetup256 = vDSP_create_fftsetup(log2N256!, FFTRadix(kFFTRadix2))
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftsetup4096)
        vDSP_destroy_fftsetup(fftsetup2048)
        vDSP_destroy_fftsetup(fftsetup1024)
        vDSP_destroy_fftsetup(fftsetup512)
        vDSP_destroy_fftsetup(fftsetup256)
    }
        
    func calculateAnalysisWindowForBuffer(numberOfSamples: Int, windowType:Int)->(Float, [Float]) {
        
        var window = [Float](repeating:1.0, count:numberOfSamples) // also rectangle!
        let halfWindow = numberOfSamples / 2
        switch windowType {
        case 1: // Hanning
            vDSP_hann_window(&window, vDSP_Length(numberOfSamples), 0) // Hann
        case 2: vDSP_hamm_window(&window, vDSP_Length(numberOfSamples), 0) // Hamm
        case 3:
            for index in 0..<numberOfSamples {
                window[index] = 1 - (Float(index) / Float(halfWindow))
            }
        case 4: vDSP_blkman_window(&window, vDSP_Length(numberOfSamples), 0) // Blckman
        case 5: // Flattop
            for index in 0..<numberOfSamples {
                var value: Double = 1 - 1.933 * cos(2 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 1.286 * cos(4 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value - 0.388 * cos(6 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 0.032 * cos(8 * .pi * Double(index)/Double(numberOfSamples-1))
                window[index] = Float(value)
            }
        case 6: // quick 7term harris hack
            for index in 0..<numberOfSamples {
                var value: Double = 0.27122036 - 0.4334461*cos(2 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 0.2180041*cos(4 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value - 0.0657853 * cos(6 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 0.010761867 * cos(8 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value - 0.000770012*cos(10 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 0.0000136*cos(12 * .pi * Double(index)/Double(numberOfSamples-1))
                window[index] = Float(value)
            }
        case 7: // Hann-Poisson
            for index in 0..<numberOfSamples {
                let value: Double = 0.5 * (1 - cos(2 * .pi / Double(numberOfSamples))) * exp((-2*abs(Double(numberOfSamples) - Double(2*index))) / Double(numberOfSamples))
                window[index] = Float(value)
            }
        case 8: // Power of sin/cos
            for index in 0..<numberOfSamples {
                let value: Double = pow(sin((.pi * Double(index) / Double(numberOfSamples))), 16)
                
                window[index] = Float(value)
            }
        case 9: // cheby
            
            func chebyshev_polynomial(n: Int, x: Double) -> Double {
                if n == 0 {
                    return 1.0
                } else if n == 1 {
                    return x
                } else {
                    return 2 * x * chebyshev_polynomial(n: n-1,  x: x) - chebyshev_polynomial(n: n - 2, x: x)
                }
            }
            
            let M = numberOfSamples
            let A = pow(10.0, /*sidelobe_attenuation_db*/ 12.0 / 20.0)
            let beta = acosh(A) / Double(M)
            
            let alpha = (Double(M) - 1.0) / 2.0

            for index in 0..<numberOfSamples {
                let value: Double = cos(.pi * (Double(index) - alpha) / Double(M))
                let temp = chebyshev_polynomial(n: M - 1, x: cosh(beta) * value)
                
                window[index] = Float(temp / chebyshev_polynomial(n:M - 1, x: cosh(beta)))
            }
        default: window[0] = 1.0
        }
        let sum = window.reduce(.zero, +)
        let dBGain = 20.0 * log10(sum/Float(numberOfSamples))
        return (dBGain,window)
    }
    
    func calculateAnalysisWindow(numberOfSamples: Int, windowType:Int)->[Float] {
        
        var window = [Float](repeating:1.0, count:numberOfSamples) // also rectangle!
        let halfWindow = numberOfSamples / 2
        switch windowType {
        case 1: // Hanning
            vDSP_hann_window(&window, vDSP_Length(numberOfSamples), 0) // Hann
        case 2: vDSP_hamm_window(&window, vDSP_Length(numberOfSamples), 0) // Hamm
        case 3:
            for index in 0..<numberOfSamples {
                window[index] = 1 - (Float(index) / Float(halfWindow))
            }
        case 4: vDSP_blkman_window(&window, vDSP_Length(numberOfSamples), 0) // Blckman
        case 5: // Flattop
            for index in 0..<numberOfSamples {
                var value: Double = 1 - 1.933 * cos(2 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 1.286 * cos(4 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value - 0.388 * cos(6 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 0.032 * cos(8 * .pi * Double(index)/Double(numberOfSamples-1))
                window[index] = Float(value)
            }
        case 6: // quick 7term harris hack
            for index in 0..<numberOfSamples {
                var value: Double = 0.27122036 - 0.4334461*cos(2 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 0.2180041*cos(4 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value - 0.0657853 * cos(6 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 0.010761867 * cos(8 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value - 0.000770012*cos(10 * .pi * Double(index)/Double(numberOfSamples-1))
                value = value + 0.0000136*cos(12 * .pi * Double(index)/Double(numberOfSamples-1))
                window[index] = Float(value)
            }
        case 7: // Hann-Poisson
            for index in 0..<numberOfSamples {
                let value: Double = 0.5 * (1 - cos(2 * .pi / Double(numberOfSamples))) * exp((-2*abs(Double(numberOfSamples) - Double(2*index))) / Double(numberOfSamples))
                window[index] = Float(value)
            }
        case 8: // Power of sin/cos
            for index in 0..<numberOfSamples {
                let value: Double = pow(sin((.pi * Double(index) / Double(numberOfSamples))), 16)
                
                window[index] = Float(value)
            }
        default: window[0] = 1.0
        }
        let sum = window.reduce(.zero, +)
        let dBGain = 20.0 * log10(sum/Float(numberOfSamples))
        self.lastdBGain = dBGain
        return window
    }
    
    internal func spectrumForValuesBetterMemoryPointer(signal: UnsafeMutablePointer<Float>, fftsetup: FFTSetup, count: Int = 512) -> [Float] {
        // Find the largest power of two in our samples
        let log2N = vDSP_Length(log2(Double(count)))
        let n = 1 << log2N
        let fftLength = n / 2
        
        
        var fft = [Float](repeating:0.0, count:Int(n))
        
        // Generate a split complex vector from the real data
        var realp = [Float](repeating:0.0, count:Int(fftLength))
        var imagp = realp
        
        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp:realPtr.baseAddress!, imagp:imagPtr.baseAddress!)
                UnsafePointer(signal).withMemoryRebound(to: DSPComplex.self, capacity: 1) {
                    vDSP_ctoz($0, 2, &splitComplex, 1, vDSP_Length(fftLength))
                }
                vDSP_fft_zrip(fftsetup, &splitComplex, 1, log2N, FFTDirection(kFFTDirection_Forward))
                
                // Normalize
                var normFactor: Float = 1.0 / Float(n*2)
                vDSP_vsmul(splitComplex.realp, 1, &normFactor, splitComplex.realp, 1, vDSP_Length(fftLength))
                vDSP_vsmul(splitComplex.imagp, 1, &normFactor, splitComplex.imagp, 1, vDSP_Length(fftLength))
                
                // Zero out Nyquist
                splitComplex.imagp[0] = 0.0
                
                // Convert complex FFT to magnitude
                var b: Float = 1
                vDSP_zvmags(&splitComplex, 1, &fft, 1, vDSP_Length(fftLength))
                
                var kAdjust0DB : Float = 1.5849e-13
                var _fft = fft
                vDSP_vsadd(&_fft, 1, &kAdjust0DB, &fft, 1, vDSP_Length(fftLength));
                vDSP_vdbcon(&_fft, 1, &b, &fft, 1, vDSP_Length(fftLength), 1);
            }
        }
        return fft
    }
    
    public func spectrumData(fromSamples: [Float]!, startSample: Int = 0, numberOfSamples: Int!, FFTSize: Int = 0, Window: Int = 0, ScaleFactor: Float = 128.0 / 96.0) -> [Float]? {
        if FFTSize == 0 || numberOfSamples == 0 {
            return nil
        }
        
        var b = [Float](repeating: 0.0, count: FFTSize)
        var fft = [Float](repeating:0.0, count:Int(FFTSize))
        let window = calculateAnalysisWindowForBuffer(numberOfSamples: FFTSize, windowType:Window)
        let log2N = vDSP_Length(log2(Double(FFTSize)))
        let fftsetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2))
        
        b[0..<FFTSize] = fromSamples[startSample..<FFTSize+startSample]
        
        b.withUnsafeMutableBufferPointer { bPtr in
            vDSP_vmul(window.1,1,bPtr.baseAddress!,1,bPtr.baseAddress!,1,vDSP_Length(FFTSize))
            fft =  spectrumForValuesBetterMemoryPointer(signal: bPtr.baseAddress!, fftsetup: fftsetup!)
        }
        
        vDSP_destroy_fftsetup(fftsetup)
        
        return Array(fft[0..<FFTSize/2])
    }
    
    public func spectrumHiresData(fromSamples: inout [Float]!, startSample: Int = 0, numberOfSamples: Int!, FFTSize: Int = 0, Window: Int = 0, ScaleFactor: Float = 128.0 / 96.0) -> [Float]? {
        
        if numberOfSamples == 0 {
            return nil
        }
        
        var i = 1.0
        while pow(2.0,i) < Double(numberOfSamples) {
            i += 1
        }
        
        let spectrumFFTSize = Int(pow(2,i))
        var b = [Float](repeating: 0.0, count: spectrumFFTSize)
        var fft = [Float](repeating:0.0, count: spectrumFFTSize)
        
        let dataStart = (spectrumFFTSize-numberOfSamples) / 2
        
        let window = calculateAnalysisWindowForBuffer(numberOfSamples: spectrumFFTSize, windowType:Window)
        let log2N = vDSP_Length(log2(Double(spectrumFFTSize)))
        let fftsetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2))
        var numberOfSamples = numberOfSamples
        if numberOfSamples!+startSample >= fromSamples.count {
            numberOfSamples = fromSamples.count - startSample - 1
        }
        var startSample = startSample
        if startSample < 0 {
            startSample = 0
        }
        
        if numberOfSamples!+startSample <= fromSamples.count {
            b[dataStart..<numberOfSamples!+dataStart] = fromSamples[startSample..<numberOfSamples!+startSample]
        }
        else {
            b[dataStart..<numberOfSamples!+dataStart] = fromSamples[(fromSamples.count-startSample)..<fromSamples.count]
        }

        if fftsetup == nil {
            return nil
        }
        
        b.withUnsafeMutableBufferPointer { bPtr in
            vDSP_vmul(window.1,1,bPtr.baseAddress!,1,bPtr.baseAddress!,1,vDSP_Length(spectrumFFTSize))
            fft = spectrumForValuesBetterMemoryPointer(signal: bPtr.baseAddress!, fftsetup: fftsetup!, count: spectrumFFTSize)
        }
        if self.lastdBGain != 0.0 {
            fft = fft.map{$0 - self.lastdBGain}
        }
        fft = vDSP.clip(fft, to: Float(-255)...Float(0.0))
        vDSP_destroy_fftsetup(fftsetup)
        return Array(fft[0..<spectrumFFTSize/2])
    }
    
    public func meanFrequency( fromSamples: inout [Float]!, startSample: Int, sizeSamples: Int) -> Float {
        var fftsize = sizeSamples
        var i = 0
        while (pow(2,Float(i)) < Float(sizeSamples)) {
            i += 1
        }
        fftsize = Int(pow(2,Float(i)))
        
        var callStart = startSample
        if startSample + fftsize >= fromSamples.count {
            callStart = fromSamples.count - fftsize - 1
        }
        
        if callStart < 0 {
            return 0
        }
        
        let fft = spectrumData(fromSamples: fromSamples, startSample: callStart, numberOfSamples: sizeSamples, FFTSize: fftsize, Window:0)
        
        var maxDB: Float = -255.0
        var maxFreq = 0.0
        var meanF: Float = 0.0
        for index in 1..<fftsize/2 {
            //float         mag = scale * sqrtf(real*real+imag*imag);
            //float		  value = scaleFactor * ((20.0 * log10f(mag))
            let value =  fft![index]
            
            if value > maxDB {
                maxDB = value
                maxFreq = Double(fftsize/2)/Double(index)
            }
        }
        meanF = Float(maxFreq)
        return meanF
        
    }
    
}

@available(macOS 13.0, *)
extension FFTAnalyzer {
        
    public func sonagramImageGrayImageBuffer(fromSamples: inout [Float]!, startSample: Int = 0, numberOfSamples: Int!, FFTSize: Int = 256, Overlap: Float = 0.75, Window: Int = 0, ScaleFactor: Float = 128.0 / 96.0, gain: Double = 0.0) -> CGImage? {
        
        let halfSize = FFTSize / 2
        var sampleOverlap =  Int(ceil((Float(FFTSize)*(1.0-Overlap))))
        var numberOfFrames = ((numberOfSamples /*- FFTSize*/) / sampleOverlap ) + 1
        if numberOfFrames > 30000 {
            numberOfFrames = 30000
            sampleOverlap = 1 + (numberOfSamples /*- FFTSize*/) / numberOfFrames
        }
                
        var frequencyDomainValues = [Float]()
        
        var b = [Float](repeating: 0.0, count: FFTSize) // will hold my data later
        let window = calculateAnalysisWindowForBuffer(numberOfSamples: FFTSize, windowType:Window)
        
        // we need a loop now that will move data slowly into b and calc ffts...
        var localStartSample = startSample
        if localStartSample < 0 {
            localStartSample = 0
        }
        var frameIndex: Int = localStartSample
        
        let log2N = vDSP_Length(log2(Double(FFTSize)))
        let fftsetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2))
        
        var imageWidth = 0
        //let start = DispatchTime.now()
        while (frameIndex + FFTSize - 1) < localStartSample+numberOfSamples {
            if frameIndex+FFTSize >= fromSamples.count {
                break
            }
            
            fromSamples.withUnsafeBufferPointer { fromPtr in
                b.withUnsafeMutableBufferPointer { bPtr in
                    _ = memcpy(bPtr.baseAddress,fromPtr.baseAddress?.advanced(by: frameIndex), FFTSize * MemoryLayout<Float>.size)
                }}
           
            /*b.withUnsafeMutableBufferPointer { bPtr in
                vDSP_vmul(window.1,1,bPtr.baseAddress!,1,bPtr.baseAddress!,1,vDSP_Length(FFTSize))
            }*/
            
            var fft = Array<Float>()
            
            b.withUnsafeMutableBufferPointer { bPtr in
                vDSP_vmul(window.1,1,bPtr.baseAddress!,1,bPtr.baseAddress!,1,vDSP_Length(FFTSize))
                fft =  spectrumForValuesBetterMemoryPointer(signal: bPtr.baseAddress!, fftsetup: fftsetup!, count: FFTSize)
            }
            
            //fft = vDSP.add(Float(gain), fft)
            if self.lastdBGain != 0.0 {
                //fft = fft.map{$0 - self.lastdBGain}
                fft = vDSP.add(self.lastdBGain, fft)
            }
            vDSP.multiply(Float(-1.0/256.0), fft, result: &fft)
            fft = vDSP.clip(fft, to: Float(0.0)...Float(1.0))
            
            frequencyDomainValues.append(contentsOf:fft[0..<halfSize])
            frameIndex += sampleOverlap;
            imageWidth += 1
        }
        
        let grayImageFormat = vImage_CGImageFormat( bitsPerComponent: 32, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: kCGBitmapByteOrder32Host.rawValue | CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.none.rawValue))!
        
        var grayBuffer = vImage.PixelBuffer<vImage.PlanarF>(
            width: halfSize,
            height: imageWidth)
               
        
        frequencyDomainValues.withUnsafeMutableBufferPointer {
            grayBuffer = vImage.PixelBuffer(
                data: $0.baseAddress!,
                width: halfSize,
                height: imageWidth,
                byteCountPerRow: halfSize * MemoryLayout<Float32>.stride,
                pixelFormat: vImage.PlanarF.self)
        }
        
        return grayBuffer.makeCGImage(cgImageFormat: grayImageFormat) ?? FFTAnalyzer.emptyCGImage
        
    }
    
    public func sonagramImageGrayImageBufferHires(fromSamples: inout [Float]!, startSample: Int = 0, numberOfSamples: Int!, FFTSize: Int = 256, Overlap: Float = 0.75, Window: Int = 0, ScaleFactor: Float = 128.0 / 96.0, gain: Double = 0.0) -> CGImage? {
        
        let halfSize = FFTSize / 2
        var subFFTSize = 256
        if FFTSize == subFFTSize {
            subFFTSize /= 2
        }
        let wFFT = subFFTSize
        var sampleOverlap =  Int(ceil((Float(wFFT)*(1.0-Overlap))))
        
        var numberOfFrames = ((numberOfSamples /*- FFTSize*/) / sampleOverlap ) + 1
        if numberOfFrames > 30000 {
            numberOfFrames = 30000
            sampleOverlap = 1 + (numberOfSamples /*- FFTSize*/) / numberOfFrames
        }
                
        var frequencyDomainValues = [Float]()
        
        var b = [Float](repeating: 0.0, count: FFTSize) // will hold my data later
        var bMid = [Float](repeating: 0.0, count: wFFT)
        let window = calculateAnalysisWindowForBuffer(numberOfSamples: wFFT, windowType:Window)
        
        // we need a loop now that will move data slowly into b and calc ffts...
        var localStartSample = startSample
        if localStartSample < 0 {
            localStartSample = 0
        }
        var frameIndex: Int = localStartSample
        
        let log2N = vDSP_Length(log2(Double(FFTSize)))
        let fftsetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2))
        
        var imageWidth = 0
        //let start = DispatchTime.now()
        while (frameIndex + subFFTSize - 1) < localStartSample+numberOfSamples {
            if frameIndex+subFFTSize >= fromSamples.count {
                break
            }
            
            fromSamples.withUnsafeBufferPointer { fromPtr in
                bMid.withUnsafeMutableBufferPointer { bPtr in
                    _ = memcpy(bPtr.baseAddress,fromPtr.baseAddress?.advanced(by: frameIndex), wFFT * MemoryLayout<Float>.size)
                }}
            
            bMid.withUnsafeMutableBufferPointer { bPtr in
                vDSP_vmul(window.1,1,bPtr.baseAddress!,1,bPtr.baseAddress!,1,vDSP_Length(wFFT))
            }
            
            b.replaceSubrange(wFFT..<wFFT*2, with: bMid)
            
            var fft = Array<Float>()
            
            b.withUnsafeMutableBufferPointer { bPtr in
                fft =  spectrumForValuesBetterMemoryPointer(signal: bPtr.baseAddress!, fftsetup: fftsetup!, count: FFTSize)
            }
            
            if self.lastdBGain != 0.0 {
                fft = vDSP.add(self.lastdBGain, fft)
            }
            vDSP.multiply(Float(-1.0/256.0), fft, result: &fft)
            fft = vDSP.clip(fft, to: Float(0.0)...Float(1.0))
            
            frequencyDomainValues.append(contentsOf:fft[0..<halfSize])
            frameIndex += sampleOverlap;
            imageWidth += 1
        }
        
        let grayImageFormat = vImage_CGImageFormat( bitsPerComponent: 32, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: kCGBitmapByteOrder32Host.rawValue | CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.none.rawValue))!
        
        var grayBuffer = vImage.PixelBuffer<vImage.PlanarF>(
            width: halfSize,
            height: imageWidth)
               
        
        let planarRotate = vImage.PixelBuffer<vImage.PlanarF>(width: imageWidth, height: halfSize)
        let planarScale = vImage.PixelBuffer<vImage.PlanarF>(width: imageWidth, height: halfSize)
        
        frequencyDomainValues.withUnsafeMutableBufferPointer {
            grayBuffer = vImage.PixelBuffer(
                data: $0.baseAddress!,
                width: halfSize,
                height: imageWidth,
                byteCountPerRow: halfSize * MemoryLayout<Float32>.stride,
                pixelFormat: vImage.PlanarF.self)
            
            _ = planarRotate.withUnsafePointerToVImageBuffer{ destPtr in
                grayBuffer.withUnsafePointerToVImageBuffer {srcPtr in
                    vImageRotate90_PlanarF(srcPtr, destPtr, 1, 1, vImage_Flags.max)
                }
            }
            
            _ = planarScale.withUnsafePointerToVImageBuffer{ destPtr in
                planarRotate.withUnsafePointerToVImageBuffer {srcPtr in
                    vImageVerticalReflect_PlanarF(srcPtr, destPtr, vImage_Flags.max)
                }
            }
        }
        vDSP_destroy_fftsetup(fftsetup)
        return planarScale.makeCGImage(cgImageFormat: grayImageFormat) ?? FFTAnalyzer.emptyCGImage
        
    }
    
    public func sonagramImageRGBAImageBuffer(fromSamples: inout [Float]!, startSample: Int = 0, numberOfSamples: Int!, FFTSize: Int = 256, Overlap: Float = 0.75, Window: Int = 0, ScaleFactor: Float = 128.0 / 96.0, gain: Float = 0.0, spreadFactor: Float = 1, colorType: Int, expanded: Bool = false) -> CGImage? {
        
        let halfSize = FFTSize / 2
        let sampleOverlap =  Int(ceil((Float(FFTSize)*(1.0-Overlap))))
        
        var b = [Float](repeating: 0.0, count: FFTSize) // will hold my data later
        let window = calculateAnalysisWindow(numberOfSamples: FFTSize, windowType:Window)
        
        // we need a loop now that will move data slowly into b and calc ffts...
        var localStartSample = startSample
        if localStartSample < 0 {
            localStartSample = 0
        }
        var frameIndex: Int = localStartSample
                
        var fftsetup = fftsetup512
        if FFTSize == 256 {
            fftsetup = fftsetup256
        } else if FFTSize == 1024 {
            fftsetup = fftsetup1024
        } else if FFTSize == 2048 {
            fftsetup = fftsetup2048
        } else if FFTSize == 4096 {
            fftsetup = fftsetup4096
        }
        
        var frequencyDomainValues = [Float]()
        frequencyDomainValues.reserveCapacity((halfSize * numberOfSamples / FFTSize))
        
        var imageWidth = 0
       
        while (frameIndex + FFTSize - 1) < localStartSample+numberOfSamples {
            if frameIndex+FFTSize >= fromSamples.count {
                break
            }
            
            fromSamples.withUnsafeBufferPointer { fromPtr in
                b.withUnsafeMutableBufferPointer { bPtr in
                    _ = memcpy(bPtr.baseAddress,fromPtr.baseAddress?.advanced(by: frameIndex), FFTSize * MemoryLayout<Float>.size)
                }}
            
            b.withUnsafeMutableBufferPointer { bPtr in
                vDSP_vmul(window,1,bPtr.baseAddress!,1,bPtr.baseAddress!,1,vDSP_Length(FFTSize))
            }
            
            var fft = Array<Float>()
            
            b.withUnsafeMutableBufferPointer { bPtr in
                fft =  spectrumForValuesBetterMemoryPointer(signal: bPtr.baseAddress!, fftsetup: fftsetup!, count: FFTSize)
            }
            
            
            fft = vDSP.add(128+Float(gain+self.lastdBGain), fft)
            
            if abs(spreadFactor - 1.0) > 0.1 {
                fft = vDSP.multiply(spreadFactor, fft)
            }
            
            
            vDSP.multiply(Float(1.0/256.0), fft, result: &fft)
            fft = vDSP.clip(fft, to: Float(0.0)...Float(1.0))
            
            frequencyDomainValues.append(contentsOf:fft[0..<halfSize])
            frameIndex += sampleOverlap;
            imageWidth += 1
        }
        
        let rgbImageFormat = vImage_CGImageFormat( bitsPerComponent: 32, bitsPerPixel: 32 * 3, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: kCGBitmapByteOrder32Host.rawValue | CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.none.rawValue))!
        
        
        let rgbImageBuffer = vImage.PixelBuffer<vImage.InterleavedFx3>(
            width: halfSize * (expanded ? 2 : 1),
            height: imageWidth)
        
        if !expanded {
        
            let redBuffer = vImage.PixelBuffer<vImage.PlanarF>(
                width: halfSize,
                height: imageWidth)
            
            let greenBuffer = vImage.PixelBuffer<vImage.PlanarF>(
                width: halfSize,
                height: imageWidth)
            
            let blueBuffer = vImage.PixelBuffer<vImage.PlanarF>(
                width: halfSize,
                height: imageWidth)
                       
            frequencyDomainValues.withUnsafeMutableBufferPointer {
                
                let planarImageBuffer = vImage.PixelBuffer(
                    data: $0.baseAddress!,
                    width: halfSize,
                    height: imageWidth,
                    byteCountPerRow: halfSize * MemoryLayout<Float>.stride,
                    pixelFormat: vImage.PlanarF.self)
                
                if colorType == 2 {
                    multidimensionalLookupTableGray.apply(
                        sources: [planarImageBuffer],
                        destinations: [redBuffer, greenBuffer, blueBuffer],
                        interpolation: .half)
                } else if colorType == 3 {
                    multidimensionalLookupTableRed.apply(
                        sources: [planarImageBuffer],
                        destinations: [redBuffer, greenBuffer, blueBuffer],
                        interpolation: .half)
                } else if colorType == 4 {
                    multidimensionalLookupTableBunt.apply(
                        sources: [planarImageBuffer],
                        destinations: [redBuffer, greenBuffer, blueBuffer],
                        interpolation: .half)
                }
                else if colorType == 5 {
                    multidimensionalLookupTable.apply(
                        sources: [planarImageBuffer],
                        destinations: [redBuffer, greenBuffer, blueBuffer],
                        interpolation: .half)
                }
                /*} else if self.colorTable == 1 {
                 FFTAnalyzer.multidimensionalLookupTable.apply(
                 sources: [planarImageBuffer],
                 destinations: [redBuffer, greenBuffer, blueBuffer],
                 interpolation: .half)
                 }*/
                
                
                rgbImageBuffer.interleave(
                    planarSourceBuffers: [redBuffer, greenBuffer, blueBuffer])
            }
        } else {
            let planarScale = vImage.PixelBuffer<vImage.PlanarF>(width: halfSize*2 , height:imageWidth)
            
            let redBuffer = vImage.PixelBuffer<vImage.PlanarF>(
                width: halfSize*2,
                height: imageWidth)
            
            let greenBuffer = vImage.PixelBuffer<vImage.PlanarF>(
                width: halfSize*2,
                height: imageWidth)
            
            let blueBuffer = vImage.PixelBuffer<vImage.PlanarF>(
                width: halfSize*2,
                height: imageWidth)
            
            frequencyDomainValues.withUnsafeMutableBufferPointer {
                
                let planarImageBuffer = vImage.PixelBuffer(
                    data: $0.baseAddress!,
                    width: halfSize,
                    height: imageWidth,
                    byteCountPerRow: halfSize * MemoryLayout<Float>.stride,
                    pixelFormat: vImage.PlanarF.self)
                
                _ = planarScale.withUnsafePointerToVImageBuffer{ destPtr in
                    planarImageBuffer.withUnsafePointerToVImageBuffer {srcPtr in
                        vImageScale_PlanarF(srcPtr, destPtr, nil, vImage.Options.highQualityResampling.rawValue)
                    }
                }
                
                
                if colorType == 2 {
                    multidimensionalLookupTableGray.apply(
                        sources: [planarScale],
                        destinations: [redBuffer, greenBuffer, blueBuffer],
                        interpolation: .half)
                } else if colorType == 3 {
                    multidimensionalLookupTableRed.apply(
                        sources: [planarScale],
                        destinations: [redBuffer, greenBuffer, blueBuffer],
                        interpolation: .half)
                } else if colorType == 4 {
                    multidimensionalLookupTableBunt.apply(
                        sources: [planarScale],
                        destinations: [redBuffer, greenBuffer, blueBuffer],
                        interpolation: .half)
                }
                else if colorType == 5 {
                    multidimensionalLookupTable.apply(
                        sources: [planarScale],
                        destinations: [redBuffer, greenBuffer, blueBuffer],
                        interpolation: .half)
                }

                rgbImageBuffer.interleave(
                    planarSourceBuffers: [redBuffer, greenBuffer, blueBuffer])
            }
       }
        return rgbImageBuffer.makeCGImage(cgImageFormat: rgbImageFormat) ?? FFTAnalyzer.emptyCGImage
    }
    
    internal static let emptyCGImage: CGImage = {
        let buffer = vImage.PixelBuffer(
            pixelValues: [0],
            size: .init(width: 1, height: 1),
            pixelFormat: vImage.Planar8.self)
        
        let fmt = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8 ,
            colorSpace: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            renderingIntent: .defaultIntent)
        
        return buffer.makeCGImage(cgImageFormat: fmt!)!
    }()
    
}
