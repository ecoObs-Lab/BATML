//
//  BatSoundFileSpecs.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 23.07.25.
//

import Foundation
import CoreServices
import AudioToolbox
import CoreAudio
import OSLog

import AVFoundation

public enum FileTypes : String {
    case batcorder_raw = "Batcorder raw"
    case windows_wave = "Windows wave"
    case batsound_wave = "Batsound wave"
    case flac = "Flac"
    case mp3 = "MP3"
    case unkown = "Unknown"
}

public enum AudioError : Error {
    case TooManyChannels
    case FileFormat
    case SecurityScopeExhausted
    case EmptyFile
    case OtherError
}

public enum sampleType {
    case Sample8bit
    case Sample16bitLE
    case Sample16bitBE
    case Sample24bitFloat
    case Sample32bitFloat
}

public struct AudioHeader {
    public var samplerate: Int = 500000
    public var channelCount: Int = 1
    public var sampleCount: Int = 0
    public var soundStartSample: Int = 0
    public var sampleFormat: sampleType = .Sample16bitLE
    public var fileType: FileTypes = .unkown
    var audioFormatDescription: AudioStreamBasicDescription? // file
    var storedAudioFormatDescription: AudioStreamBasicDescription? // stored for internal use
    {
        if self.audioFormatDescription == nil {
            return nil
        }
        else {
            var returnValue = audioFormatDescription
            returnValue!.mFormatFlags = AudioFormatFlags(kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved)
            returnValue!.mBytesPerPacket = 4
            returnValue!.mBytesPerFrame = 4
            returnValue!.mBitsPerChannel = 32
            return returnValue
        }
    }
    var timeExpansion: Int = 1
}

public final class BatSoundFileSpecs: Sendable {
    
    static let sharedInstance = BatSoundFileSpecs()
        
    func readHeader(of audioURL: URL) ->  AudioHeader? {
        
        if audioURL.pathExtension.lowercased() == "raw" {
            
            var header: AudioHeader = AudioHeader()
            header.samplerate = 500000
            header.channelCount = 1
            header.sampleFormat = .Sample16bitLE
            header.fileType = .batcorder_raw
            header.audioFormatDescription = AudioStreamBasicDescription(mSampleRate: 500000.0, mFormatID: AudioFormatID(kAudioFormatLinearPCM), mFormatFlags: AudioFormatFlags(kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved), mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
            
            do {
                header.sampleCount = try FileManager.default.attributesOfItem(atPath:audioURL.path)[FileAttributeKey.size] as! Int / 2
                
            }
            catch {
                return nil
            }
            
            return header
        }
        else {
            var header: AudioHeader = AudioHeader()
            var audioFile : AudioFileID?
            let status = AudioFileOpenURL(audioURL as CFURL, AudioFilePermissions.readPermission, 0, &audioFile)
            if status != 0 {
                
                if audioFile != nil {
                    AudioFileClose(audioFile!)
                }
                let tempSoundData = NSData(contentsOf: audioURL)
                if nil == tempSoundData || tempSoundData?.length == 0 {
                    return nil
                }
                var buffer: Array<Int8> = Array(repeating: 00, count: 5)
                var i = 0
                
                for _ in 0..<(tempSoundData!.length - 4) {
                    tempSoundData!.getBytes(&buffer, range: NSMakeRange(i,4))
                    var returnValue: AudioHeader?
                    buffer.withUnsafeBufferPointer { buf in
                        if let myString = String(validatingCString: buf.baseAddress!) {
                            if myString == "fmt " {
                                i += 8
                                
                                var channels = 0
                                tempSoundData!.getBytes(&channels, range: NSMakeRange(i,2))
                                
                                var samplerate = 0
                                i += 4
                                tempSoundData!.getBytes(&samplerate, range: NSMakeRange(i,4))
                                if channels > 2 || channels < 1 {
                                    returnValue = nil
                                }
                                header.channelCount = channels
                                header.samplerate = samplerate
                                
                                var dataString = ""
                                while dataString != "data" && i < tempSoundData!.length - 4 {
                                    i += 1
                                    tempSoundData!.getBytes(&buffer, range: NSMakeRange(i,4))
                                    if let testString = String(validatingCString: buf.baseAddress!) {
                                        dataString = testString
                                    }
                                    
                                }
                                i += 4
                                let audiobytecount = ((tempSoundData!.length-i)/2)*header.channelCount
                                header.sampleCount = audiobytecount
                                header.soundStartSample = i
                                header.fileType = .batsound_wave
                                returnValue =  header
                            }
                        }
                    }
                    return returnValue
                }
                return nil
            }
            guard let _audioFile = audioFile else { return nil }
            var inputFormat = AudioStreamBasicDescription(mSampleRate: 500000.0, mFormatID: AudioFormatID(kAudioFormatLinearPCM), mFormatFlags: AudioFormatFlags(kAudioFormatFlagsNativeFloatPacked), mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
            
            
            var audioByteCount: UInt32 = 0
            var size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            var propertySize: UInt32  = 0
            var propWrite: UInt32 = 0
            
            var err = AudioFileGetProperty(_audioFile, UInt32(kAudioFilePropertyDataFormat), &size, &inputFormat)
            if err != 0 {
                Logger.soundFile.error("Error getting data format: \(audioURL.path)")
            }
            else {
                header.channelCount = Int(inputFormat.mChannelsPerFrame)
                header.samplerate = Int(inputFormat.mSampleRate)
                header.audioFormatDescription = inputFormat
            }
            
            err = AudioFileGetPropertyInfo(_audioFile, UInt32(kAudioFilePropertyAudioDataByteCount), &propertySize, &propWrite)
            if err != 0 {
                Logger.soundFile.error("Error getting byte count: \(audioURL.path)")
            }
            else {
                err = AudioFileGetProperty(_audioFile, UInt32(kAudioFilePropertyAudioDataByteCount), &propertySize, &audioByteCount)
                if err != 0 {
                    Logger.soundFile.error("Error getting byte count: \(audioURL.path)")
                }
                else {
                    if audioURL.pathExtension.lowercased() == "flac" {
                        var flacAudioFile : AudioFileID?
                        let status = ExtAudioFileOpenURL(audioURL as CFURL, &flacAudioFile)
                        if status == 0, let _flacAudioFile = flacAudioFile {
                            var theFileLengthInFrames: UInt32 = 0
                            err = ExtAudioFileGetProperty(_flacAudioFile, kExtAudioFileProperty_FileLengthFrames, &propertySize, &theFileLengthInFrames)
                            if err != 0 {
                                flacAudioFile = nil
                                AudioFileClose(audioFile!)
                                Logger.soundFile.error("AudioError.AudioFileFormat: \(audioURL.path)")
                                return nil
                            }
                            header.sampleCount = Int(theFileLengthInFrames)
                            header.fileType = .flac
                            flacAudioFile = nil
                        }
                        else {
                            return nil
                        }
                    } else if audioURL.pathExtension.lowercased() == "mp3" {
                        var mp3AudioFile : AudioFileID?
                        let status = ExtAudioFileOpenURL(audioURL as CFURL, &mp3AudioFile)
                        if status == 0, let _mp3AudioFile = mp3AudioFile {
                            var theFileLengthInFrames: UInt32 = 0
                            err = ExtAudioFileGetProperty(_mp3AudioFile, kExtAudioFileProperty_FileLengthFrames, &propertySize, &theFileLengthInFrames)
                            if err != 0 {
                                mp3AudioFile = nil
                                AudioFileClose(audioFile!)
                                Logger.soundFile.error("AudioError.AudioFileFormat: \(audioURL.path)")
                                return nil
                            }
                            header.sampleCount = Int(theFileLengthInFrames)
                            header.fileType = .mp3
                            mp3AudioFile = nil
                        }
                        else {
                            return nil
                        }
                    }
                    else if audioURL.pathExtension.lowercased() == "wav" || audioURL.pathExtension.lowercased() == "wave"  {
                        header.sampleCount = Int(audioByteCount) / Int(inputFormat.mBytesPerFrame)
                        header.fileType = .windows_wave
                    } else {
                        return nil
                    }
                }
            }
            if audioFile != nil {
                AudioFileClose(audioFile!)
            }
            return header
        }
    }
}



