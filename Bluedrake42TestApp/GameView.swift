import SwiftUI

// MARK: - Data Structures

// NEW: Define Shape Types
enum ShapeType: CaseIterable, Identifiable {
    case circle, rectangle, triangle, star // Removed Capsule

    var id: Self { self }

    // Helper to get a SwiftUI Shape View
    @ViewBuilder
    var view: some View {
        switch self {
        case .circle: Circle()
        case .rectangle: Rectangle()
        case .triangle: Triangle() // Assume Triangle shape exists
        case .star: Star(corners: 5, smoothness: 0.45) // Assume Star shape exists
        }
    }
}

// Shape Definitions (Triangle & Star) - Add these if they don't exist
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Star: Shape {
    let corners: Int
    let smoothness: CGFloat // 0 = pointy, 1 = almost circular

    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }

        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * smoothness

        let angleAdjustment = .pi / 2.0 // Start from top
        let angleIncrement = .pi * 2 / Double(corners)

        var path = Path()

        for i in 0..<corners * 2 {
            let radius = (i % 2 == 0) ? outerRadius : innerRadius
            let angle = Double(i) * angleIncrement / 2.0 - angleAdjustment

            let point = CGPoint(
                x: center.x + cos(CGFloat(angle)) * radius,
                y: center.y + sin(CGFloat(angle)) * radius
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct FallingShape: Identifiable {
    let id = UUID()
    var position: CGPoint
    let shapeType: ShapeType // Use the enum
    let color: Color // ADDED BACK: Color for normal mode
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
    @State private var showingSettings = false // State to control settings sheet
    @State private var isColorblindModeEnabled = false // State for the toggle
    @State private var latestBounds: CGSize = .zero // Store latest bounds for reset
    
    // Objects
    @State private var fallingShapes: [FallingShape] = []
    @State private var particles: [Particle] = []
    
    // Target - Now depends on mode
    @State private var targetShape: ShapeType = .circle
    @State private var targetColor: Color = .green // Restore target color
    
    // Timers & Dynamics
    @State private var lastUpdateTime: Date? = nil
    @State private var timeSinceLastSpawn: TimeInterval = 0
    @State private var currentFallSpeed: CGFloat = 3.0 // Dynamic fall speed, starts at base

    // MARK: Game Configuration
    
    // Restore available colors
    let availableColors: [Color] = [.red, .blue, .yellow, .purple, .orange, .green, .pink, .cyan] // Added more colors

    let spawnRate: TimeInterval = 0.7      // How often new shapes appear (seconds)
    let fallSpeed: CGFloat = 180.0          // Base fall speed (points per second)
    let speedIncreasePerPoint: CGFloat = 6.0 // How much speed increases per point (points per second)
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

                    // Falling Shapes Layer - CONDITIONAL COLOR
                    ForEach(fallingShapes) { shape in
                        shape.shapeType.view // Use the enum's view property
                            .foregroundColor(isColorblindModeEnabled ? .white : shape.color) // Conditional color
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
                        HStack(alignment: .center) { // Revert to original alignment
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
                            
                            Spacer() // Pushes Score left and Target right

                            // Target Display (Back to original position)
                            VStack(alignment: .center) {
                                Text("TARGET")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.7))
                                targetShape.view
                                    .foregroundColor(isColorblindModeEnabled ? .white : targetColor)
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
                     // Store the latest bounds
                     latestBounds = geometry.size
                     guard !isGameOver else { return } // Stop updates if game over
                     gameLoop(bounds: geometry.size, currentTime: newValue)
                }
                // ADDED: Watch for changes in the colorblind toggle
                .onChange(of: isColorblindModeEnabled) { _, _ in
                     print("DEBUG: Colorblind mode changed. Resetting game.")
                     resetGame(bounds: latestBounds)
                }
            }
            .onAppear {
                 startGame(bounds: geometry.size)
            }
            // ADDED: Settings Sheet Modifier
            .sheet(isPresented: $showingSettings) {
                SettingsSheetView(isColorblindModeEnabled: $isColorblindModeEnabled)
            }
            // ADDED: Place Settings button using safeAreaInset
            .safeAreaInset(edge: .top, alignment: .trailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.trailing) // Add padding from the edge
            }
        }
    }
    
    // MARK: - Game Lifecycle
    
    func startGame(bounds: CGSize) {
        print("--- GAME START ---")
        // Reset game state
        score = 0
        isGameOver = false
        fallingShapes.removeAll()
        particles.removeAll()
        timeSinceLastSpawn = 0
        lastUpdateTime = nil // Will be set on first gameLoop call
        currentFallSpeed = fallSpeed // Reset speed to base
        
        // Set the initial target (depends on mode, handled by randomizeTarget)
        randomizeTarget()
    }
    
    func resetGame(bounds: CGSize) {
         print("--- GAME RESET ---")
         startGame(bounds: bounds)
    }
    
    func gameOver() {
        print("--- GAME OVER --- Final Score: \(score)")
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
        let oldSpeed = currentFallSpeed
        currentFallSpeed = fallSpeed + (CGFloat(score) * speedIncreasePerPoint)
        if oldSpeed != currentFallSpeed {
            print("DEBUG: Speed updated to \(String(format: "%.2f", currentFallSpeed))")
        }
        
        // --- Spawn Shapes ---
        timeSinceLastSpawn += deltaTime
        if timeSinceLastSpawn >= spawnRate {
            spawnShape(in: bounds)
            timeSinceLastSpawn = 0 // Reset spawn timer
        }
        
        // --- Move Shapes & Check Bounds --- CONDITIONAL TARGET CHECK
        var shapesToRemove: [UUID] = []
        for index in fallingShapes.indices {
            // Use currentFallSpeed for movement - NOW TIME-BASED
            fallingShapes[index].position.y += currentFallSpeed * CGFloat(deltaTime)
            
            // Check if shape is off-screen (bottom edge)
            if fallingShapes[index].position.y > bounds.height + fallingShapes[index].size / 2 {
                // If a target shape was missed, game over - CHECK TYPE and maybe COLOR
                var missedTarget = false
                if isColorblindModeEnabled {
                    missedTarget = fallingShapes[index].isTarget && fallingShapes[index].shapeType == targetShape
                } else {
                    missedTarget = fallingShapes[index].isTarget && fallingShapes[index].shapeType == targetShape && fallingShapes[index].color == targetColor
                }

                if missedTarget {
                     print("DEBUG: Missed target shape \(fallingShapes[index].shapeType)")
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
            particles[index].position.x += particles[index].velocity.dx * CGFloat(deltaTime) // Ensure CGFloat cast
            particles[index].position.y += particles[index].velocity.dy * CGFloat(deltaTime) // Ensure CGFloat cast
            
            // Update opacity based on lifespan
            let timeAlive = Date().timeIntervalSince(particles[index].creationDate)
            let lifeFraction = timeAlive / particles[index].lifespan
            particles[index].opacity = max(0, 1.0 - lifeFraction) // Fade out
            
            // Mark particle for removal if lifespan exceeded
            if timeAlive > particles[index].lifespan {
                particlesToRemove.append(particles[index].id)
            }
        }
        // Remove expired particles
        particles.removeAll { particlesToRemove.contains($0.id) }
    }
    
    // MARK: - Player Interaction - CONDITIONAL TAP LOGIC

    func handleTap(shape: FallingShape, bounds: CGSize) {
        guard !isGameOver else { return }
        print("DEBUG: Tapped shape: \(shape.shapeType), Color: \(shape.color), isTarget: \(shape.isTarget)")

        var correctTap = false
        if isColorblindModeEnabled {
            correctTap = (shape.shapeType == targetShape)
        } else {
            correctTap = (shape.shapeType == targetShape && shape.color == targetColor)
        }

        if correctTap {
            // Correct tap!
            score += 1
            print("DEBUG: Correct tap! Score: \(score)")
            // Use yellow for explosion in colorblind, shape color otherwise
            createExplosion(at: shape.position, color: isColorblindModeEnabled ? .yellow : shape.color, bounds: bounds)
            fallingShapes.removeAll { $0.id == shape.id }
            randomizeTarget() // Pick a new target immediately
        } else {
            // Wrong tap! Game Over.
            print("DEBUG: Incorrect tap!")
            gameOver()
        }
    }

    // MARK: - Object Spawning - CONDITIONAL COLOR/TARGET

    func spawnShape(in bounds: CGSize) {
        // Choose a random shape type
        guard let randomShapeType = ShapeType.allCases.randomElement() else { return }

        // Choose a random color (only used if not in colorblind mode)
        let randomColor = availableColors.randomElement() ?? .white // Default to white if fails

        // Determine if this shape is the target based on the mode
        var isTargetShape = false
        if isColorblindModeEnabled {
            isTargetShape = (randomShapeType == targetShape)
        } else {
            isTargetShape = (randomShapeType == targetShape && randomColor == targetColor)
        }

        let padding: CGFloat = 30 // Define padding
        // Correctly use bounds.width for range calculation
        let startX = CGFloat.random(in: padding...(bounds.width - padding))
        let startY: CGFloat = -50 // Start above the screen

        let newShape = FallingShape(
            position: CGPoint(x: startX, y: startY),
            shapeType: randomShapeType,
            color: randomColor, // Assign color even in CB mode, just won't be used for rendering/logic
            isTarget: isTargetShape
        )
        
        print("DEBUG: Spawned \(randomShapeType) - Color: \(randomColor) - IsTarget: \(isTargetShape)")
        fallingShapes.append(newShape)
    }
    
    // MARK: - Target Randomization - CONDITIONAL
    
    func randomizeTarget() {
        if isColorblindModeEnabled {
            // --- Colorblind Mode: Randomize Shape Only ---
            var potentialNewTargets = ShapeType.allCases.filter { $0 != targetShape }
            if potentialNewTargets.isEmpty {
                potentialNewTargets = ShapeType.allCases
            }
            targetShape = potentialNewTargets.randomElement() ?? .circle
            // No need to set targetColor
            print("DEBUG: New Target (CB Mode): \(targetShape)")

        } else {
            // --- Normal Mode: Randomize Shape and Color ---
            var potentialNewShape: ShapeType
            var potentialNewColor: Color
            var attempt = 0
            let maxAttempts = 20 // Prevent infinite loops if very few shapes/colors exist

            repeat {
                potentialNewShape = ShapeType.allCases.randomElement() ?? .circle
                potentialNewColor = availableColors.randomElement() ?? .green
                attempt += 1
            } while (potentialNewShape == targetShape && potentialNewColor == targetColor) && attempt < maxAttempts

            targetShape = potentialNewShape
            targetColor = potentialNewColor
            print("DEBUG: New Target (Normal Mode): \(targetShape) - Color: \(targetColor)")
        }

        // Optional: Clear existing shapes that might match the new target immediately?
        // fallingShapes.removeAll { $0.isTarget } // Simplistic approach, might feel abrupt.
    }
    
    // MARK: - Particle Effects
    
    func createExplosion(at position: CGPoint, color: Color, bounds: CGSize) {
        // Use the provided color for particles
        let explosionColor = color
        for _ in 0..<particleCountPerExplosion {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = Double.random(in: particleBaseSpeed)
            let velocity = CGVector(dx: cos(angle) * CGFloat(speed), dy: sin(angle) * CGFloat(speed))
            let size = CGFloat.random(in: particleSizeRange)

            let particle = Particle(
                position: position,
                color: explosionColor, // Use the explosion color
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

// ADDED: Simple View for the Settings Sheet
struct SettingsSheetView: View {
    @Binding var isColorblindModeEnabled: Bool
    @Environment(\.dismiss) var dismiss // To close the sheet

    var body: some View {
        NavigationView { // Add NavigationView for title and dismiss button
            Form {
                Toggle("Colorblind Mode (Shapes Only)", isOn: $isColorblindModeEnabled)
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss() // Close the sheet
            })
        }
    }
} 