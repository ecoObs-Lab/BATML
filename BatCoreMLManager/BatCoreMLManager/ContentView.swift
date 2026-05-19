//
//  ContentView.swift
//  BatCoreMLManager
//
//  Created by Volker Runkel on 04.02.26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.documentConfiguration) private var documentConfiguration
    @Environment(\.modelContext) private var modelContext
    
    @State private var showImages: Bool = false
    
    @State private var importPresented: Bool = false
    @State private var folderSecurityBookmark: Data?
    
    @State private var items: [RecordingInput] = Array()
    @State private var selectedRecording: RecordingInput?
    
    @Query(sort: \ImageOutput.name) var images: [ImageOutput]
    @State private var selectedImage: ImageOutput?
    
    @State private var imageFiles: [ImageFile] = Array()
    @State private var selectedImageFile: ImageFile?
    
    @State private var fileURL: URL?

    var body: some View {
        NavigationSplitView {
#if !VIEWER
            Button("Toggle") {
                self.selectedRecording = nil
                self.selectedImage = nil
                showImages.toggle()
            }
            /*
            Button("Load YOLO") {
                loadYOLO()
            }
             */
            
#endif // !VIEWER

            if !showImages {
                Group {
                    if items.isEmpty {
                        ContentUnavailableView {
                            Button() {
                                importPresented.toggle()
                                } label: {
                                Label("Choose folder", systemImage: "folder.badge.plus")
                            }
                            .buttonStyle(.borderless)
                        } description: {
                            Text("After choosing a folder the contents will appear here")
                        }
                    } else {
                        List(items.sorted { $0.fileURL.lastPathComponent < $1.fileURL.lastPathComponent}, id: \.self, selection: $selectedRecording) { recording in
                            Text(recording.fileURL.lastPathComponent)
                            //Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        }
                    }
                }
                    .fileImporter(isPresented: $importPresented, allowedContentTypes: [.directory], onCompletion: { result in
                        switch result {
                        case .success(let url):
                            // gain access to the directory
                            let gotAccess = url.startAccessingSecurityScopedResource()
                            if !gotAccess { return }
                            if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                                self.folderSecurityBookmark = bookmarkData
                            }
                            self.items = self.getFiles(directoryURL: url)
                            self.selectedRecording = nil
                            url.stopAccessingSecurityScopedResource()
                        case .failure(let error):
                            // handle error
                            print(error)
                        }
                    })
                .navigationSplitViewColumnWidth(min: 225, ideal: 300)
                .toolbar {
                    ToolbarItem {
                        Button(action:  { importPresented.toggle() } ) {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                }
            } else {
                /*List(imageFiles, id:\.self, selection: $selectedImageFile) { image in
                    Text("\(image.fileName) - \(image.annotations.count)")
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)*/
                
                Button("Save JSON") {
                    let sp = NSOpenPanel()
                    sp.canCreateDirectories = true
                    sp.canChooseFiles = false
                    sp.canChooseDirectories = true
                    sp.allowedContentTypes = [.folder]
                    if sp.runModal() == .OK, let url = sp.url {
                        
                        for anImage in images {
                            try? anImage.imageData.write(to: url.appendingPathComponent(anImage.name, conformingTo: .jpeg))
                        }
                        
                        guard let data = try? JSONEncoder().encode(images) else {
                            print("Error")
                          return
                        }
                        try! data.write(to: url.appendingPathComponent("annotations", conformingTo: .json))
                    }
                    
                }
                Button("Save YOLO") {
                    let sp = NSOpenPanel()
                    sp.canCreateDirectories = true
                    sp.canChooseFiles = false
                    sp.canChooseDirectories = true
                    sp.allowedContentTypes = [.folder]
                    if sp.runModal() == .OK, let url = sp.url {
                        let categories = (self.images).compactMap { $0.annotations.first?.annotationLabel }
                        let uniqueCategories = Array(Set(categories)).sorted()
                        var classesFile = ""
                        for aClass in uniqueCategories {
                            if aClass == uniqueCategories.last {
                                classesFile.append(aClass)
                            } else {
                                classesFile.append(aClass + "\n")
                            }
                        }
                        try? classesFile.write(to: url.appendingPathComponent("classes.txt"), atomically: true, encoding: .utf8)
                        for (index, anImage) in images.enumerated() {
                            var adjustedURL: URL?
                            if index % 3 == 0 {
                                adjustedURL = url.appendingPathComponent("Valid")
                            } else {
                                adjustedURL = url.appendingPathComponent("Train")
                            }
                            
                            try? anImage.imageData.write(to: adjustedURL!.appendingPathComponent(anImage.name + ".jpg"))
                            var textFile = ""
                            if let anAnnotation = anImage.annotations.first {
                                if let img = anImage.cgImage {
                                    textFile.append("\(uniqueCategories.firstIndex(of: anAnnotation.annotationLabel)!) ")
                                    textFile.append("\(anAnnotation.center.x/CGFloat(img.width)) \(anAnnotation.center.y/CGFloat(img.height)) \(anAnnotation.width/CGFloat(img.width)) \(anAnnotation.height/CGFloat(img.height))")
                                    try? textFile.write(to: adjustedURL!.appendingPathComponent(anImage.name + ".txt", conformingTo: .text), atomically: true, encoding: .utf8)
                                }
                            }
                        }
                        
                    }
                    
                }
                
                List(images, id:\.self, selection: $selectedImage) { image in
                    Text("\(image.name) - \(image.annotations.count)")
                }
                .navigationSplitViewColumnWidth(min: 225, ideal: 300)
                .toolbar {
                    ToolbarItem {
                        Button(action:  {
                            self.modelContext.delete(self.selectedImage!)
                            
                        } ) {
                            Label("Delete Item", systemImage: "minus")
                        }
                    }
                }
            }
        } detail: {
            if !showImages {
                if self.selectedRecording != nil {
                    DetailView(recordingEntry: self.selectedRecording!)
                        .id(selectedRecording?.id ?? nil)
                        .frame(minWidth: 1200)
                        .navigationTitle(self.selectedRecording!.fileURL.lastPathComponent)
                        .navigationSplitViewColumnWidth(min: 1200, ideal: 1200)
                }
            }
            else {
                if self.selectedImage != nil {
                    DetailViewImages(imageOutput: self.selectedImage!)
                        .id(selectedImage?.id ?? nil)
                        .padding()
                } else if self.selectedImageFile != nil {
                    DetailViewImagesFiles(imageOutput: self.selectedImageFile!)
                        .id(selectedImageFile?.id ?? nil)
                        .padding()
                }
            }
        }
    }

    func loadYOLO() {
        self.imageFiles.removeAll()
        var classNames = [String]()
        let op = NSOpenPanel()
        op.allowedContentTypes = [UTType(filenameExtension: "names")!, .folder]
        op.allowsMultipleSelection = true
        op.canChooseDirectories = true
        if op.runModal() == .OK, op.urls.count == 2 {
            
            for anUrl in op.urls {
                if anUrl.pathExtension == "names" {
                    do {
                        let namesFile = try String(contentsOf: anUrl, encoding: .utf8)
                        classNames = namesFile.components(separatedBy: .newlines)
                    }
                    catch {
                        print("Error reading names file")
                        return
                    }
                }
            }
            
            for anUrl in op.urls {
                if let resourceValues = (try? anUrl.resourceValues(forKeys: [.isDirectoryKey])), let isDir = resourceValues.isDirectory, isDir {
                    
                    for aLine in self.getFilesYOLO(directoryURL: anUrl) {
                        
                        if aLine.pathExtension == "txt" {
                            if let lineData = try? String(contentsOf: aLine, encoding: .utf8) {
                                let lineArray = lineData.components(separatedBy: " ")
                                let className = classNames[Int(lineArray[0])!]
                                
                                let xR = Float(lineArray[1])!
                                let yR = Float(lineArray[2])!
                                let wR = Float(lineArray[3])!
                                let hR = Float(lineArray[4])!
                                
                                let imageFilename = aLine.deletingPathExtension().appendingPathExtension("jpg")
                                if let image = NSImage(contentsOf: imageFilename) {
                                    
                                    let imgAnnot = ImageAnnotation(annotationCoordinates: CGRect(x: CGFloat(xR-wR/2) * CGFloat(image.size.width), y: CGFloat(yR-hR/2) * CGFloat(image.size.height), width: CGFloat(wR) * CGFloat(image.size.width), height: CGFloat(hR) * CGFloat(image.size.height)), annotationLabel: className)
                                    
                                    withAnimation {
                                        imageFiles.append(ImageFile(fileName: imageFilename.lastPathComponent, image: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, annotations: [imgAnnot]))
                                    }
                                }
                            }
                        }
                    }
                    
                }
            }
        }
        if !self.imageFiles.isEmpty {
            showImages.toggle()
        }
    }
    
    func getFiles(directoryURL: URL) -> Array<RecordingInput> {
      var files: [RecordingInput] = []
     do {
        let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
         
            let listOfFiles = directoryContents.filter{ ["wav", "raw"].contains($0.pathExtension.lowercased()) }
         
         for aFile in listOfFiles {
             var newItem = RecordingInput(timestamp: Date(), fileURL: aFile)
             newItem.secBookmark = try? aFile.bookmarkData(
                 options: .withSecurityScope,
                 includingResourceValuesForKeys: nil,
                 relativeTo: nil
             )
             files.append(newItem)
         }
         
     } catch {
         print(error)
     }
     return files
    }
    
    func getFilesYOLO(directoryURL: URL) -> Array<URL> {
      var files: [URL] = []
     do {
        let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
         
            let listOfFiles = directoryContents.filter{ ["jpg", "txt"].contains($0.pathExtension.lowercased()) }
         
         for aFile in listOfFiles {
             files.append(aFile)
         }
         
     } catch {
         print(error)
     }
     return files
    }
    
    private func addItem() {
        let op = NSOpenPanel()
        op.allowedContentTypes = [.wav, UTType(filenameExtension: "raw")!]
        op.allowsMultipleSelection = true
        if op.runModal() == .OK, let urls = op.urls.map(\.standardizedFileURL) as? [URL] {
            withAnimation {
                for anUrl in urls {
                    var newItem = RecordingInput(timestamp: Date(), fileURL: anUrl)
                    newItem.secBookmark = try? anUrl.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    self.items.append(newItem)
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                //modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ImageOutput.self, inMemory: true)
}
