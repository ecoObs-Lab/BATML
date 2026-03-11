//
//  BatSoundContainer.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 23.07.25.
//

import Foundation
import CoreServices
import AudioToolbox
import CoreAudio
import AVFoundation
import Accelerate

import AVFoundation

// C-interop friendly context (POD only; no Swift reference types)
struct AudioIOContext {
    var pos: UInt32
    var srcBuffer: UnsafePointer<Float> // read-only pointer into Swift array storage
    var srcBufferSize: UInt32
    var srcSizePerPacket: UInt32
    var numPacketsPerRead: UInt32
    var maxPacketsInSound: UInt32
    var abl: UnsafeMutablePointer<AudioBufferList>
}

// Keep the old signature expected by AudioConverterFillComplexBuffer
func fillComplexCallback(myConverter: AudioConverterRef,
                         packetNumber: UnsafeMutablePointer<UInt32>,
                         ioData: UnsafeMutablePointer<AudioBufferList>,
                         aspd: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
                         userInfo: UnsafeMutableRawPointer?) -> OSStatus {

    guard let userInfo else { return -50 } // paramErr
    // Bind to our POD context
    let ctxPtr = userInfo.assumingMemoryBound(to: AudioIOContext.self)
    var ctx = ctxPtr.pointee

    if packetNumber.pointee > ctx.numPacketsPerRead {
        packetNumber.pointee = ctx.numPacketsPerRead
    }

    if packetNumber.pointee + ctx.pos >= ctx.maxPacketsInSound {
        packetNumber.pointee = ctx.maxPacketsInSound - ctx.pos
    }

    // Number of bytes for Float output requested by converter (we configured 16-bit out,
    // but AudioConverterFillComplexBuffer asks us for source packets; we provide Float frames here)
    let outByteSize = packetNumber.pointee * ctx.srcSizePerPacket

    // Point mData to the correct slice inside the existing srcBuffer without creating Swift arrays
    let frameOffset = Int(ctx.pos)
    let byteOffset = frameOffset * MemoryLayout<Float>.size
    let srcBaseRaw = UnsafeRawPointer(ctx.srcBuffer)
    let slicePtr = srcBaseRaw.advanced(by: byteOffset)

    let audioBufferListRef = UnsafeMutableAudioBufferListPointer(ioData)
    audioBufferListRef[0].mData = UnsafeMutableRawPointer(mutating: slicePtr)
    audioBufferListRef[0].mDataByteSize = outByteSize
    audioBufferListRef[0].mNumberChannels = 1

    // Advance position in the original context stored on heap
    ctx.pos = ctx.pos + packetNumber.pointee
    ctxPtr.pointee = ctx

    return noErr
}

public final class BatSoundContainer
{
    private var audioURL: URL?
    
    public var soundData: [Float]?
    public var header: AudioHeader?
    lazy var fftAnalyzer = FFTAnalyzer()
    
    public var soundInfoText = ""
    public var soundDetailInfoText: String {
        get {
            if self.header == nil {
                return "No header"
            }
            var detailString: String = ""
            if self.header!.channelCount == 1 {
                detailString += "Mono "
            }
            else {
                detailString += "Stereo "
            }
            var thousands = 0
            var returnSamples = self.header!.sampleCount
            while returnSamples > 10000 {
                returnSamples /= 1000
                thousands += 3
            }
            detailString += String(format:"%d*10^%d spls ", returnSamples, thousands)
            
            detailString += String(format:"%.2fs", Double(self.header!.sampleCount)/Double(self.header!.samplerate))
            
            return detailString
        }
    }
        
    let denormal : Double = 0.000001
    
    public var kHzMax: Double {
        get {
            if self.header == nil {
                return 250
            }
            return Double(self.header!.samplerate * self.header!.timeExpansion) / 2000.0
        }
    }
    
    public var msMax: Double {
        get {
            if self.header == nil {
                return 0
            }
            return Double(self.header!.sampleCount) / Double(self.header!.timeExpansion * self.header!.samplerate) * 1000.0
        }
    }
    
    public var activeChannel: Int = 0 {
        didSet {
            self.selectionSampleStart = nil
            self.selectionSampleSize = nil
        }
    }
    
    public var selectionSampleStart: Int? = nil
    public var selectionSampleSize: Int? = nil
    
    deinit {
        print("Deinit BatSoundContainer")
    }
    
    public init(create: Bool = true) {
        self.header = AudioHeader()
        self.header!.samplerate = 500000
        self.header!.channelCount = 1
        self.header!.sampleFormat = .Sample16bitLE
        self.header!.fileType = .batcorder_raw
        self.header!.sampleCount = 250000
        
        self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount)
        self.soundInfoText = String(format: "%.0fkHz - batcorder RAW", Double(self.header!.samplerate) / 1000.0)
       
    }
    
    public  init(from raw: Data, audioHeader: AudioHeader? = nil) throws {
        if audioHeader != nil {
            self.header = audioHeader
        } else {
            self.header = AudioHeader()
            self.header!.samplerate = 500000
            self.header!.channelCount = 1
            self.header!.sampleFormat = .Sample16bitLE
            self.header!.fileType = .batcorder_raw
            self.header!.sampleCount = raw.count / 2
        }
        
        self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount)
        if self.header?.sampleFormat == .Sample32bitFloat {
            raw.withUnsafeBytes({ (bytes) -> Void in
                let buffer: UnsafePointer<Float32> = bytes.baseAddress!.assumingMemoryBound(to: Float32.self)
                for i in 0..<header!.sampleCount {
                    self.soundData![i] = buffer[i]
                }
            })
        } else {
            raw.withUnsafeBytes({ (bytes) -> Void in
                let buffer: UnsafePointer<Int16> = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                self.FloatFromSInt16(sourceObject: buffer)
            })
        }
    }
        
    public init(with url: URL) throws {
        guard let header = BatSoundFileSpecs.sharedInstance.readHeader(of: url) else {
            throw AudioError.FileFormat
        }
        self.audioURL = url
        
        
        self.header = header
        if header.fileType == .batcorder_raw {
            let tempSoundData = try Data(contentsOf: url)
            self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount)
            tempSoundData.withUnsafeBytes({ (bytes) -> Void in
                let buffer: UnsafePointer<Int16> = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                self.FloatFromSInt16(sourceObject: buffer)
            })
        }
        else if header.fileType == .windows_wave {
            guard let inputFormat = header.audioFormatDescription else {
                throw AudioError.FileFormat
            }

            var converterOutputFormat = inputFormat
            converterOutputFormat.mBytesPerFrame = converterOutputFormat.mChannelsPerFrame * 2
            converterOutputFormat.mBitsPerChannel = 16
            converterOutputFormat.mBytesPerPacket = converterOutputFormat.mChannelsPerFrame * 2
            
            let arraySize = Int(header.sampleCount*Int(inputFormat.mChannelsPerFrame))
            self.soundData = [Float](repeating: 0.0, count:arraySize)
            
            //let isFloatFormat: Bool = inputFormat.mFormatFlags & AudioFormatFlags(kAudioFormatFlagIsFloat) == 1
            var err: OSStatus = 0
            var audioFile : AudioFileID?
            let status = AudioFileOpenURL(url as CFURL, AudioFilePermissions.readPermission, 0, &audioFile)
            if status != 0 { return }

            if inputFormat.mBitsPerChannel == 8 {
                var pos: Int = 0
                var writePos: Int = 0
                let stereoOffset = header.sampleCount
                var packetCount:UInt32  = 4096
                let IntToFloatScalar : Float = 1.0 / 256;
                var kSrcBufSizeSound:UInt32  = packetCount*inputFormat.mBytesPerFrame
                var rawBuffer = [UInt8](repeating: 0, count:Int(packetCount*2))
                let channelMax = header.channelCount
                while err != 0 || writePos<=header.sampleCount || packetCount > 0
                {
                    err = AudioFileReadPacketData(audioFile!, false, &kSrcBufSizeSound, nil, Int64(pos), &packetCount, &rawBuffer)
                    //println("\(writePos) : \(packetCount) and \(kSrcBufSizeSound)")
                    if err != 0 { break }
                    if packetCount < 2 {break }
                    for c in 0..<channelMax {
                        let start = c
                        var j = 0;
                        for i in stride(from: start, to: Int(packetCount), by: channelMax) {
                            if writePos+j >= header.sampleCount {break}
                            self.soundData?[(c*stereoOffset)+writePos+j] = Float(rawBuffer[i]) * IntToFloatScalar
                            j += 1
                        }
                    }
                    pos += Int(packetCount)/channelMax
                    writePos += Int(packetCount)/channelMax
                }
            }
            else if inputFormat.mBitsPerChannel == 16 {
                
                var pos: Int = 0
                var writePos: Int = 0
                let stereoOffset = header.sampleCount
                let IntToFloatScalar : Float = 1.0 / 32768.0;
                var packetCount:UInt32  = 4096
                var kSrcBufSizeSound:UInt32  = packetCount*inputFormat.mBytesPerFrame
                var rawBuffer = [Int16](repeating: 0, count:Int(packetCount*2))
                let channelMax = header.channelCount
                while err != 0 || writePos<=header.sampleCount || packetCount > 0
                {
                    err = AudioFileReadPacketData(audioFile!, false, &kSrcBufSizeSound, nil, Int64(pos), &packetCount, &rawBuffer)
                    //println("\(writePos) : \(packetCount) and \(kSrcBufSizeSound)")
                    if err != 0 { break }
                    if packetCount < 2 {break }
                    for c in 0..<channelMax {
                        let start = c
                        var j = 0;
                        for i in stride(from: start, to: Int(packetCount), by: channelMax) {
                            if writePos+j >= header.sampleCount {break}
                            self.soundData?[(c*stereoOffset)+writePos+j] = Float(rawBuffer[i]) * IntToFloatScalar
                            j += 1
                        }
                    }
                    pos += Int(packetCount)/channelMax
                    writePos += Int(packetCount)/channelMax
                }
            }
            else if inputFormat.mBitsPerChannel == 24 {
                var inputfile: ExtAudioFileRef?
                err = ExtAudioFileOpenURL(url as CFURL, &inputfile)
                if (err != 0) {
                    AudioFileClose(audioFile!)
                    print("Error ExtAudioFileOpen")
                    throw AudioError.FileFormat
                }
                
                var propertyWriteable: DarwinBoolean = false
                var propertySize: UInt32  = 0
                err = ExtAudioFileGetPropertyInfo(inputfile!, UInt32(kExtAudioFileProperty_ClientDataFormat), &propertySize, &propertyWriteable)
                if err != 0 {
                    AudioFileClose(audioFile!)
                    throw AudioError.FileFormat
                }
                
                err = ExtAudioFileSetProperty(inputfile!, kExtAudioFileProperty_ClientDataFormat, propertySize, &converterOutputFormat)
                if err != 0 {
                    AudioFileClose(audioFile!)
                    throw AudioError.FileFormat
                }
                
                let packetCount:UInt32  = UInt32(header.sampleCount)
                let kSrcBufSizeSound:UInt32  = packetCount*converterOutputFormat.mBytesPerFrame
                
                var pos: Int = 0
                let stereoOffset = header.sampleCount
                let IntToFloatScalar : Float = 1.0 / 32768.0;
                var _buffer = [Int16](repeating: 0, count:Int(packetCount*2))
                var numFrames = (kSrcBufSizeSound / converterOutputFormat.mBytesPerFrame) //packetCount
                
                while 1 == 1 {
                    _buffer.withUnsafeMutableBytes{ buffer in
                        var fillBufList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer( mNumberChannels: inputFormat.mChannelsPerFrame, mDataByteSize: kSrcBufSizeSound, mData: buffer.baseAddress!))
                        
                        err = ExtAudioFileRead (inputfile!, &numFrames, &fillBufList)
                    }
                    if err != 0 || numFrames == 0 {
                        break
                    }
                    
                    for c in 0..<header.channelCount {
                        let start = c
                        var j = 0
                        for i in stride(from: start, to: Int(numFrames*converterOutputFormat.mChannelsPerFrame), by: header.channelCount) {
                            if pos+j >= header.sampleCount {break}
                            self.soundData?[(c*stereoOffset)+pos+j] = Float(_buffer[i]) * IntToFloatScalar
                            j += 1
                        }
                    }
                    pos += Int(numFrames) / header.channelCount
                }
                ExtAudioFileDispose(inputfile!)
            }
            else if inputFormat.mBitsPerChannel == 32 {
                var inputfile: ExtAudioFileRef?
                err = ExtAudioFileOpenURL(url as CFURL, &inputfile)
                if (err != 0) {
                    AudioFileClose(audioFile!)
                    print("Error ExtAudioFileOpen")
                    throw AudioError.FileFormat
                }
                
                var propertyWriteable: DarwinBoolean = false
                var propertySize: UInt32  = 0
                err = ExtAudioFileGetPropertyInfo(inputfile!, UInt32(kExtAudioFileProperty_ClientDataFormat), &propertySize, &propertyWriteable)
                if err != 0 {
                    AudioFileClose(audioFile!)
                    throw AudioError.FileFormat
                }
                
                converterOutputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger
                err = ExtAudioFileSetProperty(inputfile!, kExtAudioFileProperty_ClientDataFormat, propertySize, &converterOutputFormat)
                if err != 0 {
                    AudioFileClose(audioFile!)
                    throw AudioError.FileFormat
                }
                
                let packetCount:UInt32  = UInt32(header.sampleCount)
                let kSrcBufSizeSound:UInt32  = packetCount*converterOutputFormat.mBytesPerFrame
                
                var pos: Int = 0
                let stereoOffset = header.sampleCount
                let IntToFloatScalar : Float = 1.0 / 32768.0;
                var _buffer = [Int16](repeating: 0, count:Int(packetCount*2))
                var numFrames = (kSrcBufSizeSound / converterOutputFormat.mBytesPerFrame) //packetCount
                
                while 1 == 1 {
                    _buffer.withUnsafeMutableBytes{ buffer in
                        var fillBufList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer( mNumberChannels: inputFormat.mChannelsPerFrame, mDataByteSize: kSrcBufSizeSound, mData: buffer.baseAddress!))
                        
                        err = ExtAudioFileRead (inputfile!, &numFrames, &fillBufList)
                    }
                    if err != 0 || numFrames == 0 {
                        break
                    }
                    
                    for c in 0..<header.channelCount {
                        let start = c
                        var j = 0
                        for i in stride(from: start, to: Int(numFrames*converterOutputFormat.mChannelsPerFrame), by: header.channelCount) {
                            if pos+j >= header.sampleCount {break}
                            self.soundData?[(c*stereoOffset)+pos+j] = Float(_buffer[i]) * IntToFloatScalar
                            j += 1
                        }
                    }
                    pos += Int(numFrames) / header.channelCount
                }
                ExtAudioFileDispose(inputfile!)
            }
            else {
                AudioFileClose(audioFile!)
                throw AudioError.FileFormat
            }
            if audioFile != nil {
                AudioFileClose(audioFile!)
            }
        }
        else if header.fileType == .batsound_wave {
            let tempSoundData = try Data(contentsOf: url)
            
            self.soundData = [Float](repeating: 10.0, count: self.header!.sampleCount)
            
            tempSoundData.withUnsafeBytes({ (bytes) -> Void in
                let buffer: UnsafePointer<Int16> = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                self.FloatFromSInt16(sourceObject: buffer)
            })
        }
        else if header.fileType == .flac {
            if let _soundData = FlacToRawDecoder().decode(from: url) {
                self.soundData = _soundData
            }
            else {
                throw AudioError.FileFormat
            }
        }
        else if header.fileType == .mp3 {
            if let _soundData = MP3ToRawDecoder().decode(from: url) {
                self.soundData = _soundData
            }
            else {
                throw AudioError.FileFormat
            }
        }
        else {
            throw AudioError.FileFormat
        }
    }
        
    /// Init sound document from raw data
    /// - Parameter settings: settings should contain fileToImport, sampleRate, sampleFormat, channelLayout
    public init(settings:Dictionary<String,String>) throws {
        let outError: NSError! = NSError(domain: "de.ecoObs.SoundContainer", code: 0, userInfo: [NSLocalizedRecoverySuggestionErrorKey:NSLocalizedString("Error creating document", comment: "Error creating document")])
        self.header = AudioHeader()
        guard let file = settings["fileToImport"] else {
            self.header!.sampleCount = 1
            self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount)
            self.header!.channelCount = 1
            throw outError
        }
        
        guard let _sr = settings["sampleRate"] else {
            self.header!.sampleCount = 1
            self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount)
            self.header!.channelCount = 1
            throw outError
        }
        
        let sr = (_sr as NSString).integerValue
        
        guard let format = settings["sampleFormat"] else {
            self.header!.sampleCount = 1
            self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount)
            self.header!.channelCount = 1
            throw outError
        }
        
        guard let channels = settings["channelLayout"] else {
            self.header!.sampleCount = 1
            self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount)
            self.header!.channelCount = 1
            throw outError
        }
        
        var _channelCount = 1
        if channels == "Stereo" {
            _channelCount = 2
        }
        
        var channelLayout = 0
        if let cl = settings["channelLayout"], cl == "true" {
            channelLayout = 1
        }
        
        do {
            
            let rawData = try Data(contentsOf: URL.init(fileURLWithPath: file))
            
            // 0: 8-bit
            // 1: 16-bit Intel
            // 2: 16-bit PPC
            
            switch format {
            case "8-bit" :
                self.header!.sampleCount = rawData.count / _channelCount
                self.header!.samplerate = sr
                self.header!.channelCount = _channelCount
                self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount*self.header!.channelCount)
                /*let rawSamples = UnsafePointer<uint8>(rawData.bytes)
                withExtendedLifetime(rawSamples) {
                    self.FloatFromUInt8(rawSamples, channels: channelCount, layoutInterleaved: (channelLayout == 0))
                }*/
            
                rawData.withUnsafeBytes({ (bytes) -> Void in
                    let buffer: UnsafePointer<UInt8> = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    self.FloatFromUInt8(sourceObject: buffer, channels: self.header!.channelCount, layoutInterleaved: (channelLayout == 0))
                })
                            
            case "16-bit Intel" :
                self.header!.sampleCount = rawData.count / (2*_channelCount)
                self.header!.samplerate = sr
                self.header!.channelCount = _channelCount
                self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount*self.header!.channelCount)
                rawData.withUnsafeBytes({ (bytes) -> Void in
                    let buffer: UnsafePointer<Int16> = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                    self.FloatFromSInt16(sourceObject: buffer, channels: self.header!.channelCount, layoutInterleaved: (channelLayout == 0))
                })
            case "16-bit PPC" :
                self.header!.sampleCount = rawData.count / (2*_channelCount)
                self.header!.samplerate = sr
                self.header!.channelCount = _channelCount
                self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount*self.header!.channelCount)
                rawData.withUnsafeBytes({ (bytes) -> Void in
                    let buffer: UnsafePointer<Int16> = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                    self.FloatFromSInt16BE(sourceObject: buffer, channels: self.header!.channelCount, layoutInterleaved: (channelLayout == 0))
                })
            default: self.header!.sampleCount = rawData.count / _channelCount
                self.header!.samplerate = sr
                self.header!.channelCount = _channelCount
                self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount*self.header!.channelCount)
            }
            
            //clientFormat = AudioStreamBasicDescription(mSampleRate: Float64(self.sampleRate), mFormatID: AudioFormatID(kAudioFormatLinearPCM), mFormatFlags: AudioFormatFlags(kAudioFormatFlagsNativeFloatPacked), mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: UInt32(self.header!.channelCount), mBitsPerChannel: 32, mReserved: 0)
            
            if self.header!.samplerate > 100000 {
                self.soundInfoText = String(format: "%.0fkHz - Import", Double(self.header!.samplerate) / 1000.0)
            }
            else {
                self.soundInfoText = String(format: "%.1fkHz - Import", Double(self.header!.samplerate) / 1000.0)
            }
        }
        catch {
            self.header!.sampleCount = 1
            self.soundData = [Float](repeating: 0.0, count: self.header!.sampleCount)
            self.header!.channelCount = 1
            throw outError
        }
    }
    
    public func bcCallsMeasurements() -> NSArray? {
        guard let _ = self.audioURL else { return nil }
        return nil
        /*let coord = NSFileCoordinator(filePresenter: self.bcCallsPresenter)
        var coordError: NSError?
        var result: NSArray?
        coord.coordinate(readingItemAt: self.bcCallsPresenter!.presentedItemURL!, error: &coordError) { url in
            if !FileManager.default.fileExists(atPath: url.path) {
                print("Not existing")
                return
            }
            if let origCallData = NSArray(contentsOf: url) {
                result = origCallData
            }
        }
        if let err = coordError {
            print("File coordination error: \(err)")
        }
        return result*/
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
    
    func writeSoundToURL(url: NSURL, type: FileTypes, outputSampleRate: Float64?) -> Bool {
        var result = false
        if type == .batcorder_raw {
            let rawData = self.SInt16FromFloat()
            withExtendedLifetime(rawData) {
                self.FloatFromSInt16(sourceObject: rawData)
            }
            self.header!.channelCount = 1
            
            self.soundInfoText = String(format: "%.0fkHz - batcorder RAW", Double(self.header!.samplerate) / 1000.0)
            
            let exportData = NSData(bytes:rawData, length: self.header!.sampleCount*2)
            var error: NSError?
            do {
                try exportData.write(to: url as URL, options: NSData.WritingOptions.atomic)
                result = true
            } catch let error1 as NSError {
                error = error1
                result = false
            }
            if !result {
                Logger.soundFile.error("Error \(error)")
            }
            return result
        }
        else {
            var clientFormat = AudioStreamBasicDescription(mSampleRate: outputSampleRate!, mFormatID: AudioFormatID(kAudioFormatLinearPCM), mFormatFlags: AudioFormatFlags(kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved), mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
            
            var outfile : AudioFileID?
            var outputFormat = AudioStreamBasicDescription()
            outputFormat.mFormatID = kAudioFormatLinearPCM
            if outputSampleRate == nil {
                outputFormat.mSampleRate = clientFormat.mSampleRate
            }
            else {
                outputFormat.mSampleRate = outputSampleRate!
                clientFormat.mSampleRate = Float64(self.header!.samplerate)//500000.0
            }
            outputFormat.mBytesPerPacket = 2
            outputFormat.mFramesPerPacket = 1
            outputFormat.mBytesPerFrame = 2
            outputFormat.mChannelsPerFrame = clientFormat.mChannelsPerFrame
            outputFormat.mBitsPerChannel = 16
            outputFormat.mFormatFlags = AudioFormatFlags(kAudioFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger)
            
            var converter : AudioConverterRef?
            var err = AudioConverterNew(&clientFormat, &outputFormat, &converter)
            if err != 0 {
                print("Audio error \(err)")
                return false
            }
            
            var size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            err = AudioConverterGetProperty(converter!, kAudioConverterCurrentOutputStreamDescription, &size, &outputFormat);
            if err != 0 {
                print("Audio error 2 \(err)")
                return false
            }
            if FileManager.default.fileExists(atPath: (url as NSURL).path!) {
                try? FileManager.default.trashItem(at: url as URL, resultingItemURL: nil)
            }
            err = AudioFileCreateWithURL(url, kAudioFileWAVEType, &outputFormat, AudioFileFlags.eraseFile, &outfile)
            if err != 0 {
                print("File create \(err)")
                return false
            }
            
            let kSrcBufSize: UInt32 = 32768*4
            var pos: UInt32 = 0
            let outputBuffer = UnsafeMutablePointer<Int16>.allocate(capacity: Int(kSrcBufSize))
            defer {
                outputBuffer.deallocate()
            }
            var numOutputPackets: UInt32 = 32768
            var totalOutputFrames = 0

            // Allocate and populate POD context on heap; keep it alive across calls
            var ctxPtr: UnsafeMutablePointer<AudioIOContext>?
            soundData!.withUnsafeBufferPointer { srcBuf in
                let srcBase = srcBuf.baseAddress!
                let convertedData = AudioBufferList.allocate(maximumBuffers: 1)
                defer {
                    convertedData.unsafeMutablePointer.deallocate()
                }
                convertedData[0].mNumberChannels = 1
                convertedData[0].mDataByteSize = kSrcBufSize
                convertedData[0].mData = UnsafeMutableRawPointer(outputBuffer)

                ctxPtr = UnsafeMutablePointer<AudioIOContext>.allocate(capacity: 1)
                ctxPtr!.initialize(to: AudioIOContext(
                    pos: pos,
                    srcBuffer: UnsafePointer<Float>(srcBase),
                    srcBufferSize: kSrcBufSize,
                    srcSizePerPacket: UInt32(4),
                    numPacketsPerRead: 32768,
                    maxPacketsInSound: UInt32(self.header!.sampleCount),
                    abl: convertedData.unsafeMutablePointer
                ))

                while true {
                    // Reset output packet count for each fill
                    numOutputPackets = 32768

                    let error: OSStatus = AudioConverterFillComplexBuffer(
                        converter!,
                        fillComplexCallback,
                        ctxPtr, // heap pointer to POD context (no warning)
                        &numOutputPackets,
                        convertedData.unsafeMutablePointer,
                        nil)

                    if (-50 == error) {
                        debugPrint("Audio parameter error. Please check your argument when calling audio API.")
                        break
                    }

                    let myBool : Bool = false
                    let inNumBytes = convertedData[0].mDataByteSize
                    err = AudioFileWritePackets(outfile!, myBool, inNumBytes, nil, Int64(pos), &numOutputPackets, outputBuffer)
                    
                    if err != 0 {
                        print("Audio error 5 \(err)")
                        break
                    }
                    if (numOutputPackets < 1) {
                        break
                    }
                    pos += numOutputPackets
                    totalOutputFrames += Int(numOutputPackets)

                    // Update ctx pos so the next call continues
                    ctxPtr!.pointee.pos = pos
                }
            }
            // Clean up context
            if let ctx = ctxPtr {
                ctx.deinitialize(count: 1)
                ctx.deallocate()
            }

            AudioConverterDispose(converter!)
            AudioFileClose(outfile!);
            return true
        }
    }
    
    func FloatFromSInt8(sourceObject:UnsafePointer<Int8>, channels: Int = 1, layoutInterleaved: Bool = true)
    {
        let IntToFloatScalar : Float = 1.0 / 255.0;
        if layoutInterleaved {
            for i in stride(from: 0, to: self.header!.sampleCount, by: channels) {
                self.soundData![i] = Float(sourceObject[i]) * IntToFloatScalar
                if channels == 2 {
                    self.soundData![i+self.header!.sampleCount] = Float(sourceObject[i+1]) * IntToFloatScalar
                }
            }
        }
        else {
            for i in stride(from: 0, to: self.header!.sampleCount, by: 1) {
                self.soundData![i] = Float(sourceObject[i]) * IntToFloatScalar
                if channels == 2 {
                    self.soundData![i+self.header!.sampleCount] = Float(sourceObject[i+self.header!.sampleCount]) * IntToFloatScalar
                }
            }
        }
    }
    
    func FloatFromUInt8(sourceObject:UnsafePointer<UInt8>, channels: Int = 1, layoutInterleaved: Bool = true)
    {
        let IntToFloatScalar : Float = 1.0 / 255.0;
        if layoutInterleaved {
            var dataCounter = 0
            for i in stride(from: 0, to: self.header!.sampleCount*channels, by: channels) {
                self.soundData![dataCounter] = Float(sourceObject[i]) * IntToFloatScalar
                if channels == 2 {
                    self.soundData![dataCounter+self.header!.sampleCount] = Float(sourceObject[i+1]) * IntToFloatScalar
                }
                dataCounter += 1
            }
        }
        else {
            var dataCounter = 0
            for i in stride(from: 0, to: self.header!.sampleCount, by: 1) {
                self.soundData![dataCounter] = Float(sourceObject[i]) * IntToFloatScalar
                if channels == 2 {
                    self.soundData![dataCounter+self.header!.sampleCount] = Float(sourceObject[i+self.header!.sampleCount]) * IntToFloatScalar
                }
                dataCounter += 1
            }
        }
    }
    
    func FloatFromSInt16(sourceObject:UnsafePointer<Int16>, channels: Int = 1, layoutInterleaved: Bool = true, start: Int = 0)
    {
        
        guard let header = self.header else {
            //NSSound.beep()
            return
        }
        
        let IntToFloatScalar : Double = 1.0 / 32768.0;
        
        if layoutInterleaved {
            var dataCounter = 0
            for i in stride(from:start, to: header.sampleCount*channels, by: channels) {
                self.soundData![dataCounter] = Float(Double(sourceObject[i]) * IntToFloatScalar)
                if channels == 2 {
                    self.soundData![dataCounter+header.sampleCount] = Float(Double(sourceObject[i+1]) * IntToFloatScalar)
                }
                dataCounter += 1
            }
        }
        else {
            var dataCounter = 0
            for i in stride(from: start, to: header.sampleCount, by: 1) {
                self.soundData![dataCounter] = Float(Double(sourceObject[i]) * IntToFloatScalar)
                if channels == 2 {
                    self.soundData![dataCounter+header.sampleCount] = Float(Double(sourceObject[i+header.sampleCount]) * IntToFloatScalar)
                }
                dataCounter += 1
            }
        }
    }
    
    func FloatFromSInt16BE(sourceObject:UnsafePointer<Int16>, channels: Int = 1, layoutInterleaved: Bool = true)
    {
        
        let IntToFloatScalar : Float = 1.0 / 32768.0;
        
        if layoutInterleaved {
            var dataCounter = 0
            for i in stride(from: 0, to: self.header!.sampleCount*channels, by: channels) {
                self.soundData![dataCounter] = Float(Int16(bigEndian:sourceObject[i]).littleEndian) * IntToFloatScalar
                if channels == 2 {
                    self.soundData![dataCounter+self.header!.sampleCount] = Float(Int16(bigEndian:sourceObject[i+1]).littleEndian) * IntToFloatScalar
                }
                dataCounter += 1
            }
        }
        else {
            var dataCounter = 0
            for i in stride(from: 0, to: self.header!.sampleCount, by: 1) {
                self.soundData![dataCounter] = Float(Int16(bigEndian:sourceObject[i]).littleEndian) * IntToFloatScalar
                if channels == 2 {
                    self.soundData![dataCounter+self.header!.sampleCount] = Float(Int16(bigEndian:sourceObject[i+self.header!.sampleCount]).littleEndian) * IntToFloatScalar
                }
                dataCounter += 1
            }
        }
    }
    
    func SInt16FromFloat(mono: Bool = true) -> Array<Int16>
    {
        let FloatToIntScalar : Float = 32768.0;
        var returnData: Array<Int16> = Array()
        var offset = 0
        if self.activeChannel == 1 {
            offset = self.header!.sampleCount
        }
        for index in offset..<self.header!.sampleCount+offset {
            returnData.append(Int16(self.soundData![index]*FloatToIntScalar))
        }
        return returnData
    }
    
    public func RMSforSamples(startSample: Int, numberOfSamples: Int) -> Float {
        if startSample+numberOfSamples > self.header!.sampleCount {
            return 0
        }
        var result: Float = 0.0
        vDSP_rmsqv(Array(self.soundData![startSample..<startSample+numberOfSamples]), 1, &result, vDSP_Length(numberOfSamples))
        result *= sqrt(2.0)
        if result > 1.0 {
            return 1.0
        }
        return result
    }
    
    func convertLinearToDecibels(value:Float) -> Float
    {
        return (20.0 * log10(abs(value)))
    }
    
    func sampleFactorFromdB(dBValue:Float) -> Float {
        var sampleFactor: Float = 1
        
        sampleFactor = pow(10,dBValue / 20)
        
        return sampleFactor
    }
}

/* extension BatSoundContainer {
    public func overviewSonagram(height: CGFloat = 128, expectedWidth: Double, gain: Float = 0, spreadFactor: Float = 1, colorType: Int = 5) -> CGImage? {
        
        let fftSize = height * 2
                
        // create sonagramm
        
        let sampleCount = self.header!.sampleCount
        
        var overlap: Float = 0.0
        overlap = 1.0 - (Float(Double(sampleCount) / expectedWidth) / Float(fftSize))
        
        let offset = self.header!.sampleCount * self.activeChannel
        
        return fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &self.soundData, startSample: offset, numberOfSamples:sampleCount, FFTSize: Int(fftSize), Overlap: overlap, Window:5, gain: gain, spreadFactor: spreadFactor, colorType: colorType)
    }
    
    public func overviewSonagramStereo(height: CGFloat = 128, expectedWidth: Double, gain: Float = 0, spreadFactor: Float = 1, colorType: Int = 5) -> CGImage? {
        
        let fftSize = 128 * 2
                
        // create sonagramm
        
        let sampleCount = self.header!.sampleCount
        
        var overlap: Float = 0.0
        overlap = 1.0 - (Float(Double(sampleCount) / expectedWidth) / Float(fftSize))
        
        
        var offset = 0
        
        let leftChannel = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &self.soundData, startSample: offset, numberOfSamples: sampleCount, FFTSize: fftSize, Overlap: overlap, Window: 5, gain: gain, spreadFactor: spreadFactor)
        
        offset = self.header!.sampleCount
        let rightChannel = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &self.soundData, startSample: offset, numberOfSamples: sampleCount, FFTSize: fftSize, Overlap: overlap, Window: 5, gain: gain, spreadFactor: spreadFactor)
        
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.floatComponents.rawValue)
        
        let outputBitmap = CGContext(data: nil, width: leftChannel!.width * 2, height: leftChannel!.height, bitsPerComponent: 32, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        outputBitmap?.draw(leftChannel!, in: CGRect(x: leftChannel!.width * 1, y: 0,width: leftChannel!.width, height: leftChannel!.height))
        outputBitmap?.draw(rightChannel!, in: CGRect(x: 0,y: 0,width: leftChannel!.width, height: leftChannel!.height))
        return outputBitmap?.makeImage() ?? FFTAnalyzer.emptyCGImage
        
        //return fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &self.soundData, startSample: offset, numberOfSamples:sampleCount, FFTSize: fftSize, Overlap: overlap, Window:5, gain: gain, spreadFactor: spreadFactor, colorType: colorType)
    }

    
    public func sonagramImage(from: Int, size: Int, fftParameters: FFTAnalyzer.FFTSettings, hires: Bool = false, gain: Float = 0, spreadFactor: Float = 1, colorType: Int = 5, expanded: Bool = false) -> CGImage? {
        
        let offset = self.header!.sampleCount * self.activeChannel
        return fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &self.soundData, startSample: from+offset, numberOfSamples: size, FFTSize: fftParameters.fftSize, Overlap: fftParameters.overlap, Window: fftParameters.window.rawValue, gain: gain, spreadFactor: spreadFactor, expanded: expanded)
    }
    
    /*
     let outputBitmap = CGBitmapContextCreate(nil, n_2*fftFactor /*height*/, width, CGImageGetBitsPerComponent(cgImage!), 0, NSColorSpace.genericGrayColorSpace().CGColorSpace!, bitmapInfo.rawValue)
     */
    
    public func sonagramImageStereo(from: Int, size: Int, fftParameters: FFTAnalyzer.FFTSettings, hires: Bool = false, gain: Float = 0, spreadFactor: Float = 1, colorType: Int = 5, expanded: Bool = false) -> CGImage? {
        
        var offset = 0
        
        let leftChannel = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &self.soundData, startSample: from+offset, numberOfSamples: size, FFTSize: fftParameters.fftSize, Overlap: fftParameters.overlap, Window: fftParameters.window.rawValue, gain: gain, spreadFactor: spreadFactor, expanded: expanded)
        
        offset = self.header!.sampleCount * self.activeChannel
        let rightChannel = fftAnalyzer.sonagramImageRGBAImageBuffer(fromSamples: &self.soundData, startSample: from+offset, numberOfSamples: size, FFTSize: fftParameters.fftSize, Overlap: fftParameters.overlap, Window: fftParameters.window.rawValue, gain: gain, spreadFactor: spreadFactor, expanded: expanded)
        
        let outputBitmap = CGContext(data: nil, width: leftChannel!.width * 2, height: leftChannel!.height, bitsPerComponent: leftChannel!.bitsPerComponent, bytesPerRow: 0, space: leftChannel!.colorSpace!, bitmapInfo: leftChannel!.bitmapInfo.rawValue)
        outputBitmap?.draw(leftChannel!, in: CGRect(x: leftChannel!.width, y: 0,width: leftChannel!.width, height: leftChannel!.height))
        outputBitmap?.draw(rightChannel!, in: CGRect(x: 0 ,y: 0,width: leftChannel!.width, height: leftChannel!.height))
        return outputBitmap?.makeImage() ?? FFTAnalyzer.emptyCGImage
        
    }
    
    public func spectrumData(from: Int, size: Int, fftParameters: FFTAnalyzer.FFTSettings) -> [Float]? {
        let offset = self.header!.sampleCount * self.activeChannel
        return fftAnalyzer.spectrumHiresData(fromSamples: &self.soundData, startSample: from + offset, numberOfSamples: size, FFTSize: 1024*16, Window: fftParameters.window.rawValue)
    }
} */

extension BatSoundContainer {
    
    func downsample(count: Int) -> [Float] {
        guard !(soundData?.isEmpty ?? true) else { return [] }
        
        var total = self.header!.sampleCount
        var localCount = count
        if self.header!.channelCount == 2 {
            total *= 2
            localCount *= 2
        }
        
        let chunkSize = total / localCount
        var newSamples = [Float](repeating: 0, count: localCount)
        let offset = self.activeChannel * self.header!.sampleCount
            for i in 0..<localCount {
                let start = i * chunkSize + offset
                let end = min(start + chunkSize, total)
                
                soundData!.withUnsafeBufferPointer { buffer in //1
                    let slice = buffer[start..<end]         //2
                    newSamples[i] = vDSP.maximum(slice)     //3
                }
            }

            return newSamples
        }
}
