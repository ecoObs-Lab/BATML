//
//  SwiftUIView.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 29.01.26.
//

import SwiftUI

public struct BatSoundOverView: View {
    
    @Binding var batRecording: BatRecording?
    @Binding var selectedCall: CallMeasurements?
    
    @State var sonaWidth: CGFloat = 800
    
    @State private var samples: Array<Float> = []
    @State var waveFillColor: Color
    @State var waveHeight: CGFloat
    
    @State private var sonaImg: CGImage?
    @State private var markerPosition: CGFloat = 0.0
    
    @AppStorage(SonaGain) var sonaGain: Double = 0.0
    @AppStorage(SonaSpread) var sonaSpread: Double = 1.0
    
    public init(batRecording: Binding<BatRecording?>, selectedCall: Binding<CallMeasurements?>, sonaWidth: CGFloat = 800, waveFillColor: Color = .green, waveHeight: CGFloat = 128) {
        self._batRecording = batRecording
        self._selectedCall = selectedCall
        self.sonaWidth = sonaWidth
        self.waveFillColor = waveFillColor
        self.waveHeight = waveHeight
    }
    
    public var body: some View {
        VStack(spacing:0) {
            AudioWave(samples: $samples, width: 2, fillColor: $waveFillColor, normalized: false)
                .frame(height: waveHeight)
                .overlay(alignment: .bottomLeading) {
                    if self.selectedCall != nil {
                        Image(systemName: "chevron.up")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .offset(x: sonaWidth * markerPosition - 12, y: 0)
                            .foregroundColor(.white)
                    }
                }
            if let img = self.sonaImg {
                Image(img,
                      scale: 1.0,
                      orientation: .left,
                      label: Text("Sonagram"))
                .overlay(alignment: .topLeading) {
                    if self.selectedCall != nil {
                        Image(systemName: "chevron.down")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .offset(x: sonaWidth * markerPosition - 12, y: 0)
                            .foregroundColor(.white)
                    }
                }
            }
            HStack {
                Slider(value: $sonaGain, in: -128...128) { editing in
                    if !editing {
                        self.updateViewData()
                    }
                }
                Slider(value: $sonaSpread, in: -5...5) { editing in
                    if !editing {
                        self.updateViewData()
                    }
                }
            }
            .frame(width: 800)
        }
        .onChange(of: selectedCall) {
            if self.selectedCall != nil {
                let callStart = self.selectedCall!.getCallStart()
                if let msMax = self.batRecording?.soundContainer?.msMax {
                    self.markerPosition = CGFloat(callStart / Float(msMax))
                } else {
                    self.markerPosition = 0
                }
            }
        }
        .onChange(of: batRecording) {
            self.updateViewData()
        }
        .onAppear {
            self.updateViewData()
        }
    }
    
    func updateViewData() {
        guard let batRecording = self.batRecording else {
            self.sonaImg = nil
            self.samples = Array()
            return
        }
        self.sonaImg = batRecording.overviewSonagram(height: 256, expectedWidth: sonaWidth, gain: Float(sonaGain), spreadFactor: Float(sonaSpread))
        self.samples = batRecording.soundContainer!.downsample(count: Int(sonaWidth)/4)
    }
}

#Preview {
    // For preview/demo, create local @State to pass bindings.
    struct PreviewWrapper: View {
        @State var recording: BatRecording? = nil
        @State var call: CallMeasurements? = nil
        var body: some View {
            BatSoundOverView(batRecording: $recording, selectedCall: $call)
        }
    }
    return PreviewWrapper()
}
