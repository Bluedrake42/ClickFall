import SwiftUI

// MARK: - Data Structures
struct FallingShape: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let shapeType: AnyView // Can be Circle, Rectangle, etc.
    let isTarget: Bool
    var size: CGFloat = 50 // Size of the shape
}

// MARK: - Game View
struct GameView: View {
    // State for game variables
    @State private var score = 0
    // @State private var targetPosition = CGPoint(x: 100, y: 100) // No longer needed
    // @State private var targetSize: CGFloat = 60 // Size is now in FallingShape
    @State private var isGameOver = false
    // @State private var timer: Timer? // Will use a different timer structure
    // @State private var timeRemaining = 10 // No time limit for now
    
    @State private var fallingShapes: [FallingShape] = [] // Array to hold active shapes
    @State private var gameTimer: Timer? // Timer for game updates (falling, spawning)
    
    // Game Configuration
    @State private var targetColor: Color = .green
    @State private var targetShapeIndex: Int = 0 // Store the index of the target shape
    let spawnRate: TimeInterval = 0.7 // How often new shapes appear
    let fallSpeed: CGFloat = 3.0 // How fast shapes fall
    
    // Shape options (keeping these)
    let availableShapes = [AnyView(Circle()), AnyView(Rectangle()), AnyView(Capsule())]
    let availableColors: [Color] = [.red, .blue, .yellow, .purple, .orange, .green] // Include target color
    // @State private var currentShapeIndex = 0 // No longer needed

    // Timing related state for TimelineView
    @State private var lastUpdateTime: Date? = nil
    @State private var timeSinceLastSpawn: TimeInterval = 0

    var body: some View {
        GeometryReader { geometry in
            // Use TimelineView for animation updates
            TimelineView(.animation) { timeline in
                ZStack {
                    // Background (same as before)
                    LinearGradient(gradient: Gradient(colors: [.cyan, .indigo]), startPoint: .top, endPoint: .bottom)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Display Falling Shapes
                    ForEach(fallingShapes) { shape in
                        shape.shapeType
                            .foregroundColor(shape.color)
                            .frame(width: shape.size, height: shape.size)
                            .position(shape.position)
                            .onTapGesture {
                                if !isGameOver {
                                     handleTap(shape: shape, bounds: geometry.size)
                                }
                            }
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 3)
                    }
                    
                    // Score Display (Top Left)
                    VStack {
                        HStack {
                            Text("Score: \(score)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                            Spacer()
                            // Dynamically display target shape and color
                            HStack {
                                Text("Tap:")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                // Show the target shape and color
                                availableShapes[targetShapeIndex] 
                                    .foregroundColor(targetColor)
                                    .frame(width: 25, height: 25)
                                    .shadow(radius: 1)
                            }
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                            .padding(.trailing)
                        }
                        Spacer()
                    }
                    
                    // Game Over Overlay (same structure as before)
                    if isGameOver {
                        VStack {
                            Text("Game Over!")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Final Score: \(score)")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(.bottom)
                            Button("Play Again") {
                                resetGame(bounds: geometry.size)
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.7))
                    }
                }
                // Game loop logic triggered by timeline update
                .onChange(of: timeline.date) { oldValue, newValue in
                     guard !isGameOver else { return } // Stop updates if game over
                     gameLoop(bounds: geometry.size, currentTime: newValue)
                }
            }
            .onAppear {
                 startGame(bounds: geometry.size)
            }
        }
    }

    // MARK: - Game Lifecycle & Loop
    
    func startGame(bounds: CGSize) {
        score = 0
        isGameOver = false
        fallingShapes.removeAll()
        timeSinceLastSpawn = 0
        lastUpdateTime = Date()
        
        // Randomize the target color and shape index for the new game
        targetColor = availableColors.randomElement() ?? .green
        targetShapeIndex = Int.random(in: 0..<availableShapes.count)
        
        // Spawn initial shape maybe?
        // spawnShape(in: bounds)
    }
    
    func gameLoop(bounds: CGSize, currentTime: Date) {
        guard let lastTime = lastUpdateTime else {
            lastUpdateTime = currentTime // Initial setup
            return
        }
        
        let deltaTime = currentTime.timeIntervalSince(lastTime)
        lastUpdateTime = currentTime
        
        // --- Spawn Shapes ---
        timeSinceLastSpawn += deltaTime
        if timeSinceLastSpawn >= spawnRate {
            spawnShape(in: bounds)
            timeSinceLastSpawn = 0 // Reset spawn timer
        }
        
        // --- Move Shapes & Check Bounds ---
        var shapesToRemove: [UUID] = []
        for index in fallingShapes.indices {
            fallingShapes[index].position.y += fallSpeed // Simple linear fall for now
            
            // Check if shape is off-screen
            if fallingShapes[index].position.y > bounds.height + fallingShapes[index].size / 2 {
                // If a target shape was missed, game over
                if fallingShapes[index].isTarget {
                    gameOver()
                    return // Stop processing immediately
                }
                shapesToRemove.append(fallingShapes[index].id)
            }
        }
        
        // Remove shapes that went off-screen
        fallingShapes.removeAll { shapesToRemove.contains($0.id) }
    }
    
    func gameOver() {
        isGameOver = true
        lastUpdateTime = nil // Stop updates indirectly
    }

    // MARK: - Shape Handling

    // Function to handle tap on a shape
    func handleTap(shape: FallingShape, bounds: CGSize) {
        guard !isGameOver else { return }

        if shape.isTarget {
            // Correct tap!
            score += 1
            // "Explode" - remove the shape
            fallingShapes.removeAll { $0.id == shape.id }
            // TODO: Add explosion particle effect here later
        } else {
            // Wrong tap!
            gameOver()
        }
    }

    // Function to spawn a new shape
    func spawnShape(in bounds: CGSize) {
        let randomShapeIndex = Int.random(in: 0..<availableShapes.count)
        let randomColorIndex = Int.random(in: 0..<availableColors.count)
        let shapeColor = availableColors[randomColorIndex]
        let shapeView = availableShapes[randomShapeIndex]
        // Target must match BOTH color and shape index
        let isTargetShape = (shapeColor == targetColor && randomShapeIndex == targetShapeIndex)
        let shapeSize: CGFloat = 50
        
        // Random horizontal position, start above the screen
        let randomX = CGFloat.random(in: (shapeSize / 2)...(bounds.width - shapeSize / 2))
        let startY: CGFloat = -shapeSize // Start just above the visible area
        
        let newShape = FallingShape(
            position: CGPoint(x: randomX, y: startY),
            color: shapeColor,
            shapeType: shapeView,
            isTarget: isTargetShape,
            size: shapeSize
        )
        
        fallingShapes.append(newShape)
    }

    // Function to reset the game - now accepts bounds
    func resetGame(bounds: CGSize) {
         startGame(bounds: bounds)
    }
}

#Preview {
    GameView()
} 