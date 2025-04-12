import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Add a nice header image
                Image(systemName: "swift")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .foregroundColor(.blue)
                    .padding(.top, 30)

                Text("Welcome to Your App!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("This is a sample home screen.")
                    .font(.title2)
                    .foregroundColor(.gray)

                // Example Button
                Button("Learn More") {
                    // Action for the button
                    print("Learn More tapped!")
                }
                .buttonStyle(.borderedProminent) // Modern button style
                .padding()

                Spacer() // Pushes content to the top
            }
            .padding(.horizontal) // Add horizontal padding
            .navigationTitle("Home") // Set the navigation bar title
            .navigationBarTitleDisplayMode(.inline) // Make title smaller
        }
    }
}

#Preview {
    HomeView()
} 