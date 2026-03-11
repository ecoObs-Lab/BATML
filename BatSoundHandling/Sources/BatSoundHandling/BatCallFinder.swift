//
//  File.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 30.01.26.
//

import Foundation
import Accelerate

protocol CallFinderDelegate {
    // protocol definition goes here
    var mySoundContainer: BatSoundContainer! { get }
}

let kCallFinderGeneralThresholdUI = "CallFinderGeneralThresholdUI"
let kCallFinderGeneralzfthreshold = "CallFinderGeneralThreshold"
let kCallFinderGeneralQuality = "CallFinderGeneralQuality"
let kCallFinderMinCallInt = "CallFinderMinimumCallIntervall"

let kFilterCallLength = "FilterCallsByLength"
let kFilterCallLengthMin = "FilterCallsByLengthMinimum"
let kFilterCallLengthMax = "FilterCallsByLengthMaximum"

let kCallFinderAdaptiveIntervals = "CallFinderUsesAdaptiveIntervalls"
let kCallFinderAdaptiveIntfactor = "CallFinderUsesAdaptiveIntervallsFactor"

let kCallFilterQualityCriteriumSelector = "CallFilterQualityCriteriumSelector"
let kCallFilterQualityCriteriumBandwidth = "CallFilterQualityCriteriumBandwidth"
let kCallFilterQualityCriterium = "CallFilterQualityCriterium"

let kCallFinderGenerateBatIdent1 = "CallFinderGenerateBatIdent1File"
let kCallFinderGenerateBatIdent2 = "CallFinderGenerateBatIdent2File"

let kCallFinderStereo = "CallFinderPreferredChannel"

let kCSVDecimalSep = "CSVExportDecimalSeparator"

public class BatCallFinderManager: CallFinderDelegate {
    
    let mySoundContainer: BatSoundContainer!
    
    //var callMeasures: Array<CallMeasurements>?
    var callBlocks: Array<Int>?
    var errorOccurred: Bool = false
    
    init(mySoundContainer: BatSoundContainer!) {
        self.mySoundContainer = mySoundContainer

    }
    
    public func exportForbatIdent(calls : Array<CallMeasurements>, toURL: URL) {
        var exportString = "Datei\tArt\tRuf\tDur\tSfreq\tEfreq\tStime\tNMod\tFMod\tFRmin\tRmin\ttRmin\tRlastms\tFlastms"
        
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
        
        let decimalSetting = UserDefaults.standard.integer(forKey: kCSVDecimalSep)
        if decimalSetting == 0 {
            nF.decimalSeparator = ","
            nF.groupingSeparator = "."
        }
        else if decimalSetting ==  1 {
            nF.decimalSeparator = "."
            nF.groupingSeparator = ","
        }
        
        for aCall in calls {
            if aCall.identData != nil {
                exportString += "\n\(toURL.lastPathComponent)"
                exportString += "\t\(aCall.species)"
                exportString += "\t\(aCall.callNumber)"
                let callSize = aCall.callData["Size"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:callSize))!
                let sFreq = aCall.callData["SFreq"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:sFreq))!
                let eFreq = aCall.callData["EFreq"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:eFreq))!
                let start = aCall.callData["Start"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:start))!
                let nmod = aCall.identData!["NMod"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:nmod))!
                let fmod = aCall.identData!["FMod"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:fmod))!
                let frmin = aCall.identData!["FRmin"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:frmin))!
                let rmin = aCall.identData!["Rmin"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:rmin))!
                let trmin = aCall.identData!["tRmin"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:trmin))!
                let rlastms = aCall.identData!["Rlastms"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:rlastms))!
                let flastms = aCall.identData!["Flastms"]!
                exportString += "\t"
                exportString += nF.string(from:NSNumber(value:flastms))!
                
                for index in 10..<60 {
                    guard let value = aCall.identData!["X\(index)"] else {
                        exportString += "\t0"
                        continue
                    }
                    exportString += "\t"
                    exportString += nF.string(from:NSNumber(value:value))!
                }
                
                for index in stride(from: 60, to: 150, by: 2) {
                    guard let value = aCall.identData!["X\(index)"] else {
                        exportString += "\t0"
                        continue
                    }
                    exportString += "\t"
                    exportString += nF.string(from:NSNumber(value:value))!
                }
                
            }
        }
        do {
            let fileURL = toURL.batIdentFileURL()
            try exportString.write(to: fileURL!, atomically: true, encoding: String.Encoding.macOSRoman)
        }
        catch let err as NSError {
            Swift.print("Error occured \(err)")
        }
    }
    
    public func getBlocksFromCalls(threshold: Double?) -> Array<Int>? {
        
            let callFinder = BatCallFinder()
            callFinder.samplerate = (self.mySoundContainer!.header!.samplerate*self.mySoundContainer!.header!.timeExpansion)
            
            callFinder.delegate = self
            if threshold != nil {
                callFinder.zfthreshold = threshold!
            }
            
            var startSample = 0
            if self.mySoundContainer?.header?.channelCount == 2 {
                startSample = (self.mySoundContainer?.header?.sampleCount)!
            }
            return callFinder.getBlocksFromCalls(startSample: startSample, numberOfSamples: (self.mySoundContainer?.header?.sampleCount)!)

    }
    
    public func findCalls(threshold: Double?, quality: Double = 20) -> Array<CallMeasurements>? {
            let callFinder = BatCallFinder()
            callFinder.samplerate = (self.mySoundContainer!.header!.samplerate*self.mySoundContainer!.header!.timeExpansion)
            //callFinder.delayFactor = self.delayFactor
            callFinder.delegate = self
            if threshold != nil {
                callFinder.zfthreshold = threshold!
            }
            callFinder.smooth = quality
            
            var startSample = 0
            if self.mySoundContainer?.header?.channelCount == 2 {
                if UserDefaults.standard.integer(forKey: kCallFinderStereo) == 1 {
                    startSample = self.mySoundContainer.header!.sampleCount
                }
            }
            
            var bcCalls = callFinder.measuresFromData(startSample: startSample, numberOfSamples: (self.mySoundContainer!.header?.sampleCount)!)
            if !bcCalls.isEmpty {
                return bcCalls
            }
            return nil
    }
    
    public func thresholdForInteger(inValue: Int) -> Double {
        switch inValue {
        case 18, -18: return (12.5/100.0)
        case 24, -24: return (6.25/100.0)
        case 27, -27: return (4.25/100.0)
        case 30, -30: return (3.125/100.0)
        case 34, -34: return (2.0/100.0)
        case 36, -36: return (1.5625/100.0)
        case 42, -42: return (0.78125/100.0)
        case 48, -48: return (0.390625/100.0)
        case 54, -54: return (0.1953125/100)
        case 60, -60: return (0.097656/100.0)
        case 66, -66: return (0.048828125/100.0)
        default: return (4.25/100.0)
        }
    }
    
}

extension RangeReplaceableCollection where Index : Comparable {
    mutating func removeAtIndices<S : Sequence>(indices: S) where S.Iterator.Element == Index {
        indices.sorted().lazy.reversed().forEach{ remove(at: $0) }
    }
}


final public class BatCallFinder {
    
    var delegate: CallFinderDelegate!
    
    var zcmse = 0.0
    var zcwindowsize = 100.0
    var srwindowsize = 200.0
    
    public var smooth = 2.0
    var samplehi = 200
    public var zfthreshold = 0.0
    
    var mincalldist = 15
    var mincalllength = 0.0
    
    var backmse = 100.0
    var formse = 100.0
    var mincallint = 15.0
    var srahead = 30
    
    var zeroThres = 1.0
    var hystThres = 2.0
    var useHyst = true
    var ampThres = 500.0
    
    public var samplerate: Int = 500000 {
        didSet {
            if (samplerate > 0) {
                sampleFactor = (samplerate*delayFactor)/1000
                time_correct = 1.0 / Double(sampleFactor)
            }
        }
    }
    public var sampleFactor = 500    // how many samples per millisecond, important for calculations
    var time_correct = 0.002 // milliseconds per sample, important for calculations
    public var delayFactor: Int = 1 {
        didSet {
            if delayFactor > 0 {
                sampleFactor = (samplerate*delayFactor)/1000
                time_correct = 1.0 / Double(sampleFactor)
            }
        }
    }
    
    var sampleCount = 0
    var sampleStart = 0
    
    //var rawSoundData: Array<Float>! // we need to store a reference only here somehow!
    var offset: Float = 0.0
    var dataArray: Array<CallMeasurements> = Array()
    var zcTimeData: Array<Float>=Array()
    var zcFreqData: Array<Double>=Array()
    
    public init() {
        self.setDefaults()
    }
    
    func regression_two(arr:Array<(Float, Float)>, numberOfSamples:Int) -> Double
    {
        //regression vars
        var s_x: Double = 0.0
        var ss_x: Double = 0.0
        var s_f: Double = 0.0
        var s_xf: Double = 0.0
        var r_s = 0.0
        let zero = arr[0].0 - 1
        
        var b: Double
        var a: Double
        var rsquare: Double
        let rgut = zcmse
        
        // sum of x's (we pull down everything towards zero!)
        for k in 0..<numberOfSamples {
            s_x = s_x + Double(arr[k].0-zero)
        }
        //for (k=0;k<n;k++) s_x = s_x + (arr[k][0]-zero);
        
        // sum of squares of x's (we pull down everything towards zero!)
        //for (k=0;k<n;k++) ss_x = ss_x + ( (arr[k][0]-zero)*(arr[k][0]-zero));
        for k in 0..<numberOfSamples {
            ss_x = ss_x + Double( (arr[k].0-zero)*(arr[k].0-zero))
        }
        
        // sum of frequencies
        for k in 0..<numberOfSamples {
            s_f = s_f + Double(arr[k].1)
        }
        //for (k=0;k<n;k++) s_f = s_f + arr[k][1];
        
        // sum of x*frequencies
        for k in 0..<numberOfSamples {
            s_xf = s_xf + Double( (arr[k].0-zero) * arr[k].1 )
        }
        //for (k=0;k<n;k++) s_xf = s_xf + ( (arr[k][0]-zero) * arr[k][1] );
        let divisor = (s_xf - ((s_x*s_f)/Double(numberOfSamples)))
        let divident = (ss_x-((s_x*s_x)/Double(numberOfSamples)))
        b = Double(divisor / divident)
        a = (s_f - (s_x * b)) / Double(numberOfSamples)
        
        
        r_s=0
        for k in 0..<numberOfSamples {
            // ( ( arr[k][1] - (a+((float)((arr[k][0]-zero)*b))))*( arr[k][1] - (a+((float)((arr[k][0]-zero)*b)))))
            let part1 = Double(arr[k].1) - (a+((Double(arr[k].0-zero)*b)))
            r_s = r_s + (part1 * part1)
        }
        
        //Attention: rsquare = MSE!
        rsquare = r_s / Double(numberOfSamples)
        
        if (rsquare <= rgut) {
            let x = a + ((Double(arr[0].0) + Double(zcwindowsize)/2 - Double(zero))*b)
            return x
        }
        return -1
    }
    
    func regressionFrom(start:Int, end:Int, withA regA:inout Double, withB regB:inout Double) -> Double
    {
        //regression vars
        var s_x = 0.0
        var ss_x = 0.0
        var s_f = 0.0
        var s_xf = 0.0
        var r_s = 0.0
        let zero: Float = zcTimeData[start] - 1
        let n: Int = end-start+1
        
        var b = 0.0
        var a = 0.0
        var rsquare = 0.0
        // sum of x's (we pull down everything towards zero!)
        
        for k in start...end { s_x = s_x + Double(zcTimeData[k]-zero) }
        //for (k=start;k<=end;k++) s_x = s_x + (zcTimeData[k]-zero);
        
        // sum of squares of x's (we pull down everything towards zero!)
        for k in start...end { ss_x = ss_x + (Double(zcTimeData[k]-zero)*Double(zcTimeData[k]-zero)) }
        //for (k=start;k<=end;k++) ss_x = ss_x + ((zcTimeData[k]-zero)*(zcTimeData[k]-zero));
        
        // sum of frequencies
        for k in start...end { s_f = s_f + zcFreqData[k] }
        //for (k=start;k<=end;k++) s_f = s_f + zcFreqData[k];
        
        // sum of x*frequencies
        for k in start...end { s_xf = s_xf + ( Double(zcTimeData[k]-zero) * zcFreqData[k] ) }
        //for (k=start;k<=end;k++) s_xf = s_xf + ( (zcTimeData[k]-zero) * zcFreqData[k] );
        
        b = (s_xf - ((s_x*s_f)/Double(n))) / (ss_x-((s_x*s_x)/Double(n)))
        a = (s_f - (s_x*b)) / Double(n)
        
        for k in start...end {
            let part: Double = (zcFreqData[k] - (a+(Double(zcTimeData[k]-zero)*b)))
            r_s = r_s + ( part * part)
        }
        //Attention: rsquare = MSE!
        rsquare = r_s / Double(n)
        regA = a
        regB = b
        return rsquare
    }
    
    func setDefaults()
    {
        if nil != UserDefaults.standard.object(forKey: "zcwindowsize") {
            zcwindowsize = (UserDefaults.standard.double(forKey: "zcwindowsize") / 1000.0) * Double(sampleFactor)
        }
        else {
            zcwindowsize = (300.0/1000.0) * Double(sampleFactor) // war 400/
        }
        
        if nil != UserDefaults.standard.object(forKey: "srwindowsize") {
            srwindowsize = (UserDefaults.standard.double(forKey: "srwindowsize") / 1000.0) * Double(sampleFactor)
        }
        else {
            srwindowsize = (200/1000.0) * Double(sampleFactor)
        }
        
        if nil != UserDefaults.standard.object(forKey: "zcmse") {
            zcmse = UserDefaults.standard.double(forKey: "zcmse")
        }
        else {
            zcmse = 2.0
        }
        
        if nil != UserDefaults.standard.object(forKey: kCallFinderGeneralQuality) {
            smooth = UserDefaults.standard.double(forKey: kCallFinderGeneralQuality)
        }
        else {
            smooth = 2.0
        }
        
        if nil != UserDefaults.standard.object(forKey: "samplehi") {
            samplehi = UserDefaults.standard.integer(forKey: "samplehi")
        }
        else {
            samplehi = 200
        }
        
        if nil != UserDefaults.standard.object(forKey: kCallFinderGeneralzfthreshold) {
            zfthreshold = UserDefaults.standard.double(forKey: kCallFinderGeneralzfthreshold)
        }
        else {
            zfthreshold = 0.015625
        }
        
        if nil != UserDefaults.standard.object(forKey: kCallFinderMinCallInt) {
            mincalldist = UserDefaults.standard.integer(forKey: kCallFinderMinCallInt)*sampleFactor
        }
        else {
            mincalldist = 50*sampleFactor // *500 variabel, angepasst an samplerate
        }
        
        if nil != UserDefaults.standard.object(forKey: "mincalllength") {
            mincalllength = UserDefaults.standard.double(forKey: "mincalllength")
        }
        else {
            mincalllength = 0.75
        }
        
        if nil != UserDefaults.standard.object(forKey: "backmse") {
            backmse = UserDefaults.standard.double(forKey: "backmse")
        }
        else {
            backmse = 0.16
        }
        
        if nil != UserDefaults.standard.object(forKey: "formse") {
            formse = UserDefaults.standard.double(forKey: "formse")
        }
        else {
            formse = 0.06
        }
        
        if nil != UserDefaults.standard.object(forKey: "srahead") {
            srahead = UserDefaults.standard.integer(forKey: "srahead")
        }
        else {
            srahead = 8
        }
        
        if nil != UserDefaults.standard.object(forKey: "mincallint") {
            mincallint = UserDefaults.standard.double(forKey: "mincallint")*Double(sampleFactor)
        }
        else {
            mincallint = 1.1*Double(sampleFactor); // *500 variabel, angepasst an samplerate !!!im bcAd3 550!!!
        }
        
        if nil != UserDefaults.standard.object(forKey: "hystThres") {
            hystThres = UserDefaults.standard.double(forKey: "hystThres") / 100.0
        }
        else {
            hystThres = 0.4 // 0.6
        }
        
        if nil != UserDefaults.standard.object(forKey: "useHyst") {
            useHyst = UserDefaults.standard.bool(forKey: "useHyst")
        }
        else {
            useHyst = true
        }
        
        if nil != UserDefaults.standard.object(forKey: "ampThres") {
            ampThres = UserDefaults.standard.double(forKey: "ampThres") / 100.0
        }
        else {
            ampThres = 0.003
        }
    }
    
    func getOffset() -> Float {
        var localOffset = 0.0
        
        var size = sampleCount
        if sampleCount > 500000 {
            size = 500000
        }
        
        var sumResult = 0.0
        
        for index in 0..<size {
            sumResult += Double((delegate.mySoundContainer.soundData?[index+sampleStart])!)
        }
        
        localOffset =  sumResult / Double(size)
        
        return Float(localOffset)
    }
    
    func calculateHysterese() {
        
        var soundSize = 250000
        if soundSize > sampleCount {
            soundSize = sampleCount
        }
        
        
        if useHyst && soundSize > 300*sampleFactor {
            var rmsArray = Array<Float>()
            for i in stride(from: 0, to: sampleCount-1001, by: (soundSize/10)) {
                var rms: Float = 0.0
                vDSP_rmsqv(Array(self.delegate.mySoundContainer.soundData![i..<i+1000]), 1, &rms, vDSP_Length(1000))
                rmsArray.append(rms)
            }
            var sortedArray = rmsArray.sorted()
            sortedArray.removeLast()
            //self.zeroThres = 2*hystThres*Double(sortedArray[sortedArray.count/2])
            //Swift.print(zeroThres)
            let sum = sortedArray.reduce(0) { result, number in
                result + number
            }

            // convert to double and divide by the count of the array
            let average = Double(sum) / Double(rmsArray.count)
            self.zeroThres = 1.5*hystThres*Double(average)
            /*Swift.print(2*hystThres*Double(average))
            Swift.print(2*hystThres*Double(sortedArray[sortedArray.count/2]))
            Swift.print("---")*/
            //Swift.print(rmsArray.sorted().last! - rmsArray.sorted().first!)
            if self.zeroThres > self.zfthreshold { self.zeroThres = 0.0003 }
        }
        else {
            self.zeroThres = self.ampThres
            if self.zeroThres > self.zfthreshold { self.zeroThres = 0.0003 }
        }
    }
    
    
    func calculateHystereseOld() {
        
        let soundSize = sampleCount - 50*sampleFactor
        
        zeroThres = 1.0
        
        if useHyst && soundSize > 500*sampleFactor {
            //var index = 0
            for i in stride(from: (25*sampleFactor), to: soundSize, by: (soundSize/10)) {
                let max = delegate.mySoundContainer.soundData?[sampleStart+i..<sampleStart+i+1000].max()!
                let min = delegate.mySoundContainer.soundData?[sampleStart+i..<sampleStart+i+1000].min()!
                if abs(min!) > max! {
                    if zeroThres > Double(abs(min!)) && abs(min!) > Float(0.0) {
                        zeroThres = Double(abs(min!))
                    }
                } else {
                if zeroThres > Double(max!) && max! > Float(0.0) {
                    zeroThres = Double(max!)
                }
                }
            }
            zeroThres = 2*zeroThres*hystThres
        }
        else {
            zeroThres = ampThres
            if zeroThres > zfthreshold { zeroThres = 0.0003 }
        }
        if zeroThres == 0 || zeroThres == 1 { zeroThres = 0.0003 } //war 10 davor ?!
        //if zeroThres > zfthreshold { zeroThres = 0.0003 }
    }
    
    func measuresFromData(startSample: Int, numberOfSamples:Int) -> Array<CallMeasurements> {
        //rawSoundData = delegate.mySoundContainer.soundData
        sampleCount = numberOfSamples
        sampleStart = startSample
        
        /*
         NSLock *theLock = [[NSLock alloc] init];
         [theLock lock];
         
         NSAutoreleasePool *localPool = [[NSAutoreleasePool alloc] init];
         
         if (tdaten != nil)
         [tdaten release];
         tdaten = [[NSMutableArray alloc] init];
         [self setDefaults];
         */
        
        /*if UserDefaults.standard.object(forKey: kFilterWaveFiles) != nil && UserDefaults.standard.bool(forKey: kFilterWaveFiles) {
            self.delegate.mySoundContainer.filter(hiPassFreq: 18000, lowPassFreq: 135000)
            self.delegate.mySoundContainer.amplify(amplifyValue: -6)
        }*/
        dataArray.removeAll()
        offset = Float(self.getOffset())
        
        //self.calculateHystereseOld()
        self.calculateHysterese()
        if zeroThres < 0.001 {
            zeroThres = 0
        }
        else if zeroThres > zfthreshold {
            zeroThres = 0.02
        }
        _ = self.findCalls()

        self.cleanUpCallData()
        
        
        /*
         [localPool release];
         
         [theLock unlock];
         [theLock release];
         */
        
        return dataArray
    }
    
    func getBlocksFromCalls(startSample: Int, numberOfSamples:Int) -> Array<Int>? {
        
        var blocksArray = Array<Int>()
        
        sampleCount = numberOfSamples
        sampleStart = startSample
        offset = Float(self.getOffset())
        
        self.calculateHysterese()
        let    size = sampleStart+sampleCount
        
        var a = 0, c = 0
        var k = 0
        var fi = 0
        var f: Array<Float> = Array(repeating:0.0, count: 150)
        var fc:Float = 0.0
        let range = 250
        var block = 0
        let substart=0
        
        var x:Float = 0.0
        var y: Float = 0.0
        let ZCOFFSET: Float = Float(zfthreshold) - offset // offset was removed !
        
        while k < ((size-1)-range) {
            c = 0
            fc = 0.0
            a = 0
            fi = 0
            block = k + range
            for j in k..<block {
                x = (delegate.mySoundContainer.soundData?[j])!
                let j_ = j+1
                y = (delegate.mySoundContainer.soundData?[j_])!
                if x <= ZCOFFSET  &&  y > ZCOFFSET && a != 0 {
                    f[c] = Float(j_-a)
                    fi += (j_-a)
                    c += 1
                    a = j_
                }
                else if x <= ZCOFFSET  &&  y > ZCOFFSET && a==0 {
                    a=j_
                }
                
            }
            
            if c > 6 {
                
                for j in 0..<(c-3) {
                    let absValue = abs(((f[j]-f[j+1])-(f[j+1]-f[j+2])))
                    fc = fc + absValue
                }
                
                fc = fc/Float(c-3)
                if fc<=Float(smooth) && fi >= samplehi && substart == 0 {
                    
                    blocksArray.append(k)
                    
                }
                
            }
            fc = 0.0;c = 0;x = 0;y = 0;
            k=k+range
        }
        
        if blocksArray.count > 0 {
            return blocksArray
        }
        return nil
    }
    
    func findCalls() -> Int {
        //var i = 0
        let    size = sampleStart+sampleCount
        
        var a = 0, c = 0
        var k = 0
        var fi = 0
        var f: Array<Float> = Array(repeating:0.0, count: 150)
        var fc:Float = 0.0
        let range = 250
        var block = 0
        var substart=0, subend=0, found=0, lastfound = 0
        var jumpmark = 0 // "Lücken" detector allows 1 to 3 blocks of gap size
        
        var x:Float = 0.0
        var y: Float = 0.0
        let ZCOFFSET: Float = Float(Int(zfthreshold*32768))/32768.0   // -< ursprünglich Float(zfthreshold) // offset was removed !
        //let ZCOFFSET: Float = Float(zfthreshold * 0.98)
        var searchWindow = 30 * sampleFactor
        if searchWindow > 10*sampleFactor && searchWindow >= mincalldist {
            searchWindow = mincalldist - 500
        }
        
        //for k=sampleStart;k<(size-1)-range; k=k+range {
        while k < ((size-1)-range) {
            c = 0
            //i = 0
            fc = 0.0
            a = 0
            fi = 0
            block = k + range
            
            for j in k..<block {
                x = (delegate.mySoundContainer.soundData?[j])! - offset
               
                let j_ = j+1
                y = (delegate.mySoundContainer.soundData?[j_])!  - offset
                
                if x <= ZCOFFSET  &&  y > ZCOFFSET && a != 0 {
                    f[c] = Float(j_-a)
                    fi += (j_-a)
                    c += 1
                    a = j_
                }
                else if x <= ZCOFFSET  &&  y > ZCOFFSET && a==0 {
                    a=j_
                }
                
                //j -= 1;
            }
            
            if c > 6 {
                
                for j in 0..<(c-3) {
                    let absValue = abs(((f[j]-f[j+1])-(f[j+1]-f[j+2])))
                    fc = fc + absValue
                }
                
                fc = fc/Float(c-3)
                if fc<=Float(smooth) && fi >= samplehi && substart == 0 {
                    
                    // Ruf position -> zcanalyse und sound regression
                    // Start ist k - 30*500 und ende ist k+30*500 samples
                    
                    substart = (k-30*500) >= 0 ? k-30*500 : 1
                    if lastfound != 0 && substart<lastfound {
                        substart = lastfound + 1
                    }
                    jumpmark = 0
                    
                }
                if fc>Float(smooth) && fi < samplehi && substart != 0 && subend == 0 {
                    
                    if jumpmark < 2 {
                        jumpmark += 1
                    }
                    else {
                        subend = (k+searchWindow) < size ? k+searchWindow : size-1
                        // found = [self searchForCallFrom:substart to:subend];
                        found = self.searchForCallFrom(starting: substart, ending: subend)
                        if (found==0) {
                            k=subend
                        }
                        else {
                            k = found
                            lastfound = found
                        }
                        //lastfound = found
                        subend = 0
                        substart = 0
                    }
                }
            }
                
            else if c<=6 && substart != 0
            {
                // !!! Needs to jump over small gaps, like the measuring algorithm does !!!
                // !!! needs to be in this routine, I think at least !!!
                
                if jumpmark < 2 {
                    jumpmark += 1
                }
                    
                else {
                    subend = (k+searchWindow) < size ? k+searchWindow : size-1
                    // found = [self searchForCallFrom:substart to:subend];
                    found = self.searchForCallFrom(starting: substart, ending: subend)
                    
                    if (found==0) {
                        k=subend
                    }
                    else {
                        k = found
                        lastfound = found;
                    }
                    //lastfound = found;
                    subend = 0;
                    substart = 0;
                    jumpmark = 0;
                }
            }
            fc = 0.0;c = 0;x = 0;y = 0;
            k=k+range
        }
        return dataArray.count
    }
    
    func searchForCallFrom(starting:Int, ending:Int) -> Int
    {
        
        /*    *****************************************************
         This block takes care of basic zero-crossing analysis
         as well as it does the first step in regression
         and results in a filled temparray which is used later for call extraction !
         ***************************************************** */
        var tempresults_time: Array<Float> = Array()
        var tempresults_wave: Array<Float> = Array()
        
        /*tempresults_time = (float*) malloc(zcDataSize*sizeof(float));
         if (tempresults_time == NULL) NSLog(@"Malloc problem for time");
         tempresults_wave = (float*) malloc(zcDataSize*sizeof(float));
         if (tempresults_wave == NULL) NSLog(@"Malloc problem for wave");
         */
        var k = 0, count = 0
        var m = 0, l = 0, n = 0, j = 0
        var xt: Float = 0.0
        
        var sw1: Float = 0.0
        var sw2: Float = 0.0
        
        let size = ending
        
        var pos: Bool = false
        var neg: Bool = false
        var jn: Float = 0.0
        
        for i in starting..<size {
            sw1 = (delegate.mySoundContainer.soundData?[i])! - offset
            sw2 = (delegate.mySoundContainer.soundData?[i+1])! - offset
            
            if (sw1<=Float(zeroThres)) && (sw2>Float(zeroThres)) {
                if (!pos) && (!neg) {
                    jn = Float(i) + (abs(sw1)/(abs(sw1)+abs(sw2)))
                    pos = true
                }
                else if pos && neg {
                    neg = false
                    tempresults_time.append(jn+((Float(i)-jn+(abs(sw1)/(abs(sw1)+abs(sw2))))/2.0)) //[m]=
                    tempresults_wave.append(Float(i)-jn+(abs(sw1)/(abs(sw1)+abs(sw2)))) //[m]=
                    m += 1
                    jn=Float(i)+(abs(sw1)/(abs(sw1)+abs(sw2)))
                }
                else if !pos && neg { pos=true }
            }
            else if sw1 > Float(-1*zeroThres) && sw2 <= Float(-1*zeroThres) {
                if !pos && !neg {
                    jn = Float(i) + (abs(sw1)/(abs(sw1)+abs(sw2)))
                    neg = true
                }
                else if pos && neg {
                    pos = false
                    tempresults_time.append(jn + ( ( Float(i) - jn + (abs(sw1)/(abs(sw1)+abs(sw2))))/2.0)) //[m] =
                    tempresults_wave.append(Float(i)-jn+(abs(sw1)/(abs(sw1)+abs(sw2)))) //[m]=
                    m += 1
                    jn=Float(i)+(abs(sw1)/(abs(sw1)+abs(sw2)))
                }
                else if !neg && pos { neg=true }
            }
            
            /*if (m >= zcDataSize) {
             zcDataSize *= 2;
             tempresults_time = (float*) realloc(tempresults_time,zcDataSize*sizeof(float));
             if (tempresults_time == NULL) NSLog(@"Malloc problem for time");
             tempresults_wave = (float*) realloc(tempresults_wave, zcDataSize*sizeof(float));
             if (tempresults_wave == NULL) NSLog(@"Malloc problem for wave");
             
             zcTimeData = realloc(zcTimeData,zcDataSize*sizeof(float));
             if (NULL == zcTimeData ) NSLog(@"Remalloc bug in TimeData");
             zcFreqData = realloc(zcFreqData,zcDataSize*sizeof(double));
             if (NULL == zcFreqData ) NSLog(@"Remalloc bug in FreqData");
             }*/
        }
        
        var temparray: Array<(Float,Float)> = Array(repeating:(0.0, 0.0), count:200)
        m -= 1
        var index = 0
        l = 0
        n = 0
        if tempresults_time.count < 2 {
            return 0
        }
        j = Int(tempresults_time[0])
        
        while ( index < tempresults_time.count && tempresults_time[index]-Float(j) < Float(zcwindowsize) /*&& index <= m*/) {
            temparray.append((Float(tempresults_time[index]),Float(tempresults_wave[index])))
            //temparray[l][0] = tempresults_time[index]
            //temparray[l][1] = tempresults_wave[index]
            l += 1
            index += 1
        }
        
        if (index >= tempresults_time.count) {
            index = tempresults_time.count-1
        }
        
        if tempresults_time[index] - Float(j) > Float(zcwindowsize) {
            index -= 1
            l -= 1
        }
        l += 1
        
        zcTimeData.append(0.0)
        zcFreqData.append(0.0)
        
        while index <= m {        // found all data of one window... quality and regression ?
            xt = Float(regression_two(arr: temparray, numberOfSamples:l))
            if xt < 60 && xt>0 { // Woher kommen diese Werte ???
                count += 1;
                zcTimeData.append(Float(temparray[0].0) + Float(zcwindowsize/2.0))
                zcFreqData.append(1.0/Double(xt*Float(time_correct)))
                //NSLog(@"at i %d w/ 1.MSE: d %.02f ; freq %.02f",i,zcTimeData[count]-zcTimeData[count-1],zcFreqData[count]);
            }
            
            if Int(index) == Int(m) && Float(tempresults_time[index] - tempresults_time[n]) < Float(zcwindowsize*0.75) { break }
            //NSLog(@"i %d",i);
            n += 1
            // STILL NEEDED?! if n >= zcDataSize { break }
            if n >= tempresults_time.count { break }
            j = Int(tempresults_time[n])
            
            while Int(tempresults_time[index]) - j < Int(zcwindowsize) && index < m { index += 1 }
            
            while Int(tempresults_time[index]) - j > Int(zcwindowsize) || index > m { index -= 1 }
            
            //for l=0;l<=(index-n);l++ {
            for inL in 0...(index-n) {
                temparray[inL].0 = tempresults_time[n+inL]
                temparray[inL].1 = tempresults_wave[n+inL]
            }
            l = (index-n)+1
            //NSLog(@"i %d, n %d, l %d und i-n %d und count %d",n,i,l,i-n, count);
        }
        
        zcTimeData[0]=Float(count)
        tempresults_time.removeAll()
        tempresults_wave.removeAll()
        
        /*    *********************
         end of zero crossing analysis
         **********************/
        
        
        /*    *****************************************************
         Now we have to find the exact call location and get
         the call measurements. This was formerly known as
         SoundRegression. It will decide what to return to the caller
         ***************************************************** */
        
        // NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];  // do we need this ?
        
        m = 0; index = 0; j = 0; l = 0; k = 0; count = 0;
        
        var start = 1
        var startsample = 0.0
        var callstart = 0.0
        var end = 0
        var startFound = false
        var mse = 0.0
        var regA = 0.0
        var regB = 0.0
        
        var zeroAdjust = 0.0
        var measureCount = 0
        var lastMeasure = 0.0
        var msCallStart = 0.0
        var maxDist: Float = 0.0
        
        var startPoints: Array<Int> = Array(repeating:0, count: 200)
        var endingPoints: Array<Int> = Array(repeating:0, count: 200)
        var lengthSamples: Array<Int> = Array(repeating:0, count: 200)
        
        var sprung = srahead-1
        
        if zcTimeData.count < 2 {
            return 0
        }
        
        end = Int(zcTimeData[0])
        startsample = Double(zcTimeData[1])
        index = start+sprung
        
        // 11.12.2009
        // OKAY: Some crashing recordings went over the 100 array count = k;
        // we do now cancel all above 100... should we deal with it in any other way, what are the consequences ???
        // NEEDS a LOT of DEBUGGING and UNDERSTANDING!!!!!
        
        while (index <= end && k < 199) {
            
            //mse = [self regressionFrom:start to:i withA:&regA withB:&regB];
            mse = self.regressionFrom(start: start, end: index, withA: &regA, withB: &regB)
            //zeroAdjust = zcTimeData[start]-1;
            
            maxDist = 0.0
            for l in start..<index {
                if Float(zcTimeData[l+1] - zcTimeData[l]) > maxDist {
                    maxDist = zcTimeData[l+1] - zcTimeData[l]
                }
            }
            
            if maxDist <= Float(mincallint) {
                if (mse<=formse) {
                    if (!startFound) {
                        startFound = true
                        startPoints[k]=start
                        callstart=startsample
                    }
                }
                else if (mse>formse) {
                    if (startFound) {
                        startFound = false
                        endingPoints[k]=index-1
                        lengthSamples[k]=Int(zcTimeData[index-1]-Float(callstart))
                        k += 1
                    }
                }
            }
                
            else if (startFound && maxDist > Float(mincallint)) {
                startFound = false
                l = start
                while zcTimeData[l+1] - zcTimeData[l] <= Float(mincallint) { l += 1 }
                index=l
                endingPoints[k]=index
                lengthSamples[k]=Int(zcTimeData[index]-Float(callstart))
                k += 1
            }
            
            start += 1
            startsample = Double(zcTimeData[start])
            index=start+sprung
        }
        
        if (startFound && start < end) { // Ende abfangen !!!
            startFound = false
            index = end
            //mse = [self regressionFrom:start to:i withA:&regA withB:&regB];
            mse = self.regressionFrom(start: start, end: index, withA: &regA, withB: &regB)
            maxDist=0.0
            //for (l=start;l<index;l++) {
            for inL in start..<index {
                if Float(zcTimeData[inL+1] - zcTimeData[inL]) > maxDist { maxDist = zcTimeData[inL+1] - zcTimeData[inL] }
            }
            l = index
            
            if maxDist <= Float(mincallint) {
                if (mse<=formse) {
                    endingPoints[k]=index
                    lengthSamples[k]=Int(zcTimeData[index]-Float(callstart))
                    k += 1
                }
                else if (mse>formse) {
                    index = start-1+sprung
                    endingPoints[k]=index
                    lengthSamples[k]=Int(zcTimeData[index-1]-Float(callstart))
                    k += 1
                }
            }
                
            else if maxDist > Float(mincallint) {
                l = start
                while zcTimeData[l+1] - zcTimeData[l] <= Float(mincallint) { l += 1 }
                index=l
                endingPoints[k]=index
                lengthSamples[k]=Int(zcTimeData[index]-Float(callstart))
                k += 1
            }
        }
        else if (startFound && start == end ) {
            startFound = false
            index = end
            endingPoints[k]=index
            lengthSamples[k]=Int(zcTimeData[index]-Float(callstart))
        }
        
        /*    *********************
         end of sound regression
         **********************/
        // before we start, we lower the "sprung" to get more acurate regeressions
        sprung = 4
        
        //NSMutableDictionary *tempDict = [[NSMutableDictionary dictionary] retain];
        var tempDict: Dictionary<String,Float> = Dictionary()
        
        for l in 0..<k {
            //autoreleasepool {
            if lengthSamples[l]>=250 {
                m=startPoints[l]
                startsample = Double(self.zcTimeData[m])
                zeroAdjust = startsample-1
                callstart=startsample-(self.zcwindowsize/2.0)
                msCallStart = self.time_correct*callstart;
                
                index=1;
                while (self.zcTimeData[m+index]-self.zcTimeData[m] <= Float(self.sampleFactor/10)) { index += 1}
                //NSLog(@"i %d",i);
                
                //mse = [self regressionFrom:m to:m+i withA:&regA withB:&regB];
                mse = self.regressionFrom(start: m, end: m+index, withA: &regA, withB: &regB)
                
                // if (nil!=tempDict) [tempDict release]; //removed on crash in this line, do not understand it yet
                tempDict["Startsample"] = Float(callstart)
                tempDict["Start"] = Float(self.time_correct*callstart)
                tempDict["SFreq"] = Float(regA+((callstart-zeroAdjust))*regB)
                tempDict["Freq1"] = Float(regA+(((callstart+Double(self.sampleFactor/10))-zeroAdjust))*regB)
                tempDict["Time1"] = Float((self.time_correct*(callstart+Double(self.sampleFactor/10)))-msCallStart)
                tempDict["Freq2"] = Float(regA+((callstart+Double(self.sampleFactor/10)*2) - zeroAdjust)*regB)
                tempDict["Time2"] = Float((self.time_correct*((callstart+Double(self.sampleFactor/10)*2)))-msCallStart)
                
                // wegen 300us Fenster rausgenommen!
                //[tempDict setObject:[NSNumber numberWithFloat:(regA+(((callstart+150)) - zeroAdjust)*regB)] forKey:@"Freq3"];
                //[tempDict setObject:[NSNumber numberWithFloat:(time_correct*((callstart+150)))-msCallStart] forKey:@"Time3"];
                
                measureCount = 2;
                lastMeasure = callstart+Double(self.sampleFactor/10)*2
                
                var realSample = Double(((msCallStart + 0.1*Double(measureCount))*Double(self.sampleFactor)))
                let endAt = Double(self.zcTimeData[endingPoints[l]])
                
                let d10 = Double(self.sampleFactor/10)
                let d20 = Double(self.sampleFactor/20)
                let greaterTimeDataIndex = endingPoints[l]
                while self.zcTimeData[m] < self.zcTimeData[greaterTimeDataIndex] && (realSample+d10) <= (endAt+d20) {
                    if (startsample < realSample+d10) {
                        m += 1
                        startsample = Double(self.zcTimeData[m])
                    }
                    
                    if (startsample >= lastMeasure) {
                        measureCount += 1
                        zeroAdjust = startsample-1
                        realSample = ((msCallStart + 0.1*Double(measureCount))*Double(self.sampleFactor))
                        while (startsample > realSample) {
                            m -= 1
                            if m<0 {
                                m = 0
                                break
                            }
                            startsample=Double(self.zcTimeData[m])
                        }
                        zeroAdjust = startsample-1
                        if (m+sprung > endingPoints[l]) {
                            //mse = [self regressionFrom:endingPoints[l]-sprung to:endingPoints[l] withA:&regA withB:&regB];
                            mse = self.regressionFrom(start: endingPoints[l]-sprung, end: endingPoints[l], withA: &regA, withB: &regB)
                            zeroAdjust = Double(self.zcTimeData[endingPoints[l]-sprung])-1
                        }
                        else {
                            if realSample > Double(self.zcTimeData[m+sprung]) {
                                index=0
                                while (m+sprung+index < self.zcTimeData.count-1 && realSample > Double(self.zcTimeData[m+sprung+index]) && index < endingPoints[l]) {index += 1}
                                //mse = [self regressionFrom:m to:m+sprung+i withA:&regA withB:&regB];
                                mse = self.regressionFrom(start: m, end: m+sprung+index, withA: &regA, withB: &regB)
                            }
                            //mse = [self regressionFrom:m to:m+sprung withA:&regA withB:&regB];
                            mse = self.regressionFrom(start: m, end: m+sprung, withA: &regA, withB: &regB)
                        }
                        tempDict["Freq\(measureCount)"] = Float(regA+(realSample - zeroAdjust)*regB)
                        tempDict["Time\(measureCount)"] = Float((self.time_correct*(realSample))-msCallStart)
                        //[tempDict setObject:[NSNumber numberWithFloat:(regA+(realSample - zeroAdjust)*regB)] forKey:[NSString stringWithFormat:@"Freq%d",measureCount]];
                        //[tempDict setObject:[NSNumber numberWithFloat:(time_correct*(realSample))-msCallStart] forKey:[NSString stringWithFormat:@"Time%d",measureCount]];
                        lastMeasure = realSample
                    }
                }
                
                realSample = realSample+d10
                measureCount += 1
                zeroAdjust = Double(self.zcTimeData[m])-1
                if (m+sprung > endingPoints[l]) {
                    /* älterer kommentar! i=1;
                     while (zcTimeData[l]-zcTimeData[l-i] <= (sampleFactor/10)) i++;
                     if (i>2) i--;
                     mse = [self regressionFrom:endingPoints[l]-i to:endingPoints[l] withA:&regA withB:&regB];
                     zeroAdjust = zcTimeData[endingPoints[l]-i]-1;*/
                    
                    //mse = [self regressionFrom:endingPoints[l]-sprung to:endingPoints[l] withA:&regA withB:&regB];
                    mse = self.regressionFrom(start: endingPoints[l]-sprung, end: endingPoints[l], withA: &regA, withB: &regB)
                    zeroAdjust = Double(self.zcTimeData[endingPoints[l]-sprung])-1
                }
                else {
                    //mse = [self regressionFrom:m to:m+sprung withA:&regA withB:&regB];
                    mse = self.regressionFrom(start: m, end: m+sprung, withA: &regA, withB: &regB)
                }
                tempDict["EFreq"] = Float((regA+(realSample - zeroAdjust)*regB))
                tempDict["Size"] = Float(self.time_correct*(realSample - callstart))
                tempDict["Sizesample"] = Float(realSample - callstart)
                //[tempDict setObject:[NSNumber numberWithFloat:(regA+(realSample - zeroAdjust)*regB)] forKey:@"EFreq"];
                //[tempDict setObject:[NSNumber numberWithFloat:time_correct*(realSample - callstart)] forKey:@"Size"];
                //[tempDict setObject:[NSNumber numberWithInt:realSample - callstart] forKey:@"Sizesample"];
                
                if (realSample < endAt+self.zcwindowsize/2-d10) {
                    tempDict["Freq\(measureCount)"] = Float((regA+(realSample - zeroAdjust)*regB))
                    tempDict["Time\(measureCount)"] = Float((self.time_correct*(realSample))-msCallStart)
                    
                    //[tempDict setObject:[NSNumber numberWithFloat:(regA+(realSample - zeroAdjust)*regB)] forKey:[NSString stringWithFormat:@"Freq%d",measureCount]];
                    //[tempDict setObject:[NSNumber numberWithFloat:(time_correct*(realSample))-msCallStart] forKey:[NSString stringWithFormat:@"Time%d",measureCount]];
                    
                    realSample = realSample+d10
                    /* alter kommentar ! i=1;
                     while (zcTimeData[l]-zcTimeData[l-i] <= (sampleFactor/10)) i++;
                     if (i>2) i--;
                     mse = [self regressionFrom:endingPoints[l]-i to:endingPoints[l] withA:&regA withB:&regB];
                     zeroAdjust = zcTimeData[endingPoints[l]-i]-1;*/
                    
                    mse = self.regressionFrom(start: endingPoints[l]-sprung, end: endingPoints[l], withA: &regA, withB: &regB)
                    zeroAdjust = Double(self.zcTimeData[endingPoints[l]-sprung])-1
                    
                    tempDict["EFreq"] = Float((regA+(realSample - zeroAdjust)*regB))
                    tempDict["Size"] = Float(self.time_correct*(realSample - callstart))
                    tempDict["Sizesample"] = Float(realSample - callstart)
                    
                    //[tempDict setObject:[NSNumber numberWithFloat:(regA+(realSample - zeroAdjust)*regB)] forKey:@"EFreq"];
                    //[tempDict setObject:[NSNumber numberWithFloat:time_correct*(realSample - callstart)] forKey:@"Size"];
                    //[tempDict setObject:[NSNumber numberWithInt:realSample - callstart] forKey:@"Sizesample"];
                }
                //for (m=0;m<6;m++) NSLog(@"m: %d Time %f und F %f",m,zcTimeData[endingPoints[l]-5+m],zcFreqData[endingPoints[l]-5+m]);
                let thisCallMeasures = CallMeasurements(callData: tempDict, callNumber:0, species:"", speciesProb:0, meanFrequency: 0.0)
                
                self.dataArray.append(thisCallMeasures)
                //[tdaten addObject:[[tempDict mutableCopy] autorelease]];
            }
            //} // autorelease
        }
        zcTimeData.removeAll()
        zcFreqData.removeAll()
        
        if tempDict.count < 1 {
            tempDict.removeAll()
            return 0
        }
        else {
            let returnValue = tempDict["Startsample"]! + tempDict["Sizesample"]!
            tempDict.removeAll()
            return Int(returnValue)
        }
    }
    
    func cleanUpCallData() {
        
        var i = 0
        var count = dataArray.count
        var last: Float = 0.0
        var lastStart: Float = 0.0
        
        while i<count {
            if dataArray[i].callData["Size"]! < Float(mincalllength)
            {
                dataArray.remove(at: i)
                i -= 1
                count -= 1
            }
            else if UserDefaults.standard.bool(forKey: kFilterCallLength) {
                let lowerBound = UserDefaults.standard.float(forKey: kFilterCallLengthMin)
                let upperBound = UserDefaults.standard.float(forKey: kFilterCallLengthMax)
                if dataArray[i].callData["Size"]! <= lowerBound || dataArray[i].callData["Size"]! >= upperBound {
                    dataArray.remove(at: i)
                    i -= 1
                    count -= 1
                }
            }
            i += 1
        }
        
        count = dataArray.count
        
        if count > 1 {
            
            if UserDefaults.standard.bool(forKey: kCallFinderAdaptiveIntervals) {
                
                var adaptiveFactor = 5.0
                if UserDefaults.standard.object(forKey: kCallFinderAdaptiveIntfactor) != nil {
                    adaptiveFactor = UserDefaults.standard.double(forKey: kCallFinderAdaptiveIntfactor)
                }
                
                last = dataArray[0].callData["Startsample"]!+dataArray[0].callData["Sizesample"]!
                
                i = 1
                
                var localMinIntervall = dataArray[0].callData["Sizesample"]! * Float(adaptiveFactor)
                
                while i<count {
                    
                    if dataArray[i].callData["Startsample"]! - last < Float(localMinIntervall) {
                        dataArray.remove(at: i)
                        i -= 1
                        count -= 1
                    }
                    else {
                        last = dataArray[i].callData["Startsample"]!+dataArray[i].callData["Sizesample"]!
                        localMinIntervall = dataArray[i].callData["Sizesample"]! * Float(adaptiveFactor)
                    }
                    i += 1
                }
                count = dataArray.count
                lastStart = -1
                //for i=0;i<count;i++ {
                for i in 0..<count {
                    let myStart = dataArray[i].callData["Startsample"]
                    dataArray[i].callData["Startsample"] = myStart! - Float(sampleStart)
                    if dataArray[i].callData["Startsample"]! < 0 {
                        dataArray[i].callData["Startsample"] = myStart!
                    }
                    dataArray[i].callNumber = i+1
                    if lastStart < 0 {
                        dataArray[i].callData["IPI"] = 0
                    }
                    else {
                        dataArray[i].callData["IPI"] = dataArray[i].callData["Start"]! - lastStart
                    }
                    lastStart = dataArray[i].callData["Start"]!
                }
                
            }
            else {
                last = dataArray[0].callData["Startsample"]!+dataArray[0].callData["Sizesample"]!
                
                //for i=1;i<count;i++ {
                i = 1
                while i<count {
                    if dataArray[i].callData["Startsample"]! - last < Float(mincalldist) {
                        dataArray.remove(at: i)
                        i -= 1
                        count -= 1
                    }
                    else {
                        last = dataArray[i].callData["Startsample"]!+dataArray[i].callData["Sizesample"]!
                    }
                    i += 1
                }
                count = dataArray.count
                lastStart = -1
                //for i=0;i<count;i++ {
                for i in 0..<count {
                    let myStart = dataArray[i].callData["Startsample"]
                    dataArray[i].callData["Startsample"] = myStart! - Float(sampleStart)
                    if dataArray[i].callData["Startsample"]! < 0 {
                        dataArray[i].callData["Startsample"] = myStart!
                    }
                    dataArray[i].callNumber = i+1
                    if lastStart < 0 {
                        dataArray[i].callData["IPI"] = 0
                    }
                    else {
                        dataArray[i].callData["IPI"] = dataArray[i].callData["Start"]! - lastStart
                    }
                    lastStart = dataArray[i].callData["Start"]!
                }
            }
            
            count = dataArray.count
            
            if count > 2 {
                if UserDefaults.standard.bool(forKey: kCallFilterQualityCriterium) {
                    // statistical call filtering
                    if let fileCallAverages = dataArray.callAverages() {
                        
                        var upperRange: Float = (0.5 / 2.0) + 1
                        var lowerRange: Float = 1 - (0.5 / 2.0)
                        if UserDefaults.standard.integer(forKey: kCallFilterQualityCriteriumBandwidth) == 1 {
                            upperRange = (0.75 / 2.0) + 1
                            lowerRange = 1 - (0.75 / 2.0)
                        }
                        else if UserDefaults.standard.integer(forKey: kCallFilterQualityCriteriumBandwidth) == 2 {
                            upperRange = 2
                            lowerRange = 0.5
                        }
                        
                        var criterion = fileCallAverages[.durationAverage]
                        if UserDefaults.standard.integer(forKey: kCallFilterQualityCriteriumSelector) == 1 {
                            criterion = fileCallAverages[.durationMedian]
                        }
                        var indexSetForRemoval = IndexSet()
                        
                        if criterion != nil {
                            for (index, aCall) in dataArray.enumerated() {
                                if aCall.callData["Size"]! > criterion! * upperRange || aCall.callData["Size"]! < criterion! * lowerRange {
                                    indexSetForRemoval.insert(index)
                                    continue
                                }
                                if !indexSetForRemoval.isEmpty {
                                    dataArray[index].callNumber -= indexSetForRemoval.count
                                }
                            }
                        }
                        if !indexSetForRemoval.isEmpty {
                            dataArray.removeAtIndices(indices: indexSetForRemoval)
                        }
                    }
                }
            }
            count = dataArray.count
        }
        
        if count == 1 {
            dataArray[0].callNumber = 1
        }
    }
}
