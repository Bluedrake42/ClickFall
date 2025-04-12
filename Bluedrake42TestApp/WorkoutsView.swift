import SwiftUI

// Data structure for workouts
struct Workout: Identifiable {
    let id = UUID()
    let type: String // e.g., "Running", "Cycling", "Weightlifting"
    let date: Date
    let duration: TimeInterval // in seconds
    let caloriesBurned: Int
    let iconName: String
}

// Sample workout data
let sampleWorkoutData = [
    Workout(type: "Running", date: Date().addingTimeInterval(-86400 * 2), duration: 1800, caloriesBurned: 300, iconName: "figure.run"),
    Workout(type: "Weightlifting", date: Date().addingTimeInterval(-86400), duration: 3600, caloriesBurned: 450, iconName: "figure.strengthtraining.traditional"),
    Workout(type: "Cycling", date: Date(), duration: 2700, caloriesBurned: 400, iconName: "figure.outdoor.cycle"),
]

struct WorkoutsView: View {
    @State private var workouts = sampleWorkoutData

    var body: some View {
        NavigationView {
            List {
                ForEach(workouts) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        WorkoutRow(workout: workout)
                    }
                }
                .onDelete(perform: deleteWorkouts)
            }
            .navigationTitle("Workout History")
            .toolbar {
                // Maybe add a button to start a new workout
                Button { 
                    print("Add workout tapped")
                    // Add action to navigate to a workout logging screen
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        workouts.remove(atOffsets: offsets)
    }
}

// Row view for displaying a single workout in the list
struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack {
            Image(systemName: workout.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundColor(.green)
                .padding(.trailing, 10)

            VStack(alignment: .leading) {
                Text(workout.type)
                    .font(.headline)
                Text(workout.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(formattedDuration(workout.duration))")
                    .font(.subheadline)
                Text("\(workout.caloriesBurned) kcal")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 5)
    }
    
    // Helper to format duration
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

// Detail view for a specific workout
struct WorkoutDetailView: View {
    let workout: Workout
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                     Image(systemName: workout.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.green)
                    Text(workout.type)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Text(workout.date, style: .date)
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Divider()
                
                HStack {
                    DetailItem(label: "Duration", value: formattedDuration(workout.duration), unit: "")
                    Spacer()
                     DetailItem(label: "Calories Burned", value: "\(workout.caloriesBurned)", unit: "kcal")
                }
                .padding(.vertical)
                
                // Add more details here if needed (e.g., distance, heart rate graph, map)
                Text("Workout Notes:")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Placeholder for workout notes or summary.")
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Helper to format duration (duplicate, consider moving to a helper file)
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second] // More precise for detail view
        formatter.unitsStyle = .full
        return formatter.string(from: duration) ?? ""
    }
}

// Reusable view for displaying detail items
struct DetailItem: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.footnote)
                     .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    WorkoutsView()
} 