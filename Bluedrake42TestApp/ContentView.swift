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
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "figure.walk")
                }

            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "flame.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        // Add a subtle accent color for visual appeal
        .accentColor(.green)
    }
}

#Preview {
    ContentView()
}
