//
//  ContentView.swift
//  Bluedrake42TestApp
//
//  Created by Connor Hill on 4/12/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        // Add a subtle accent color for visual appeal
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
}
