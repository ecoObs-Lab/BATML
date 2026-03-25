//
//  ContentView.swift
//  BATMLTool
//
//  Created by Volker Runkel on 12.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    
    @State private var items: [RecordingInput] = Array()
    @State private var selectedRecording: RecordingInput?
    
    @State private var importPresented: Bool = false
        @State private var folderSecurityBookmark: Data?
    
    var body: some View {
        NavigationSplitView {
            Group {
                List(selection: $selectedRecording) {
                    OutlineGroup($items, id: \.self, children: \.sortedRecordings) { $urlitem in
                        let urlitem = $urlitem.wrappedValue
                        if urlitem.isFolder {
                            Label(urlitem.fileURL.lastPathComponent, systemImage: "folder")
                        } else {
                            Label(urlitem.fileURL.lastPathComponent, systemImage: "waveform")
                        }
                    }
                }
                .overlay {
                    if items.isEmpty {
                        ContentUnavailableView {
                            Button() {
                                chooseFolder()
                            } label: {
                                Label("Choose folder", systemImage: "folder.badge.plus")
                            }
                            .buttonStyle(.borderless)
                        } description: {
                            Text("After choosing a folder the contents will appear here")
                        }
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
                        self.selectedRecording = nil
                        addFolders(url: url)
                        url.stopAccessingSecurityScopedResource()
                    case .failure(let error):
                        // handle error
                        print(error)
                    }
                })
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action:  { importPresented.toggle() } ) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }

        } detail: {
                if self.selectedRecording != nil {
                    DetailView(recordingEntry: self.selectedRecording!)
                        .id(selectedRecording?.id ?? nil)
                        .navigationTitle(self.selectedRecording!.fileURL.lastPathComponent)
                } else {
                    ContentUnavailableView {
                        Text("Select a sound file")
                    } description: {
                        Text("After selecting a sound file an overview sonagram will appear here")
                    }
                }
        }

    }
    
    private func chooseFolder() {
        items.removeAll(keepingCapacity: true)
        let op = NSOpenPanel()
        op.canChooseFiles = false
        op.canChooseDirectories = true
        if op.runModal() == .OK, let url = op.url {
            addFolders(url: url)
        }
    }
    
    private func addFolders(url: URL) {
        let fm = FileManager.default
        do {
            let urls = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for anUrl in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent}) {
                if anUrl.pathExtension == "raw" || anUrl.pathExtension == "wav" {
                    let newURLItem = RecordingInput(fileURL: anUrl, isFolder: false)
                    newURLItem.secBookmark = try? anUrl.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    items.append(newURLItem)
                }
                else if anUrl.hasDirectoryPath {
                    var newURLItem = RecordingInput(fileURL: anUrl, isFolder: true)
                    newURLItem.secBookmark = try? anUrl.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    items.append(newURLItem)
                    recursiveFolderCrawl(folderItem: &newURLItem)
                }
            }
        }
        catch {
            print(error)
        }
        
    }
    
    private func recursiveFolderCrawl(folderItem: inout RecordingInput) {
        let fm = FileManager.default
        do {
            let urls = try fm.contentsOfDirectory(at: folderItem.fileURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for anUrl in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent}) {
                if anUrl.pathExtension == "raw" || anUrl.pathExtension == "wav" {
                        let newURLItem = RecordingInput(fileURL: anUrl, isFolder: false)
                        newURLItem.secBookmark = try? anUrl.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        if folderItem.recordings == nil {
                            folderItem.recordings = Array()
                        }
                        folderItem.recordings!.append(newURLItem)
                }
                else if anUrl.hasDirectoryPath {
                    if folderItem.recordings == nil {
                        folderItem.recordings = Array()
                    }
                    var newURLItem = RecordingInput(fileURL: anUrl, isFolder: true)
                    newURLItem.secBookmark = try? anUrl.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    folderItem.recordings!.append(newURLItem)
                    recursiveFolderCrawl(folderItem: &newURLItem)
                }
            }
        }
        catch {
            print(error)
        }
    }
    
    private func enumerateFolderTree(url: URL) {
        if let folderEnum = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
            var lastFolder: RecordingInput?
            while let suburl = folderEnum.nextObject() {
                if let suburl = suburl as? URL {
                    if !suburl.hasDirectoryPath {
                        if suburl.pathExtension == "raw" || suburl.pathExtension == "wav" {
                            
                            var newURLItem = RecordingInput(fileURL: suburl, isFolder: false)
                            newURLItem.secBookmark = try? suburl.bookmarkData(
                                options: .withSecurityScope,
                                includingResourceValuesForKeys: nil,
                                relativeTo: nil
                            )
                            if lastFolder != nil {
                                if lastFolder!.recordings == nil {
                                    lastFolder!.recordings = Array()
                                }
                                lastFolder!.recordings!.append(newURLItem)
                            }
                            else {
                                items.append(newURLItem)
                            }
                        }
                    } else {
                        if lastFolder == nil {
                            lastFolder = RecordingInput(fileURL: suburl, isFolder: true)
                        } else {
                            items.append(lastFolder!)
                            lastFolder = RecordingInput(fileURL: suburl, isFolder: true)
                        }
                    }
                }
            }
            if lastFolder != nil {
                items.append(lastFolder!)
            }
        }
    }
    
}

#Preview {
    ContentView()
}
