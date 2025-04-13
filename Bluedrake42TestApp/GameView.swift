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

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var velocity: CGVector // Direction and speed (points per second)
    var size: CGFloat
    var opacity: Double
    let creationDate = Date()
    let lifespan: TimeInterval = 0.6 // How long the particle lives (in seconds)
}

// MARK: - Game View
struct GameView: View {
    // MARK: State Variables
    
    // Game State
    @State private var score = 0
    @State private var isGameOver = false
    
    // Objects
    @State private var fallingShapes: [FallingShape] = []
    @State private var particles: [Particle] = []
    
    // Target
    @State private var targetColor: Color = .green
    @State private var targetShapeIndex: Int = 0 // Index in availableShapes
    
    // Timers & Dynamics
    @State private var lastUpdateTime: Date? = nil
    @State private var timeSinceLastSpawn: TimeInterval = 0
    @State private var currentFallSpeed: CGFloat = 3.0 // Dynamic fall speed, starts at base

    // MARK: Game Configuration
    
    let availableShapes: [AnyView] = [AnyView(Circle()), AnyView(Rectangle()), AnyView(Capsule())]
    let availableColors: [Color] = [.red, .blue, .yellow, .purple, .orange, .green]
    
    let spawnRate: TimeInterval = 0.7      // How often new shapes appear (seconds)
    let fallSpeed: CGFloat = 3.0           // Base fall speed (points per update)
    let speedIncreasePerPoint: CGFloat = 0.1 // How much speed increases for every point (relative to base speed)
    let particleCountPerExplosion: Int = 20
    let particleLifespan: TimeInterval = 0.6
    let particleBaseSpeed: ClosedRange<Double> = 50...150 // points per second
    let particleSizeRange: ClosedRange<CGFloat> = 3...8

    // MARK: Body
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                ZStack {
                    // Background
                    LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.7), .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Particles Layer
                    ForEach(particles) { particle in
                        Circle() // Simple particle shape
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .position(particle.position)
                            .opacity(particle.opacity)
                            .blendMode(.screen) // Optional visual effect
                    }

                    // Falling Shapes Layer
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
                    
                    // HUD Layer (Score & Target)
                    VStack {
                        HStack(alignment: .center) {
                            // Score Display
                            VStack(alignment: .center) {
                                Text("SCORE")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(score)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(.leading)
                            
                            Spacer()
                            
                            // Target Display
                            VStack(alignment: .center) {
                                Text("TARGET")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.7))
                                // Show the target shape and color
                                availableShapes[targetShapeIndex]
                                    .foregroundColor(targetColor)
                                    .frame(width: 35, height: 35)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(.trailing)
                        }
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 10)
                        Spacer()
                    }
                    
                    // Game Over Overlay Layer
                    if isGameOver {
                        VStack(spacing: 25) {
                            Text("GAME OVER")
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                            
                            Text("Final Score: \(score)")
                                .font(.system(size: 26, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Button {
                                resetGame(bounds: geometry.size)
                            } label: {
                                Text("Play Again")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .padding(.vertical, 15)
                                    .padding(.horizontal, 35)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                            }
                            .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial) // Apply material first
                        .background(Color.black.opacity(0.6)) // Then color overlay
                        .transition(.opacity.animation(.easeIn))
                    }
                }
                // Update game state on each frame from TimelineView
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
    
    // MARK: - Game Lifecycle
    
    func startGame(bounds: CGSize) {
        // Reset game state
        score = 0
        isGameOver = false
        fallingShapes.removeAll()
        particles.removeAll()
        timeSinceLastSpawn = 0
        lastUpdateTime = nil // Will be set on first gameLoop call
        currentFallSpeed = fallSpeed // Reset speed to base
        
        // Set the initial target
        randomizeTarget()
    }
    
    func resetGame(bounds: CGSize) {
         startGame(bounds: bounds)
    }
    
    func gameOver() {
        isGameOver = true
        lastUpdateTime = nil // Stop game loop updates indirectly
    }

    // MARK: - Game Loop Update
    
    func gameLoop(bounds: CGSize, currentTime: Date) {
        guard let lastTime = lastUpdateTime else {
            // If last time isn't set, initialize it for delta time calculation
            lastUpdateTime = currentTime
            return
        }
        
        let deltaTime = currentTime.timeIntervalSince(lastTime)
        lastUpdateTime = currentTime
        
        // --- Update Dynamics ---
        // Increase speed based on score
        // Formula: Base speed + (score * increase_per_point)
        currentFallSpeed = fallSpeed + (CGFloat(score) * speedIncreasePerPoint)
        
        // --- Spawn Shapes ---
        timeSinceLastSpawn += deltaTime
        if timeSinceLastSpawn >= spawnRate {
            spawnShape(in: bounds)
            timeSinceLastSpawn = 0 // Reset spawn timer
        }
        
        // --- Move Shapes & Check Bounds ---
        var shapesToRemove: [UUID] = []
        for index in fallingShapes.indices {
            // Use currentFallSpeed for movement
            fallingShapes[index].position.y += currentFallSpeed 
            
            // Check if shape is off-screen (bottom edge)
            if fallingShapes[index].position.y > bounds.height + fallingShapes[index].size / 2 {
                // If a target shape was missed, game over
                if fallingShapes[index].isTarget {
                    gameOver()
                    return // Stop processing loop immediately
                }
                // Otherwise, mark non-target shape for removal
                shapesToRemove.append(fallingShapes[index].id)
            }
        }
        // Remove shapes that went off-screen
        fallingShapes.removeAll { shapesToRemove.contains($0.id) }
        
        // --- Update Particles ---
        var particlesToRemove: [UUID] = []
        for index in particles.indices {
            // Move particle based on velocity and deltaTime
            particles[index].position.x += particles[index].velocity.dx * deltaTime
            particles[index].position.y += particles[index].velocity.dy * deltaTime
            
            // Fade out particle over its lifespan
            let age = currentTime.timeIntervalSince(particles[index].creationDate)
            let lifeRemaining = (particleLifespan - age) / particleLifespan
            particles[index].opacity = max(0, lifeRemaining) // Clamp opacity >= 0
            
            // Mark expired particles for removal
            if age >= particleLifespan {
                particlesToRemove.append(particles[index].id)
            }
        }
        // Remove expired particles
        particles.removeAll { particlesToRemove.contains($0.id) }
    }
    
    // MARK: - Player Interaction

    func handleTap(shape: FallingShape, bounds: CGSize) {
        guard !isGameOver else { return }

        if shape.isTarget {
            // Correct tap!
            score += 1
            createExplosion(at: shape.position, color: shape.color)
            fallingShapes.removeAll { $0.id == shape.id }
            randomizeTarget() // Pick a new target immediately
        } else {
            // Wrong tap! Game Over.
            gameOver()
        }
    }

    // MARK: - Object Spawning

    func spawnShape(in bounds: CGSize) {
        let randomShapeIndex = Int.random(in: 0..<availableShapes.count)
        let randomColorIndex = Int.random(in: 0..<availableColors.count)
        let shapeColor = availableColors[randomColorIndex]
        let shapeView = availableShapes[randomShapeIndex]
        
        // Target must match BOTH color and shape index
        let isTargetShape = (shapeColor == targetColor && randomShapeIndex == targetShapeIndex)
        let shapeSize: CGFloat = 50
        
        // Spawn position: Random X, just above the top edge
        let randomX = CGFloat.random(in: (shapeSize / 2)...(bounds.width - shapeSize / 2))
        let startY: CGFloat = -shapeSize
        
        let newShape = FallingShape(
            position: CGPoint(x: randomX, y: startY),
            color: shapeColor,
            shapeType: shapeView,
            isTarget: isTargetShape,
            size: shapeSize
        )
        
        fallingShapes.append(newShape)
    }
    
    // MARK: - Target Randomization
    
    func randomizeTarget() {
        var newColor: Color
        var newIndex: Int
        var existingMatchFound: Bool
        let maxAttempts = 10 // Safety break for the loop
        var attempt = 0

        repeat {
            // Select a potential random color and shape index
            newColor = availableColors.randomElement() ?? .green
            newIndex = Int.random(in: 0..<availableShapes.count)
            
            // Check if any *existing* falling shape matches this new potential target
            existingMatchFound = fallingShapes.contains { shape in
                shape.color == newColor && 
                (availableShapes.firstIndex(where: { $0.typeId == shape.shapeType.typeId }) == newIndex)
            }
            
            attempt += 1
            
        } while existingMatchFound && attempt < maxAttempts // Keep trying if match found, up to max attempts
        
        // Set the new target (either a safe one or the last attempt)
        targetColor = newColor
        targetShapeIndex = newIndex
        
        // Potential improvement: Could add logic here to ensure the new target
        // is different from the previous one to avoid immediate repeats.
    }
    
    // MARK: - Particle Effects
    
    func createExplosion(at position: CGPoint, color: Color) {
        for _ in 0..<particleCountPerExplosion {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: particleBaseSpeed) // Speed in points per second
            let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            let size = CGFloat.random(in: particleSizeRange)
            
            let particle = Particle(
                position: position,
                color: color,
                velocity: velocity,
                size: size,
                opacity: 1.0 // Start fully opaque
            )
            particles.append(particle)
        }
    }
}

// Helper extension to get a stable type identifier for AnyView comparison
// NOTE: This relies on the internal structure of AnyView and might be fragile.
// A more robust solution would involve storing the original Shape type or an enum identifier.
extension AnyView {
    var typeId: ObjectIdentifier {
        // Attempt to reflect the underlying view type
        let mirror = Mirror(reflecting: self)
        if let storage = mirror.children.first(where: { $0.label == "storage" })?.value {
            let storageMirror = Mirror(reflecting: storage)
            if let box = storageMirror.children.first(where: { $0.label == "box" })?.value {
                 return ObjectIdentifier(type(of: box))
            }
        }
        // Fallback if reflection fails (less reliable)
        return ObjectIdentifier(type(of: self))
    }
}

// MARK: - Preview

#Preview {
    GameView()
} 