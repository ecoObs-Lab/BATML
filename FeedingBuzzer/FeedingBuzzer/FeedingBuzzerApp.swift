//
//  FeedingBuzzerApp.swift
//  FeedingBuzzer
//
//  Created by Volker Runkel on 27.03.26.
//

import SwiftUI

@main
struct FeedingBuzzerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1024, minHeight: 900)
        }
        .defaultSize(CGSize(width: 1280, height: 900))
        WindowGroup(for: URL.self) {$anURL in
                    SonaView(soundURL: anURL!)
                }
        .defaultSize(CGSize(width: 1024, height: 600))
    }
}
