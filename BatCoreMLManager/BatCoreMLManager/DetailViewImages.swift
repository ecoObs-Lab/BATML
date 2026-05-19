//
//  DetailViewImages.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 05.02.26.
//

import SwiftUI

struct DetailViewImages: View {
    
    @Environment(\.modelContext) private var modelContext
    @State private var inspectorShown: Bool = false
    @State var imageOutput: ImageOutput
    @State private var selectedAnnotation: CoreMLAnnotation?
    
    
    var body: some View {
        if let image = imageOutput.cgImage {
            HStack {
                Image(image, scale: 1, label: Text("Sonaimg"))
                    .overlay(
                        self.annotationsBody
                    )
                VStack {
                    if !imageOutput.annotations.isEmpty {
                        List(imageOutput.annotations, id: \.self, selection: $selectedAnnotation) { anAnnotation in
                            HStack {
                                Text("\(anAnnotation.annotationLabel)")
                            }
                        }
                        .frame(minHeight: 100, idealHeight: 200, maxHeight: 300)
                    }
                    if self.selectedAnnotation != nil {
                        @Bindable var annon = self.selectedAnnotation!
                        TextField("Label", text: $annon.annotationLabel)
                        let r = selectedAnnotation!.rect
                        Text("x: \(r.origin.x), y: \(r.origin.y), w: \(r.size.width), h: \(r.size.height)")
                            .font(.footnote)
                    }
                }
                .frame(width: 200)
            }
        } else {
            Text("No image")
        }
        Spacer()
            .onAppear() {
                if !self.imageOutput.annotations.isEmpty {
                    self.selectedAnnotation = self.imageOutput.annotations.first
                }
            }
    }
    
    var annotationsBody: some View {
      ZStack { // (alignment: .topLeading) {
        if let newAnnotation = selectedAnnotation {
          Rectangle()
          .frame(width: newAnnotation.width, height: newAnnotation.height)
          .position(newAnnotation.center)
          .foregroundColor(.blue)
          .opacity(0.5)
          .overlay(
            Text("\(newAnnotation.annotationLabel)")
              .lineLimit(1)
              .fixedSize()
              .font(.footnote)
              .foregroundColor(.secondary)
              .background(Color.blue)
              .position(newAnnotation.center)
              .offset(x: newAnnotation.width / 2, y: newAnnotation.height / 2)
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DetailViewImagesFiles: View {
    
    @Environment(\.modelContext) private var modelContext
    @State private var inspectorShown: Bool = false
    @State var imageOutput: ImageFile
    @State private var selectedAnnotation: ImageAnnotation? = nil
    
    
    var body: some View {
        let image = imageOutput.image
            HStack {
                Image(image, scale: 1, label: Text("Sonaimg"))
                    .overlay(
                        self.annotationsBody
                    )
                VStack {
                    if !imageOutput.annotations.isEmpty {
                        List(imageOutput.annotations, id: \.self, selection: $selectedAnnotation) { anAnnotation in
                            HStack {
                                Text("\(anAnnotation.annotationLabel)")
                            }
                        }
                        .frame(minHeight: 100, idealHeight: 200, maxHeight: 300)
                    }
                    /*if self.selectedAnnotation != nil {
                        @Bindable var annon = self.selectedAnnotation!
                        TextField("Label", text: $annon.annotationLabel)
                        let r = selectedAnnotation!.rect
                        Text("x: \(r.origin.x), y: \(r.origin.y), w: \(r.size.width), h: \(r.size.height)")
                            .font(.footnote)
                    }*/
                }
                .frame(width: 200)
            }
        
        Spacer()
            .onAppear() {
                if !self.imageOutput.annotations.isEmpty {
                    self.selectedAnnotation = self.imageOutput.annotations.first
                }
            }
    }
    
    var annotationsBody: some View {
      ZStack { // (alignment: .topLeading) {
        if let newAnnotation = selectedAnnotation {
          Rectangle()
          .frame(width: newAnnotation.width, height: newAnnotation.height)
          .position(newAnnotation.center)
          .foregroundColor(.blue)
          .opacity(0.5)
          .overlay(
            Text("\(newAnnotation.annotationLabel)")
              .lineLimit(1)
              .fixedSize()
              .font(.footnote)
              .foregroundColor(.secondary)
              .background(Color.blue)
              .position(newAnnotation.center)
              .offset(x: newAnnotation.width / 2, y: newAnnotation.height / 2)
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
