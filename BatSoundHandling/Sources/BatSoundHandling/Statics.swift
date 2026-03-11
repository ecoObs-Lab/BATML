//
//  Statics.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 23.02.26.
//

import Accelerate
import Foundation
import Cocoa
import SwiftImage

// MARK: - AppStorage keys

public let SonaGain = "BatSoundHandling-sonaGain"
public let SonaSpread = "BatSoundHandling-sonaSpread"


nonisolated(unsafe)
internal let multidimensionalLookupTableBunt: vImage.MultidimensionalLookupTable = {
    let entriesPerChannel = UInt8(128)
    let srcChannelCount = 1
    let destChannelCount = 3
    
    let lookupTableElementCount = Int(pow(Float(entriesPerChannel), Float(srcChannelCount))) * Int(destChannelCount)
    
    let img = NSImage(byReferencing: Bundle.module.url(forResource: "Bright", withExtension: "png")!)
    let image = Image<RGBA<Float>>.init(nsImage:img)
    //let image  = SwiftImage.Image<RGBA<Float>>(named: "SonaBright")!
    
    let tableData = [UInt16](unsafeUninitializedCapacity: lookupTableElementCount) {
        buffer, count in
        
        /// Supply the samples in the range `0...65535`. The transform function
        /// interpolates these to the range `0...1`.
        let multiplier = CGFloat(UInt16.max)
        var bufferIndex = 0
        
        for gray in ( 0 ..< entriesPerChannel) {
            /// Create normalized red, green, and blue values in the range `0...1`.
            let normalizedValue = CGFloat(gray) / CGFloat(entriesPerChannel - 1)
            let pixel: RGBA<Float> = image[Int(CGFloat(image.width-1) * (1-normalizedValue)), 0]
            
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.red) * multiplier)
            bufferIndex += 1
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.green) * multiplier)
            bufferIndex += 1
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.blue) * multiplier)
            bufferIndex += 1
        }
        
        count = lookupTableElementCount
    }
    
    let entryCountPerSourceChannel = [UInt8](repeating: entriesPerChannel,
                                             count: srcChannelCount)
    
    return vImage.MultidimensionalLookupTable(entryCountPerSourceChannel: entryCountPerSourceChannel,
                                              destinationChannelCount: destChannelCount,
                                              data: tableData)
}()

nonisolated(unsafe)
internal let multidimensionalLookupTableGray: vImage.MultidimensionalLookupTable = {
    let entriesPerChannel = UInt8(128)
    let srcChannelCount = 1
    let destChannelCount = 3
    
    let lookupTableElementCount = Int(pow(Float(entriesPerChannel), Float(srcChannelCount))) * Int(destChannelCount)
    //let simgGrey = SwiftUI.Image("SonaGrey", bundle: .module)
    //let nsGrey = ImageRenderer(content: simgGrey).nsImage!
    let img = NSImage(byReferencing: Bundle.module.url(forResource: "Greyscale", withExtension: "png")!)
    let image = Image<RGBA<Float>>.init(nsImage:img)
    //let image  = SwiftImage.Image<RGBA<Float>>(named: "SonaGrey")!
    
    let tableData = [UInt16](unsafeUninitializedCapacity: lookupTableElementCount) {
        buffer, count in
        
        /// Supply the samples in the range `0...65535`. The transform function
        /// interpolates these to the range `0...1`.
        let multiplier = CGFloat(UInt16.max)
        var bufferIndex = 0
        
        for gray in ( 0 ..< entriesPerChannel) {
            /// Create normalized red, green, and blue values in the range `0...1`.
            let normalizedValue = CGFloat(gray) / CGFloat(entriesPerChannel - 1)
            let pixel: RGBA<Float> = image[Int(CGFloat(image.width-1) * (1-normalizedValue)), 0]
            
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.red) * multiplier)
            bufferIndex += 1
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.green) * multiplier)
            bufferIndex += 1
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.blue) * multiplier)
            bufferIndex += 1
        }
        
        count = lookupTableElementCount
    }
    
    let entryCountPerSourceChannel = [UInt8](repeating: entriesPerChannel,
                                             count: srcChannelCount)
    
    return vImage.MultidimensionalLookupTable(entryCountPerSourceChannel: entryCountPerSourceChannel,
                                              destinationChannelCount: destChannelCount,
                                              data: tableData)
}()


nonisolated(unsafe)
internal let multidimensionalLookupTableRed: vImage.MultidimensionalLookupTable = {
    let entriesPerChannel = UInt8(128)
    let srcChannelCount = 1
    let destChannelCount = 3
    
    let lookupTableElementCount = Int(pow(Float(entriesPerChannel), Float(srcChannelCount))) * Int(destChannelCount)
    
    let img = NSImage(byReferencing: Bundle.module.url(forResource: "Redscale", withExtension: "png")!)
    let image = Image<RGBA<Float>>.init(nsImage:img)
    //let image  = SwiftImage.Image<RGBA<Float>>(named: "SonaRed")!
    
    let tableData = [UInt16](unsafeUninitializedCapacity: lookupTableElementCount) {
        buffer, count in
        
        /// Supply the samples in the range `0...65535`. The transform function
        /// interpolates these to the range `0...1`.
        let multiplier = CGFloat(UInt16.max)
        var bufferIndex = 0
        
        for gray in ( 0 ..< entriesPerChannel) {
            /// Create normalized red, green, and blue values in the range `0...1`.
            let normalizedValue = CGFloat(gray) / CGFloat(entriesPerChannel - 1)
            let pixel: RGBA<Float> = image[Int(CGFloat(image.width-1) * (1-normalizedValue)), 0]
            
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.red) * multiplier)
            bufferIndex += 1
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.green) * multiplier)
            bufferIndex += 1
            buffer[ bufferIndex ] = UInt16(CGFloat(pixel.blue) * multiplier)
            bufferIndex += 1
        }
        
        count = lookupTableElementCount
    }
    
    let entryCountPerSourceChannel = [UInt8](repeating: entriesPerChannel,
                                             count: srcChannelCount)
    
    return vImage.MultidimensionalLookupTable(entryCountPerSourceChannel: entryCountPerSourceChannel,
                                              destinationChannelCount: destChannelCount,
                                              data: tableData)
}()

/// Returns the RGB values from a blue -> red -> green color map for a specified value.
///
/// Values near zero return dark blue, `0.5` returns red, and `1.0` returns full-brightness green.
nonisolated(unsafe)
internal let multidimensionalLookupTable: vImage.MultidimensionalLookupTable = {
    let entriesPerChannel = UInt8(32)
    let srcChannelCount = 1
    let destChannelCount = 3
    
    let lookupTableElementCount = Int(pow(Float(entriesPerChannel), Float(srcChannelCount))) * Int(destChannelCount)
    
    let tableData = [UInt16](unsafeUninitializedCapacity: lookupTableElementCount) {
        buffer, count in
        
        /// Supply the samples in the range `0...65535`. The transform function
        /// interpolates these to the range `0...1`.
        let multiplier = CGFloat(UInt16.max)
        var bufferIndex = 0
        
        for gray in ( 0 ..< entriesPerChannel) {
            /// Create normalized red, green, and blue values in the range `0...1`.
            let normalizedValue = CGFloat(gray) / CGFloat(entriesPerChannel - 1)
          
            // Define `hue` that's blue at `0.0` to red at `1.0`.
            let hue = 0.6666 - (0.6666 * normalizedValue)
            let brightness = sqrt(normalizedValue)
            
            
            
            var red = CGFloat()
            var green = CGFloat()
            var blue = CGFloat()
            
#if os(macOS)
            let color = NSColor(hue: hue,
                                saturation: 1,
                                brightness: brightness,
                                alpha: 1)
            
            color.getRed(&red,
                         green: &green,
                         blue: &blue,
                         alpha: nil)
            #endif

#if os(iOS)
            let color = UIColor(hue: hue,
                                saturation: 1,
                                brightness: brightness,
                                alpha: 1)
            
            color.getRed(&red,
                         green: &green,
                         blue: &blue,
                         alpha: nil)
            #endif

            
            buffer[ bufferIndex ] = UInt16(green * multiplier)
            bufferIndex += 1
            buffer[ bufferIndex ] = UInt16(red * multiplier)
            bufferIndex += 1
            buffer[ bufferIndex ] = UInt16(blue * multiplier)
            bufferIndex += 1
        }
        
        count = lookupTableElementCount
    }
    
    let entryCountPerSourceChannel = [UInt8](repeating: entriesPerChannel,
                                             count: srcChannelCount)
    
    return vImage.MultidimensionalLookupTable(entryCountPerSourceChannel: entryCountPerSourceChannel,
                                              destinationChannelCount: destChannelCount,
                                              data: tableData)
}()
