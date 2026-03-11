//
//  DecodeToRaw.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 03.04.24.
//

#if canImport(Cocoa)
import Cocoa
#endif
import CoreAudio
import AudioToolbox
import OSLog


internal final class FlacToRawDecoder {
    
    var sampleCount: Int?
    var durationSeconds: Double?
    
    func decode(from audioURL: URL) -> [Float]? {
        var audioFile : AudioFileID? = nil
        let status = AudioFileOpenURL(audioURL as CFURL, AudioFilePermissions.readPermission, 0, &audioFile)
        
        if status != 0 {
            
            if audioFile != nil {
                AudioFileClose(audioFile!)
            }
            Logger.soundFile.error("Error opening file: \(audioURL.path)")
            return nil
        }
        
        var inputFormat = AudioStreamBasicDescription(mSampleRate: 500000.0, mFormatID: AudioFormatID(kAudioFormatLinearPCM), mFormatFlags: AudioFormatFlags(kAudioFormatFlagsNativeFloatPacked), mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var audioByteCount: UInt32 = 0
        var size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var propertySize: UInt32  = 0
        var propWrite: UInt32 = 0
        var outDataSize: Float64 = 0;
        
        var err = AudioFileGetProperty(audioFile!, UInt32(kAudioFilePropertyDataFormat), &size, &inputFormat)
        err = AudioFileGetPropertyInfo(audioFile!, UInt32(kAudioFilePropertyAudioDataByteCount), &propertySize, &propWrite)
        err = AudioFileGetProperty(audioFile!, UInt32(kAudioFilePropertyAudioDataByteCount), &propertySize, &audioByteCount)
        err = AudioFileGetProperty(audioFile!, kAudioFilePropertyEstimatedDuration, &propertySize, &outDataSize)
        
        self.durationSeconds = outDataSize
        
        if err != 0 || audioByteCount == 0 {
            AudioFileClose(audioFile!)
            Logger.soundFile.error("AudioError.FileFormat \(audioURL.path)")
            return nil
        }
        
        if inputFormat.mChannelsPerFrame > 2 {
            AudioFileClose(audioFile!)
            Logger.soundFile.error("AudioError.TooManyChannels \(audioURL.path)")
            return nil
        }
        
        if inputFormat.mBytesPerFrame == 0 {
            
            var inputfile: ExtAudioFileRef?
            err = ExtAudioFileOpenURL(audioURL as CFURL, &inputfile)
            if (err != 0) {
                AudioFileClose(audioFile!)
                Logger.soundFile.error("AudioError ExtAudioFileOpen \(audioURL.path)")
                return nil
            }
            
            var propertyWriteable: DarwinBoolean = false
            err = ExtAudioFileGetPropertyInfo(inputfile!, UInt32(kExtAudioFileProperty_ClientDataFormat), &propertySize, &propertyWriteable)
            if err != 0 {
                AudioFileClose(audioFile!)
                Logger.soundFile.error("AudioError.AudioFileFormat \(audioURL.path)")
                return nil
            }
            
            var converterOutputFormat = AudioStreamBasicDescription(mSampleRate: inputFormat.mSampleRate, mFormatID: AudioFormatID(kAudioFormatLinearPCM), mFormatFlags: AudioFormatFlags(kAudioFormatFlagsNativeFloatPacked), mBytesPerPacket: 4*inputFormat.mChannelsPerFrame, mFramesPerPacket: 1, mBytesPerFrame: 4*inputFormat.mChannelsPerFrame, mChannelsPerFrame: inputFormat.mChannelsPerFrame, mBitsPerChannel: 32, mReserved: 0)
            
            err = ExtAudioFileSetProperty(inputfile!, kExtAudioFileProperty_ClientDataFormat, propertySize, &converterOutputFormat)
            if err != 0 {
                AudioFileClose(audioFile!)
                Logger.soundFile.error("AudioError.AudioFileFormat \(audioURL.path)")
                return nil
            }
            
            var theFileLengthInFrames: UInt32 = 0
            err = ExtAudioFileGetProperty(inputfile!, kExtAudioFileProperty_FileLengthFrames, &propertySize, &theFileLengthInFrames)
            if err != 0 {
                AudioFileClose(audioFile!)
                Logger.soundFile.error("AudioError.AudioFileFormat \(audioURL.path)")
                return nil
            }
            
            let sampleCount = Int(theFileLengthInFrames)
            let channelCount = inputFormat.mChannelsPerFrame
            audioByteCount = UInt32(sampleCount)*UInt32(inputFormat.mChannelsPerFrame)*UInt32(MemoryLayout<Float>.size)
            self.sampleCount = sampleCount
            
            let arraySize = Int(sampleCount*Int(inputFormat.mChannelsPerFrame))
            var soundData = [Float](repeating: 0.0 , count:arraySize)
            
            let packetCount:UInt32  = UInt32(sampleCount)
            let kSrcBufSizeSound:UInt32  = packetCount*converterOutputFormat.mBytesPerFrame
            
            var pos: Int = 0
            let stereoOffset = sampleCount
            var _buffer = [Float](repeating: 0, count:Int(packetCount*2))
            
            while true {
                
                var numFrames = (kSrcBufSizeSound / 4)
                
                _buffer.withUnsafeMutableBytes { rawBuf in
                    var fillBufList = AudioBufferList(
                        mNumberBuffers: 1,
                        mBuffers: AudioBuffer(
                            mNumberChannels: inputFormat.mChannelsPerFrame,
                            mDataByteSize: kSrcBufSizeSound,
                            mData: rawBuf.baseAddress
                        )
                    )
                    
                    err = ExtAudioFileRead (inputfile!, &numFrames, &fillBufList)
                }
                
                if err != 0 || numFrames == 0 {
                    break
                }
                
                for c in 0..<channelCount {
                    let start = c
                    var j = 0
                    for i in stride(from: start, to: numFrames*4, by: UInt32.Stride(channelCount)) {
                        if pos+j >= sampleCount {break}
                        soundData[(Int(c)*stereoOffset)+pos+j] = Float(_buffer[Int(i)])
                        j += 1
                    }
                }
                pos += Int(numFrames) / Int(channelCount)
            }
            return soundData
        }
        return nil
    }
    
}

internal final class MP3ToRawDecoder {
    
    var sampleCount: Int?
    var durationSeconds: Double?
    
    func decode(from audioURL: URL) -> [Float]? {
        var audioFile : AudioFileID? = nil
        let status = AudioFileOpenURL(audioURL as CFURL, AudioFilePermissions.readPermission, 0, &audioFile)
        
        if status != 0 {
            
            if audioFile != nil {
                AudioFileClose(audioFile!)
            }
            Logger.soundFile.error("Error opening file: \(audioURL.path)")
            return nil
        }
        
        var inputFormat = AudioStreamBasicDescription(mSampleRate: 500000.0, mFormatID: AudioFormatID(kAudioFormatLinearPCM), mFormatFlags: AudioFormatFlags(kAudioFormatFlagsNativeFloatPacked), mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var audioByteCount: UInt32 = 0
        var size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var propertySize: UInt32  = 0
        var propWrite: UInt32 = 0
        var outDataSize: Float64 = 0;
        
        var err = AudioFileGetProperty(audioFile!, UInt32(kAudioFilePropertyDataFormat), &size, &inputFormat)
        err = AudioFileGetPropertyInfo(audioFile!, UInt32(kAudioFilePropertyAudioDataByteCount), &propertySize, &propWrite)
        err = AudioFileGetProperty(audioFile!, UInt32(kAudioFilePropertyAudioDataByteCount), &propertySize, &audioByteCount)
        err = AudioFileGetProperty(audioFile!, kAudioFilePropertyEstimatedDuration, &propertySize, &outDataSize)
        
        self.durationSeconds = outDataSize
        
        if err != 0 || audioByteCount == 0 {
            AudioFileClose(audioFile!)
            Logger.soundFile.error("AudioError.AudioFileFormat \(audioURL.path)")
            return nil
        }
        
        if inputFormat.mChannelsPerFrame > 2 {
            AudioFileClose(audioFile!)
            Logger.soundFile.error("AudioError.TooManyChannels: \(audioURL.path)")
            return nil
        }
        
        if inputFormat.mBytesPerFrame == 0 {
            
            var inputfile: ExtAudioFileRef?
            err = ExtAudioFileOpenURL(audioURL as CFURL, &inputfile)
            if (err != 0) {
                AudioFileClose(audioFile!)
                Logger.soundFile.error("AudioError ExtAudioFileOpen \(audioURL.path)")
                return nil
            }
            
            var propertyWriteable: DarwinBoolean = false
            err = ExtAudioFileGetPropertyInfo(inputfile!, UInt32(kExtAudioFileProperty_ClientDataFormat), &propertySize, &propertyWriteable)
            if err != 0 {
                AudioFileClose(audioFile!)
                Logger.soundFile.error("AudioError.AudioFileFormat \(audioURL.path)")
                return nil
            }
            
            var converterOutputFormat = AudioStreamBasicDescription(mSampleRate: inputFormat.mSampleRate, mFormatID: AudioFormatID(kAudioFormatLinearPCM), mFormatFlags: AudioFormatFlags(kAudioFormatFlagsNativeFloatPacked), mBytesPerPacket: 4*inputFormat.mChannelsPerFrame, mFramesPerPacket: 1, mBytesPerFrame: 4*inputFormat.mChannelsPerFrame, mChannelsPerFrame: inputFormat.mChannelsPerFrame, mBitsPerChannel: 32, mReserved: 0)
            
            err = ExtAudioFileSetProperty(inputfile!, kExtAudioFileProperty_ClientDataFormat, propertySize, &converterOutputFormat)
            if err != 0 {
                AudioFileClose(audioFile!)
                Logger.soundFile.error("AudioError.AudioFileFormat \(audioURL.path)")
                return nil
            }
            
            var theFileLengthInFrames: UInt32 = 0
            err = ExtAudioFileGetProperty(inputfile!, kExtAudioFileProperty_FileLengthFrames, &propertySize, &theFileLengthInFrames)
            if err != 0 {
                AudioFileClose(audioFile!)
                Logger.soundFile.error("AudioError.AudioFileFormat \(audioURL.path)")
                return nil
            }
            
            let sampleCount = Int(theFileLengthInFrames)
            let channelCount = inputFormat.mChannelsPerFrame
            audioByteCount = UInt32(sampleCount)*UInt32(inputFormat.mChannelsPerFrame)*UInt32(MemoryLayout<Float>.size)
            self.sampleCount = sampleCount
            
            let arraySize = Int(sampleCount*Int(inputFormat.mChannelsPerFrame))
            var soundData = [Float](repeating: 0.0 , count:arraySize)
            
            let packetCount:UInt32  = UInt32(sampleCount)
            let kSrcBufSizeSound:UInt32  = packetCount*converterOutputFormat.mBytesPerFrame
            
            var pos: Int = 0
            let stereoOffset = sampleCount
            var _buffer = [Float](repeating: 0, count:Int(packetCount*2))
            
            while true {
                
                var numFrames = (kSrcBufSizeSound / 4)
                
                _buffer.withUnsafeMutableBytes { rawBuf in
                    var fillBufList = AudioBufferList(
                        mNumberBuffers: 1,
                        mBuffers: AudioBuffer(
                            mNumberChannels: inputFormat.mChannelsPerFrame,
                            mDataByteSize: kSrcBufSizeSound,
                            mData: rawBuf.baseAddress
                        )
                    )
                    
                    err = ExtAudioFileRead (inputfile!, &numFrames, &fillBufList)
                }
                
                if err != 0 || numFrames == 0 {
                    break
                }
                
                for c in 0..<channelCount {
                    let start = c
                    var j = 0
                    for i in stride(from: start, to: numFrames*4, by: UInt32.Stride(channelCount)) {
                        if pos+j >= sampleCount {break}
                        soundData[(Int(c)*stereoOffset)+pos+j] = Float(_buffer[Int(i)])
                        j += 1
                    }
                }
                pos += Int(numFrames) / Int(channelCount)
            }
            return soundData
        }
        return nil
    }
    
}
