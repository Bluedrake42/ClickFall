import SwiftUI

struct ProfileView: View {
    // Sample profile data and settings (replace with actual user data model)
    @State private var userName = "Jane Doe"
    @State private var userGoal = "Run 5k"
    @State private var height = 170.0 // cm
    @State private var weight = 65.0 // kg
    @State private var preferredUnits = "Metric"
    @State private var weeklyGoal = 5 // workouts per week
    @State private var enableReminders = true
    
    let unitOptions = ["Metric", "Imperial"]
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Section
                Section(header: Text("Profile Information")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                        VStack(alignment: .leading) {
                            TextField("Name", text: $userName)
                                .font(.title2)
                            Text("Goal: \($userGoal)") // Simplified goal display
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    // Use Steppers or TextFields for editable stats
                    Stepper("Height: \(Int(height)) cm", value: $height, in: 100...250)
                    Stepper("Weight: \(weight, specifier: "%.1f") kg", value: $weight, in: 30...200, step: 0.5)
                }
                
                // Goals Section
                Section(header: Text("Fitness Goals")) {
                     Stepper("Weekly Workouts: \(weeklyGoal)", value: $weeklyGoal, in: 1...14)
                     // Could add fields for specific distance/time goals etc.
                }
                
                // Settings Section
                Section(header: Text("App Settings")) {
                    Picker("Units", selection: $preferredUnits) {
                        ForEach(unitOptions, id: \.self) {
                            Text($0)
                        }
                    }
                    Toggle("Workout Reminders", isOn: $enableReminders)
                }
                
                 // Account Actions
                 Section {
                    Button("Log Out") {
                        print("Log Out tapped!")
                        // Add actual logout logic
                    }
                    .foregroundColor(.red)
                 }
            }
            .navigationTitle("Profile & Settings")
        }
    }
}

#Preview {
    ProfileView()
} 