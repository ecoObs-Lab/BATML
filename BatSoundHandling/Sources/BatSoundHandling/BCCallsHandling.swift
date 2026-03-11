//
//  BCCallsHandling.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 23.01.26.
//

import Foundation

public struct CallMeasurements: CustomStringConvertible, Equatable, Hashable {
    public init(callData: Dictionary<String,Float>, callNumber:Int, species:String, speciesProb:Float, meanFrequency: Float, identData: Dictionary<String, Float>?) {
        // Initialize all stored properties before using self
        self.callData = callData
        self.callNumber = callNumber
        self.species = species
        self.speciesProb = speciesProb
        self.meanFrequency = meanFrequency
        self.identData = identData
        self.callClass = 0
        self.callDist = nil
        self.callType = 0
        self.kneeFreq = 0.0
        self.kneePos = 0
        self.kneeAlpha = 0.0
        self.kneeR = 0.0
        self.myoFreq = 0.0
        self.myoPos = 0
        self.myoAlpha = 0.0
        self.myoR = 0.0
        self.medianFreq = 0.0
        self.middleFreq = 0.0
        self.dqcf = 0.0
        self.dfm = 0.0
        // After all properties are initialized, it’s safe to compute derived measurements
        self.calculateDerivedMeasurements()
    }
    
    public init(callData: Dictionary<String,Float>, callNumber:Int, species:String, speciesProb:Float, meanFrequency: Float) {
        self.init(callData: callData, callNumber:callNumber, species:species, speciesProb:speciesProb, meanFrequency: meanFrequency, identData: nil)
    }
    
    public static func ==(lhs: CallMeasurements, rhs: CallMeasurements) -> Bool {
        return lhs.callNumber == rhs.callNumber && lhs.callData["Start"]! == rhs.callData["Start"]!
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.callData["Start"])
            hasher.combine(callNumber)
        }
    
    public var callData: Dictionary<String,Float> {
        didSet {
            self.calculateDerivedMeasurements()
        }
    }
    
    
    public var callNumber: Int = 0
    public var species: String = ""
    public var speciesProb: Float = 0.0
    public var meanFrequency: Float = 0.0
    public var identData: Dictionary<String, Float>?
    public var callClass: Int = 0 // Good, bad, other
    public var callDist: Array<Float>?
    
    public var callType: Int? = 0 // 1 qcf, 2 fm-qcf, 3 fm
    public var kneeFreq: Float? = 0.0
    public var kneePos: Float? = 0
    public var kneePosD: Float? {
        mutating get {
            return self.kneePos! / Float(self.measurements!.count)
        }
    }
    public var kneeAlpha: Float? = 0.0
    public var kneeR:  Float? = 0.0
    public var myoFreq: Float? = 0.0
    public var myoPos: Float? = 0
    public var myoPosD: Float? {
        mutating get {
            return self.myoPos! / Float(self.measurements!.count)
        }
    }
    public var myoAlpha: Float? = 0.0
    public var myoR: Float? = 0.0
    public var medianFreq: Float? = 0.0
    public var middleFreq: Float? = 0.0
    public var dqcf : Float? = 0.0
    public var dfm : Float? = 0.0
    public var Rmitte : Float {
        var mutatableSelf = self
        if mutatableSelf.steigungen == nil {
            return 0
        }
        
        if mutatableSelf.steigungsMittel!.count % 2 == 0 {
            return (mutatableSelf.steigungsMittel![mutatableSelf.steigungsMittel!.count/2] + mutatableSelf.steigungsMittel![mutatableSelf.steigungsMittel!.count/2 + 1]) / 2.0
        }
        else {
            return mutatableSelf.steigungsMittel![mutatableSelf.steigungsMittel!.count/2]
        }
    }
    
    public lazy var avgSteig: Float = {
        var mutatableSelf = self
        if mutatableSelf.steigungen == nil {
            return 0
        }
        let sum = mutatableSelf.steigungen!.reduce(0, +)
        let count = mutatableSelf.steigungen!.count
        return sum / Float(count)
    }()
    
    public lazy var medSteig: Float = {
        var mutatableSelf = self
        if mutatableSelf.steigungen == nil {
            return 0
        }
        let sorted = mutatableSelf.steigungen!.sorted()
        if sorted.count % 2 != 0 {
            return sorted[sorted.count/2]
        }
        else {
            return (sorted[(sorted.count-1)/2] + sorted[(sorted.count+1)/2]) * 0.5
        }
    }()
    
    public lazy var measurements: Array<Float>? = {
        var tempMeasurements: Array<Float> = Array()
        tempMeasurements.append(self.callData["SFreq"]!)
        var idx: Int = 1
        while self.callData["Freq\(idx)"] != nil {
            tempMeasurements.append(self.callData["Freq\(idx)"]!)
            idx += 1
        }
        tempMeasurements.append(self.callData["EFreq"]!)
        
        if tempMeasurements.count < 4 {
            return nil
        }
        return tempMeasurements
    }()
    
    public lazy var steigungen: Array<Float>? = {
        guard let measurements = self.measurements else {
            return nil
        }
        var tempSteigungen: Array<Float> = Array()
        
        for index in 1..<measurements.count {
            tempSteigungen.append((measurements[index] - measurements[index-1])) // Steigung je (0,1) ms
        }
        
        return tempSteigungen
    }()
    
    let stepSize = 4
    
    public lazy var steigungsMittel: Array<Float>? = {
        guard let steigungen = self.steigungen else {
            return nil
        }
        var tempSteigungen: Array<Float> = Array()
        
        for index in stride(from: 0, to: steigungen.count, by: 1) {
            if index <= steigungen.count - stepSize {
                var sum : Float = 0
                for subIndex in index..<index+stepSize {
                    sum += steigungen[subIndex]
                }
                tempSteigungen.append(sum/Float(stepSize))
            }
        }
        return tempSteigungen
    }()
    
    public lazy var Fmidf: Float? = {
        if self.measurements == nil {
            return nil
        }
        return (self.measurements!.max()! - self.measurements!.min()!)/2.0 + self.measurements!.min()!
    }()
    
    public lazy var tmidf : Float? = {
        guard let fmidf = self.Fmidf else {
            return nil
        }
        if self.measurements == nil {
            return nil
        }
        if fmidf < self.measurements!.first! {
            var idx = 0
            while fmidf < self.measurements![idx] {
                idx += 1
            }
            return Float(idx)*0.1
        } else {
            var idx = 0
            while fmidf > self.measurements![idx] {
                idx += 1
            }
            return Float(idx)*0.1
        }
    }()

    public var Fmidt: Float? {
        get {
            self.middleFreq
        }
    }
    
    public var description: String {
        let callStart = callData["Start"]!
        let callDur = callData["Size"]!
        return "Call Number: \(callNumber) with start and dur: \(callStart) \(callDur) \n"
    }
    
    public var bcCallsRepresentation: NSMutableDictionary {
            var myDict = callData
            myDict.updateValue(Float(callNumber), forKey:"Call")
            myDict.updateValue(Float(0), forKey:"callClass")
            return NSMutableDictionary(dictionary: myDict)
    }
    
    public mutating func calculateDerivedMeasurements() {
        
        guard let measurements = self.measurements else {
            return
        }
        let numberOfValues = 4
        var winkel_alpha: Array<Float> = Array()
        if measurements.count < numberOfValues {
            return
        }
        
        for idx in 0..<self.steigungsMittel!.count-numberOfValues {
            let winkel = (self.steigungsMittel![idx+numberOfValues] - self.steigungsMittel![idx]) / (1 + (self.steigungsMittel![idx+numberOfValues] * self.steigungsMittel![idx]))
            winkel_alpha.append(atan(winkel) * 180 / Float.pi)
        }
        
        var max : Float = -100000
        var maxPos = winkel_alpha.count / 2 + 1
        if !winkel_alpha.isEmpty {
            for runIdx in 0..<(winkel_alpha.count / 2 + 1) {
                if winkel_alpha[runIdx] > max {
                    max = winkel_alpha[runIdx]
                    maxPos = runIdx
                }
            }
        }
        
        if max > 0 && maxPos+numberOfValues <= Int(0.75 * Double(measurements.count)) {
            self.kneeFreq = self.callData["Freq\(maxPos+numberOfValues)"]
            self.kneePos = Float(maxPos+numberOfValues)
            self.kneeAlpha = max
            self.kneeR = (self.steigungsMittel![maxPos] + self.steigungsMittel![maxPos+numberOfValues]) / 2.0
        }
        else {
            self.kneeFreq = measurements.first
            self.kneePos = 0
            self.kneeAlpha = 0
            self.kneeR = 0
        }
        
        var min : Float = 10000
        var minPos = 0
        
        if self.kneePos == 0 {
            maxPos = Int(0.5 * Double(winkel_alpha.count)) // was measurements.count, wrong ?!
        }
        
        for runIdx in maxPos..<winkel_alpha.count {
            if winkel_alpha[runIdx] < min {
                min = winkel_alpha[runIdx]
                minPos = runIdx
            }
        }
        
        if min < 0 && minPos+numberOfValues >= Int(0.5 * Double(measurements.count)) {
            self.myoFreq = self.callData["Freq\(minPos+numberOfValues)"]
            self.myoPos =  Float(minPos+numberOfValues)
            self.myoAlpha = min
            self.myoR = (self.steigungsMittel![minPos] + self.steigungsMittel![minPos+numberOfValues]) / 2.0
        } else {
            let pos = self.measurements?.count ?? 0
            self.myoFreq = self.measurements?.last ?? 0
            self.myoPos = Float(pos)
            self.myoAlpha = min
            self.myoR = self.steigungsMittel?.last ?? 0
        }
        
        if measurements.count % 2 != 0 {
            self.middleFreq = measurements[measurements.count/2]
            self.medianFreq = measurements.sorted()[measurements.count/2]
        }
        else {
            self.middleFreq = (measurements[measurements.count/2-1] + measurements[measurements.count/2]) / 2.0
            self.medianFreq = (measurements.sorted()[measurements.count/2-1] + measurements.sorted()[measurements.count/2]) / 2.0
        }
        
        var qcfLength = 0
        var lastQCF = 0
        for aValue in self.steigungsMittel! {
            if abs(aValue) < 0.1 {
                qcfLength += 1
            }
            else {
                if qcfLength > lastQCF {
                    lastQCF = qcfLength
                    qcfLength = 0
                }
            }
        }
        if qcfLength > lastQCF {
            lastQCF = qcfLength
            qcfLength = 0
        }
        self.dqcf = Float(lastQCF+3) * 0.1
        
        var fmLength = 0
        var lastFM = 0
        for aValue in self.steigungsMittel! {
            if abs(aValue) > 0.1 {
                fmLength += 1
            }
            else {
                if fmLength > lastFM {
                    lastFM = fmLength
                    fmLength = 0
                }
            }
        }
        if fmLength > lastFM {
            lastFM = fmLength
            fmLength = 0
        }
        self.dfm = Float(lastFM+3) * 0.1
    }
    
    public func getCallStart() -> Float {
        self.callData["Start"] ?? 0
    }
    
    public func getCallDuration() -> Float {
        self.callData["Size"] ?? 0
    }
    
    public func getCallStartsample() -> Float {
        self.callData["Startsample"] ?? 0
    }
    
    public func getCallSizesample() -> Float {
        self.callData["Sizesample"] ?? 0
    }
}

public class CallCSVExporter {
    
    var klassen_avg: [Double] = Array(repeating: 0.0, count: 152)
    
    public init() {}
    
    // #define ELEM_SWAP(a,b) { register float t=(a);(a)=(b);(b)=t; }
    func swap(a: inout Float, b: inout Float) {
        let temporaryA = a
        a = b
        b = temporaryA
    }
    
    func newSwap(data: inout Array<Float>, firstPos:Int, secondPos: Int) {
        let temporaryA = data[firstPos]
        data[firstPos] = data[secondPos]
        data[secondPos] = temporaryA
    }
    
    func median(arr: inout Array<Float>, count: Int) -> Float {
        //var inArray: [Float] = arr
        var low = 0
        var high = count - 1
        let median = (low + high) / 2
        var middle = 0
        var ll = 0
        var hh = 0
        
        while 1==1 {
            if high <= low {
                return arr[median]
            }
            
            if high == low + 1 {  /* Two elements only */
                
                if (arr[low] > arr[high]) {
                    self.newSwap(data: &arr, firstPos: low, secondPos: high)
                }
                return arr[median]
            }
            
            /* Find median of low, middle and high items; swap into position low */
            middle = (low + high) / 2
            if arr[middle] > arr[high]    { self.newSwap(data: &arr, firstPos: middle, secondPos: high)}
            if arr[low] > arr[high]       { self.newSwap(data: &arr, firstPos: low, secondPos: high)}
            if arr[middle] > arr[low]     { self.newSwap(data: &arr, firstPos: middle, secondPos: low) }
            
            /* Swap low item (now in position middle) into position (low+1) */
            self.newSwap(data: &arr, firstPos: middle, secondPos: low+1)
            
            ll = low + 1
            hh = high
            
            while 1==1 {
                repeat { ll += 1 } while (arr[low] > arr[ll])
                repeat { hh -= 1 } while (arr[hh]  > arr[low])
                
                if (hh < ll) { break }
                
                self.newSwap(data: &arr, firstPos: ll, secondPos: hh)
            }
            
            self.newSwap(data: &arr, firstPos: low, secondPos: hh)
            
            if hh <= median { low = ll }
            if hh >= median { high = hh - 1 }
        }
    }
    
    func maxFreq(arr: Array<Float>, count: Int) -> Float {
        var max: Float
        var i = 1
        max = arr[0]
        
        while i<count {
            if max<arr[i] {
                max = arr[i]
            }
            i += 1
        }
        return max
    }
    
    func minFreq(arr: Array<Float>, count: Int) -> Float {
        var min: Float
        var i = 1
        min = arr[0]
        
        while i<count {
            if min>arr[i] {
                min = arr[i]
            }
            i += 1
        }
        return min
    }
    
    func steigung(arr: Array<Array<Float>>, count: Int) -> Float
    {
        //regression vars
        var s_x: Double // 10 if avgsize = 4!
        var ss_x: Double // 10 if avgsize = 4!
        var s_f = 0.0
        var s_xf = 0.0
        var b: Double
        //var a: Double = 0.0
        // end regression vars
        
        //var k: Int
        
        // sum of x's
        s_x = 0
        for k in 0..<count {
            s_x = s_x + Double(arr[k][0])
        }
        
        // sum of squares of x's
        ss_x=0
        for k in 0..<count {
            ss_x = ss_x + Double( (arr[k][0]) * (arr[k][0]) )
        }
        
        // sum of frequencies
        s_f=0
        for k in 0..<count {
            s_f = s_f + Double(arr[k][1])
        }
        
        // sum of x*frequencies
        s_xf=0
        for k in 0..<count {
            s_xf = s_xf + Double( (arr[k][0]) * arr[k][1] )
        }
        
        //b = (double) (s_xf - ((s_x*s_f)/(float)n)) / (double) (ss_x-(((s_x*s_x)/(float)n)));
        b = (s_xf - ((s_x*s_f)/Double(count))) / (ss_x - ( (s_x*s_x) / Double(count)))
        //a = (s_f - (s_x*b)) / Double(count)
        
        return Float(b)
    }
    
    func modalFreq(arr: Array<Float>, count: Int, steig: inout Float) -> Float
    {
        var wsize = 24
        var start = 0
        var merker: Int = 0
        
        var min: Float = 1000.0
        var temp: Float
        var data: Array<Array<Float>> = Array()
        for index in 0..<wsize {
            data.append([Float(index), Float(0.0)])
        }
        
        while wsize < count {
            //for i = start; i < wsize; i++ {
            for i in start..<wsize {
                data[i-start][1] = arr[i]
            }
            
            temp = self.steigung(arr: data, count: wsize-start)
            if temp<min {
                min = temp
                merker = start
            }
            start += 1
            wsize += 1
        }
        
        var tempArray: Array<Float> = Array(repeating:Float(), count: wsize)
        //for (i = 0; i < wsize-start; i++) {
        for i in 0..<(wsize-start) {
            tempArray[i] = arr[i+merker];
        }
        
        steig = 10*min;
        return self.median(arr: &tempArray, count: wsize-start)
    }
    
    func getNMod(call: Dictionary<String, Float>, freq: inout Int ) -> Float {
        var l: Int
        //var j: Int
        var index: Int
        var nfreq = 0
        freq = nfreq
        
        l = Int(ceil(10.0*call["Size"]!))
        //l = ceil(10*[[call objectForKey:@"Size"] floatValue])
        
        while nil==call["Freq\(l)"] && l > 0{
            l -= 1
        }
        
        if l == 0 {
            return Float(0)
        }
        
        var klassen_alle: [Int] = Array(repeating: 0, count:152)
        //for j=0;j<152;j++ {
        for j in 0..<152 {
            klassen_alle[j]=0
            self.klassen_avg[j] = 0.0
        }
        
        // Fill histogram data ***
        var tempArray: [Float] = Array(repeating: 0.0, count:l+2)
        
        //var subJ: Int
        var expJ = (l+1)*9 + l + 1
        var fPart = 0.0
        
        tempArray[l+1] = call["EFreq"]!
        tempArray[0] = call["SFreq"]!
        
        index = Int(floor(call["SFreq"]!))
        index = (index>150 ? 0 : index)
        if index < 0 {
            index = 0
        }
        
        klassen_alle[index] = klassen_alle[index]+1
        
        //for (j=l;j>0;j--) {
        for j in stride(from: l, to: 0, by: -1) {
            tempArray[j] = call["Freq\(j)"]!
            expJ -= 1
            
            index = Int(floor(call["Freq\(j)"]!))
            index = (index>150 ? 0 : index)
            if index < 0 {
                index = 0
            }
            klassen_alle[index] = klassen_alle[index]+1
            
            fPart = Double(tempArray[j] - tempArray[j+1]) / 10.0
            //for (subJ = 1; subJ < 10; subJ++) {
            for subJ in 1..<10 {
                expJ -= 1
                index = Int(floor(Double(tempArray[j])-fPart*Double(subJ)))
                index = (index>150 ? 0 : index)
                if index < 0 {
                    index = 0
                }
                klassen_alle[index] = klassen_alle[index]+1
            }
        }
        
        fPart = Double(tempArray[0] - tempArray[1]) / 10.0
        
        //for (subJ = 1; subJ < 10; subJ++) {
        for subJ in 1..<10 {
            expJ -= 1
            index = Int(floor(Double(tempArray[0])-fPart*Double(subJ)))
            index = (index>150 ? 0 : index)
            if index < 0 {
                index = 0
            }
            klassen_alle[index] = klassen_alle[index]+1
        }
        
        // *** End of histogram fill
        
        // *** Start of Average Shifted Histogramm ***
        var odd = 9
        var even=9
        var sum=0
        
        //for (j = 10; j < 150; j++) { // upper limit was 151 -> lead to a crash!
        for j in stride(from: 10, to: 150, by: 2) {
            even += 1
            odd += 1
            sum = klassen_alle[even]+klassen_alle[even+1] + klassen_alle[odd-1]+klassen_alle[odd]
            klassen_avg[j]=Double(sum)/4.0
            even += 1
            odd += 1
            sum=klassen_alle[even]+klassen_alle[even+1] + klassen_alle[odd-1]+klassen_alle[odd]
            klassen_avg[j+1]=Double(sum)/4.0
        }
        
        // *** End of Average Shifted Histogramm ***
        
        var nmod = 0.0
        //for (j = 10; j < 151; j++) {
        for j in 10..<151 {
            if (nmod < klassen_avg[j]) {
                nmod = klassen_avg[j]
                nfreq=j
            }
        }
        
        
        freq = nfreq
        return Float(nmod)
    }
    
    func getRMinForCall(call: Dictionary<String, Float>, Rmin: inout Float, FRmin : inout Float, tRmin: inout Float ) {
        
        var l = 0
        //var j = 0
        var minpos = 0
        
        var tempR: Float = 0.0
        var rmin: Float = 0.0
        var fmin: Float = 0.0
        var tmin: Float = 0.0
        
        l = Int(ceil(10.0*call["Size"]!))
        
        while nil==call["Freq\(l)"] && l > 0{
            l -= 1
        }
        
        if l == 0 {
            Rmin = Float(0)
            FRmin = Float(0)
            tRmin = Float(0)
            return
        }
        
        var rs: [Float] = Array(repeating:0.0, count:l+1)
        var fs: [Float] = Array(repeating:0.0, count:l+1)
        var ts: [Float] = Array(repeating:0.0, count:l+1)
        
        rs[0] = (call["SFreq"]!-call["Freq1"]!) / 0.1
        fs[0] = (call["SFreq"]!+call["Freq1"]!) / 2.0
        ts[0] = -1.0*(call["Size"]!-0.1)
        rs[l] = (call["Freq\(l)"]!-call["EFreq"]!) / 0.1
        fs[l] = (call["Freq\(l)"]!+call["EFreq"]!) / 2.0
        ts[l] = -0.0
        
        //for (j=1;j<l-1;j++) {
        for j in 1..<(l-1) {
            rs[j] = ((call["Freq\(j)"]! - call["Freq\(j+1)"]!) / 0.1)
            fs[j] = ((call["Freq\(j)"]! + call["Freq\(j+1)"]!) / 2.0)
            ts[j] = -1.0 * (call["Size"]! - (call["Size"]! - (0.1*Float(l-j+1))))
        }
        
        minpos = 0
        tempR = abs((rs[0]+rs[1]+rs[2])/3.0)
        //for (j=1;j<l-3;j++) {
        for j in 1..<(l-3) {
            if (tempR>abs(((rs[j]+rs[j+1]+rs[j+2])/3.0))) {
                tempR=abs(((rs[j]+rs[j+1]+rs[j+2])/3.0))
                minpos=j
            }
        }
        
        rmin = abs(rs[minpos])
        fmin = fs[minpos]
        tmin = ts[minpos]
        
        //for (j=minpos+1;j<minpos+3;j++) {
        for j in minpos+1..<(minpos+3) {
            if (rmin>abs(rs[j])) {
                rmin = abs(rs[j])
                fmin = fs[j]
                tmin = ts[j]
            }
        }
        Rmin = rmin
        FRmin = fmin
        tRmin = tmin
    }
    
    public func exportCallMeasurements( inArray: Array<CallMeasurements>, to url: URL ) throws {
        if #available(macOS 13.0, *) {
            try self.exportCallMeasurements(inArray: inArray, toFile: url.path())
        } else {
            try self.exportCallMeasurements(inArray: inArray, toFile: url.path)
        }
    }
    
    public func generateCallMeasurements(inArray: inout Array<CallMeasurements>, newMeasurementsIncluded: Bool = false) {
        var l = 0
        
        var nmod: Float = 0.0
        var rmin: Float = 0.0
        var frmin: Float = 0.0
        var trmin: Float = 0.0
        var nfreq = 99
        
        // add parameters per call entry
       
        for i in 0..<inArray.count {
            var callDict: Dictionary<String,Float> = Dictionary()
            
            nmod = self.getNMod(call: inArray[i].callData, freq:&nfreq)
            callDict.updateValue(nmod, forKey: "NMod")
            callDict.updateValue(Float(nfreq), forKey: "FMod")
            
            self.getRMinForCall(call: inArray[i].callData, Rmin: &rmin, FRmin: &frmin, tRmin: &trmin)
            callDict.updateValue(frmin, forKey: "FRmin")
            callDict.updateValue(rmin, forKey: "Rmin")
            callDict.updateValue(trmin, forKey: "tRmin")
            
            if inArray[i].dqcf! >= 1 && inArray[i].dfm! >= 1 {
                inArray[i].callType = 2
            }
            else if inArray[i].dqcf! < 1 && inArray[i].dfm! >= 1 {
                inArray[i].callType = 3
            }
            else if inArray[i].dqcf! >= 1 && inArray[i].dfm! < 1 {
                inArray[i].callType = 1
            }
            
            l = Int(ceil(10.0*inArray[i].callData["Size"]!))
            while nil==inArray[i].callData["Freq\(l)"] && l > 0 {
                l -= 1
            }
            
            if l == 0 {
                continue
            }
            
            
            // LASTMS Neu Berechnungen ****** ****** ****** ****** ****** ******
            var lastOneArray: [Float] = Array(repeating:0.0, count:12-5)
            var lastRArray: [Float] = Array(repeating:0.0, count:12-6)
            var k = 0
            
            //lastOneArray[13-7] = inArray[i].callData["EFreq"]!
            //lastRArray[12-6] = (inArray[i].callData["Freq\(l)"]!-inArray[i].callData["EFreq"]!)/0.1
            
            k = 0
            
            
            //for j in (l-10)..<l {
            for j in (l-12)..<l-5 {
                if j<1 { continue }
                lastOneArray[k] = inArray[i].callData["Freq\(j)"]!
                k += 1
            }
            
            k = 0;
            
            //for j in (l-10)..<(l-1) {
            for j in (l-12)..<(l-6) { // neu im November 23 nach Telefonat mit Uli
                if j < 1 { continue }
                lastRArray[k] = (inArray[i].callData["Freq\(j+1)"]!-inArray[i].callData["Freq\(j)"]!)/0.1
                k += 1
            }
            
            //callDict.updateValue(self.median(arr: &lastRArray,count: 10), forKey:"Rlastms")
            let avg = lastRArray.reduce(0,+)
            callDict.updateValue(avg/Float(lastRArray.count), forKey:"Rlastms")
            //callDict.updateValue(self.median(arr: &lastOneArray,count: 11), forKey:"Flastms")
            let avgF = lastOneArray.reduce(0,+)
            callDict.updateValue(avgF/Float(lastOneArray.count), forKey:"Flastms")
            
            // ENDE LASTMS Neu Berechnungen ****** ****** ****** ****** ****** ******
            
            //exportString += "\t\(self.median(&lastRArray,count: 10))" // 10 udn 11 vertauscht, aber geht eigentlich nicht wegen definierter größe der arrays ?! NACHPRÜFEN!
            //exportString += "\t\(self.median(&lastOneArray,count: 11))"
            
            for j in stride(from: 10, to: 61, by: 1) {
                callDict.updateValue(Float(klassen_avg[j]), forKey:"X\(j)")
                //exportString += "\t\(klassen_avg[j])"
            }
            
            //for j in 60.stride(to: 150, by: 1)
            //for (j=60;j<150;j++) {
            for j in stride(from: 61, to: 150, by: 2) {
                callDict.updateValue(Float(klassen_avg[j])+Float(klassen_avg[j+1]), forKey:"X\(j+1)")
                //exportString += "\t\(klassen_avg[j]+klassen_avg[++j])"
            }
            
            if newMeasurementsIncluded {
                var aCall = inArray[i]
                if let kneeFreq = aCall.kneeFreq {
                    callDict.updateValue(kneeFreq, forKey: "Fknee")
                    callDict.updateValue(aCall.kneeAlpha!, forKey: "Alphaknee")
                    callDict.updateValue(aCall.kneeR!, forKey: "Rknee")
                    callDict.updateValue(aCall.kneePosD!, forKey: "ptknee")
                }
                
                if let myoFreq = aCall.myoFreq {
                    callDict.updateValue(myoFreq, forKey: "Fmk")
                    callDict.updateValue(aCall.myoAlpha!, forKey: "Alphamk")
                    callDict.updateValue(aCall.myoR!, forKey: "Rmk")
                    callDict.updateValue(aCall.myoPosD!, forKey: "ptmk")
                }
                
                if let medianFreq = aCall.medianFreq {
                    callDict.updateValue(medianFreq, forKey: "Fmed")
                }
                
                if let middleFreq = aCall.Fmidt {
                    callDict.updateValue(middleFreq, forKey: "Fmidt")
                }
                
                if let middleFreq = aCall.Fmidf {
                    callDict.updateValue(middleFreq, forKey: "Fmidf")
                }
                
                
                let tmidf = aCall.tmidf!///aCall.callData["Size"]!
                callDict.updateValue(tmidf, forKey: "tmidf")
                
                // falsch ?! let ptmidf = ((aCall.Fmidt! - aCall.measurements!.min()!)/(aCall.measurements!.max()! -  aCall.measurements!.min()!))
                let ptmidf = aCall.tmidf! / aCall.callData["Size"]!
                callDict.updateValue(ptmidf, forKey: "ptmidf")
                
                let PFmidt = ((aCall.Fmidt!-aCall.measurements!.min()!)/(aCall.measurements!.max()! -  aCall.measurements!.min()!))
                callDict.updateValue(PFmidt, forKey: "PFmidt")
                
                callDict.updateValue(aCall.Rmitte, forKey: "Rmidt")
                callDict.updateValue(aCall.medSteig, forKey: "Rmed")
                callDict.updateValue(aCall.avgSteig, forKey: "Rges")
                
                callDict.updateValue(aCall.dfm!, forKey: "Dfm")
                callDict.updateValue(aCall.dqcf!, forKey: "Dqcf")
                
                
                if aCall.dqcf! >= 1 && aCall.dfm! >= 1 {
                    aCall.callType = 2
                }
                else if aCall.dqcf! < 1 && aCall.dfm! >= 1 {
                    aCall.callType = 3
                }
                else if aCall.dqcf! >= 1 && aCall.dfm! < 1 {
                    aCall.callType = 1
                }
                
                callDict.updateValue(Float(aCall.callType!), forKey: "Typ")
                
            }
            
            inArray[i].identData = callDict
        }
    }
    
    public func exportCallMeasurements(inArray: Array<CallMeasurements>, toFile:String) throws {
        
        var exportString = ""
        //var i = 0
        //var j = 0
        var l = 0
        
        var nmod: Float = 0.0
        var rmin: Float = 0.0
        var frmin: Float = 0.0
        var trmin: Float = 0.0
        var nfreq = 99
        
        exportString += "Datei\tArt\tRuf\tDur\tSfreq\tEfreq\tStime\tNMod\tFMod\tFRmin\tRmin\ttRmin\tRlastms\tFlastms"
        // Generate labels for classing according... first 10 to 60 kHz 1 kHz bins, then 2 kHz bins to 150
        for i in 0..<50 {
            exportString += NSString(format: "\tX%2d", i+10) as String
        }
        //i = 0
        for i in stride(from: 0, to: 90, by: 2) {
            exportString += NSString(format:"\tX%2d", i+60) as String
        }
        
        // add parameters per call entry
        for i in 0..<inArray.count {
            // original war: geht nicht in swift, wieso war das da überhaupt? if (![[[inArray objectAtIndex:i] objectForKey:@"Call"] isKindOfClass:[NSString class]]) {
            let size = inArray[i].callData["Size"]!
            let SFreq = inArray[i].callData["SFreq"]!
            let EFreq = inArray[i].callData["EFreq"]!
            let Start = inArray[i].callData["Start"]!
            exportString += "\n\t\(inArray[i].species)\t\(inArray[i].callNumber)\t\(size)\t\(SFreq)\t\(EFreq)\t\(Start)"
            
            nmod = self.getNMod(call: inArray[i].callData, freq:&nfreq)
            exportString += "\t\(nmod)\t\(nfreq)"
            
            self.getRMinForCall(call: inArray[i].callData, Rmin: &rmin, FRmin: &frmin, tRmin: &trmin)
            exportString += "\t\(frmin)\t\(rmin)\t\(trmin)"
            
            l = Int(ceil(10.0*inArray[i].callData["Size"]!))
            while nil==inArray[i].callData["Freq\(l)"] {
                l -= 1
            }
            
            var lastOneArray: [Float] = Array(repeating:0.0, count:11)
            var lastRArray: [Float] = Array(repeating:0.0, count:10)
            var k = 0
            
            lastOneArray[10] = inArray[i].callData["EFreq"]!
            lastRArray[9] = (inArray[i].callData["Freq\(l)"]!-inArray[i].callData["EFreq"]!)/0.1
            
            k = 0
            //for j=l-10;j<l;j++ {
            for j in l-10..<l {
                if j < 1 { continue }
                lastOneArray[k] = inArray[i].callData["Freq\(j)"]!
                k += 1
            }
            
            k = 0;
            //for j=l-10;j<l-1;j++ {
            for j in l-10..<(l-1) {
                if j < 1 { continue }
                lastRArray[k] = (inArray[i].callData["Freq\(j)"]!-inArray[i].callData["Freq\(j+1)"]!)/0.1
                k += 1
            }
            
            exportString += "\t\(self.median(arr: &lastRArray,count: 10))" // 10 udn 11 vertauscht, aber geht eigentlich nicht wegen definierter größe der arrays ?! NACHPRÜFEN!
            exportString += "\t\(self.median(arr: &lastOneArray,count: 11))"
            
            //for (j=10;j<60;j++) {
            for j in 10...60 {
                exportString += "\t\(klassen_avg[j])"
            }
            //for (j=60;j<150;j++) {
            for j in stride(from: 61, to: 150, by: 2) {
                exportString += "\t\(klassen_avg[j]+klassen_avg[j+1])"
            }
            
        }
        
        try exportString.write(toFile: toFile, atomically:true, encoding:String.Encoding.macOSRoman)
    }
    
}

public extension Array where Element == CallMeasurements {
    
    enum callMeasurementAverageKeys: String {
        case callCount
        case durationAverage
        case durationMedian
        case bandwidthAverage
        case bandwidthMedian
        case sfreqAverage
        case sfreqMedian
        case efreqAverage
        case efreqMedian
        case fmitteAverage
        case fmitteMedian
    }
    
    func callAverages() -> Dictionary<callMeasurementAverageKeys, Float>? {
        var returnDict = Dictionary<callMeasurementAverageKeys, Float>()
        if self.isEmpty {
            return nil
        }
        returnDict.updateValue(Float(self.count), forKey: .callCount)
        returnDict.updateValue(self.averageDuration(), forKey: .durationAverage)
        returnDict.updateValue(self.medianDuration(), forKey: .durationMedian)
        returnDict.updateValue(self.averageBandwidth(), forKey: .bandwidthAverage)
        returnDict.updateValue(self.medianBandwidth(), forKey: .bandwidthMedian)
        returnDict.updateValue(self.averageSFreq(), forKey: .sfreqAverage)
        returnDict.updateValue(self.medianSFreq(), forKey: .sfreqMedian)
        returnDict.updateValue(self.averageEFreq(), forKey: .efreqAverage)
        returnDict.updateValue(self.medianEFreq(), forKey: .efreqMedian)
        returnDict.updateValue(self.averageFMitte(), forKey: .fmitteAverage)
        returnDict.updateValue(self.medianFMitte(), forKey: .fmitteMedian)
        return returnDict
    }
    
    func averageDuration() -> Float {
        let sumDur = self.lazy.compactMap { $0.callData["Size"] ?? 0.0 }.reduce(0, +)
        return sumDur / Float(self.count)
    }
    
    func medianDuration() -> Float {
        let durations = self.lazy.compactMap { $0.callData["Size"] ?? 0.0 }.sorted()
        if durations.count < 3 {
            return durations.last!
        }
        return durations[durations.count/2]
    }
    
    func averageBandwidth() -> Float {
        let sumBW = self.lazy.compactMap { ($0.callData["SFreq"] ?? 0.0) - ($0.callData["EFreq"] ?? 0.0) }.reduce(0, +)
        return sumBW / Float(self.count)
    }
    
    func medianBandwidth() -> Float {
        let bws = self.lazy.compactMap { ($0.callData["SFreq"] ?? 0.0) - ($0.callData["EFreq"] ?? 0.0) }.sorted()
        if bws.count < 3 {
            return bws.last!
        }
        return bws[bws.count/2]
    }
    
    func averageSFreq() -> Float {
        let sumBW = self.lazy.compactMap { $0.callData["SFreq"] ?? 0.0 }.reduce(0, +)
        return sumBW / Float(self.count)
    }
    
    func medianSFreq() -> Float {
        let bws = self.lazy.compactMap { $0.callData["SFreq"] ?? 0.0 }.sorted()
        if bws.count < 3 {
            return bws.last!
        }
        return bws[bws.count/2]
    }
    
    func averageEFreq() -> Float {
        let sumBW = self.lazy.compactMap { $0.callData["EFreq"] ?? 0.0 }.reduce(0, +)
        return sumBW / Float(self.count)
    }
    
    func medianEFreq() -> Float {
        let bws = self.lazy.compactMap { $0.callData["EFreq"] ?? 0.0 }.sorted()
        if bws.count < 3 {
            return bws.last!
        }
        return bws[bws.count/2]
    }
    
    func averageFMod() -> Float {
        let sumFMod = self.lazy.compactMap { ($0.callData["FMod"] ?? 0.0)}.reduce(0, +)
        return sumFMod / Float(self.count)
    }
    
    func averageFMitte() -> Float {
        let sumFMod = self.lazy.compactMap { ($0.middleFreq ?? 0.0)}.reduce(0, +)
        return sumFMod / Float(self.count)
    }
    
    func medianFMitte() -> Float {
        let bws = self.lazy.compactMap { $0.middleFreq ?? 0.0 }.sorted()
        if bws.count < 3 {
            return bws.last!
        }
        return bws[bws.count/2]
    }
    
}

