import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationView {
            ScrollView { // Use ScrollView for potentially longer content
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    Text("Good Morning!") // Dynamic greeting would be better
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom)

                    // Activity Summary Card
                    VStack(alignment: .leading) {
                        Text("Activity Summary")
                            .font(.title2)
                            .fontWeight(.semibold)
                        HStack {
                            ActivityRingView(progress: 0.7, color: .green, symbol: "figure.walk")
                            ActivityRingView(progress: 0.4, color: .orange, symbol: "flame.fill")
                            ActivityRingView(progress: 0.9, color: .blue, symbol: "stopwatch.fill")
                        }
                        .padding(.top, 5)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    // Quick Actions
                    VStack(alignment: .leading) {
                        Text("Quick Actions")
                            .font(.title2)
                            .fontWeight(.semibold)
                        HStack(spacing: 15) {
                            QuickActionButton(title: "Start Walk", icon: "figure.walk", color: .green)
                            QuickActionButton(title: "Start Run", icon: "figure.run", color: .orange)
                        }
                        .padding(.top, 5)
                    }
                    .padding(.top)
                    
                    // Placeholder for recent workouts or challenges
                    VStack(alignment: .leading) {
                         Text("Recent Workouts")
                            .font(.title2)
                            .fontWeight(.semibold)
                         Text("You haven't logged any workouts yet.")
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.top)


                    Spacer() // Pushes content to the top if ScrollView content is short
                }
                .padding() // Add padding around the VStack content
            }
            .navigationTitle("Dashboard")
        }
    }
}

// Simple Activity Ring View (Placeholder)
struct ActivityRingView: View {
    let progress: CGFloat
    let color: Color
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 10)
                .opacity(0.3)
                .foregroundColor(color)

            Circle()
                .trim(from: 0.0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
            
            Image(systemName: symbol)
                .font(.title2)
                .foregroundColor(color)
        }
        .frame(width: 80, height: 80)
        .padding(5)
    }
}

// Quick Action Button Style
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Button(action: { print("\(title) tapped!") }) {
            VStack {
                Image(systemName: icon)
                    .font(.title)
                    .frame(height: 30)
                Text(title)
                    .font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(10)
        }
    }
}


#Preview {
    DashboardView()
} 