import SwiftUI

struct SettingsView: View {
    // State variables for settings
    @State private var isNotificationsEnabled = true
    @State private var selectedThemeIndex = 0
    @State private var username = ""

    let themes = ["Light", "Dark", "System"]

    var body: some View {
        NavigationView {
            Form { // Use Form for standard settings layout
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $isNotificationsEnabled)
                }

                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $selectedThemeIndex) {
                        ForEach(0..<themes.count, id: \.self) { index in
                            Text(themes[index])
                        }
                    }
                }

                Section(header: Text("Account")) {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                    Button("Log Out") {
                        // Action for logging out
                        print("Log Out tapped!")
                    }
                    .foregroundColor(.red) // Make log out button stand out
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
} 