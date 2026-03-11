//
//  SwiftUIView.swift
//  BatSoundHandling
//
//  Created by Volker Runkel on 29.01.26.
//

import SwiftUI

// based on https://medium.com/@lucasmrowskovskypaim/writing-a-high-performance-audio-wave-in-swiftui-09bfc5bcd133

public struct AudioWave: View {
    
    @Binding var samples: [Float]
    @Binding var fillColor: Color
    @State var normalized: Bool

    let spacing: CGFloat
    let width: CGFloat

    
    public init(samples: Binding<Array<Float>>, spacing: CGFloat = 2, width: CGFloat = 2, fillColor: Binding<Color>, normalized: Bool = false) {
        self._samples = samples
        self.spacing = spacing
        self.width = width
        self._fillColor = fillColor
        self.normalized = normalized
    }
    
    public var body: some View {
        GeometryReader { geo in
            AudioWaveShape(samples: $samples, normalized: $normalized, spacing: spacing, width: width)
                .fill(self.fillColor)
                .background(Color.black)
        }
    }
}
private struct AudioWaveShape: Shape {
    
    @Binding var samples: [Float]
    @Binding var normalized: Bool
    let spacing: CGFloat
    let width: CGFloat

    
    nonisolated func path(in rect: CGRect) -> Path {
        Path { path in
            var currentX = 0.0
            let maxSample = normalized ? (samples.max() ?? 1) : 1
            for sample in samples {
                var height = max(Double(sample / maxSample) * rect.height, 1)
                
                path.addRect (
                    CGRect(
                        x: currentX,
                        y: -height / 2,
                        width: width,
                        height: height
                    )
                )
                currentX += width + spacing
            }
        }.offsetBy(dx: 0, dy: rect.height / 2)
    }
}

/*public struct AudioWaveStereo: View {
    
    @Binding var samples: [Float]

    let spacing: CGFloat
    let width: CGFloat

    
    init(samples: Binding<Array<Float>>, spacing: CGFloat = 2, width: CGFloat = 2) {
        self._samples = samples
        self.spacing = spacing
        self.width = width
    }
    
    var body: some View {
        GeometryReader { geo in
            AudioWaveShape(samples: $samples[safe: 0..<(samples.count / 2)], spacing: spacing, width: width)
                .fill(Color.green)
                .background(Color.black)
                .frame(height: geo.size.height / 2)
                .offset(x: 0, y:0)
            
            AudioWaveShape(samples: $samples[safe: (samples.count / 2)..<samples.count], spacing: spacing, width: width)
                .fill(Color.orange)
                .background(Color.black)
                .frame(height: geo.size.height / 2)
                .offset(x: 0, y:geo.size.height / 2)
        }
    }
}*/
