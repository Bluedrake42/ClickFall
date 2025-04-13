import SpriteKit
import GameplayKit // Useful for randomization, state machines, etc.

// Helper function to create a simple starfield
func createStarfield(frame: CGRect) -> SKNode {
    let starfieldNode = SKNode()
    let starCount = 100
    let starSize = CGSize(width: 1, height: 1)

    for _ in 0..<starCount {
        let star = SKShapeNode(rectOf: starSize)
        star.fillColor = .white
        star.strokeColor = .clear
        let xPos = CGFloat.random(in: frame.minX...frame.maxX)
        let yPos = CGFloat.random(in: frame.minY...frame.maxY)
        star.position = CGPoint(x: xPos, y: yPos)
        star.alpha = CGFloat.random(in: 0.1...0.7) // Vary brightness
        starfieldNode.addChild(star)
    }
    return starfieldNode
}

// Helper function for Screen Shake Action
func screenShakeAction(duration: TimeInterval, amplitude: CGFloat) -> SKAction {
    let shakeAmount = amplitude
    let numberOfShakes = Int(duration / 0.015) // Adjust frequency here
    var actions: [SKAction] = []

    for _ in 0..<numberOfShakes {
        let dx = CGFloat.random(in: -shakeAmount...shakeAmount)
        let dy = CGFloat.random(in: -shakeAmount...shakeAmount)
        actions.append(SKAction.moveBy(x: dx, y: dy, duration: 0.015))
    }
    // Move back to origin
    actions.append(SKAction.move(to: CGPoint.zero, duration: 0.015))
    return SKAction.sequence(actions)
}

// Particle Emitter Factory Functions
func createExplosionEmitter(position: CGPoint) -> SKEmitterNode {
    let emitter = SKEmitterNode()
    emitter.position = position
    emitter.particleTexture = SKTexture(imageNamed: "spark") // Needs a 'spark.png' or similar in Assets
    emitter.particleBirthRate = 400
    emitter.numParticlesToEmit = 100
    emitter.particleLifetime = 0.5
    emitter.particleLifetimeRange = 0.3
    emitter.particlePositionRange = CGVector(dx: 5, dy: 5)
    emitter.particleSpeed = 150
    emitter.particleSpeedRange = 50
    emitter.emissionAngle = 0
    emitter.emissionAngleRange = .pi * 2
    emitter.particleAlpha = 0.8
    emitter.particleAlphaRange = 0.2
    emitter.particleAlphaSpeed = -1.5
    emitter.particleScale = 0.3
    emitter.particleScaleRange = 0.1
    emitter.particleScaleSpeed = -0.5
    emitter.particleColor = .orange
    emitter.particleColorBlendFactor = 1.0
    emitter.particleColorSequence = nil // Use single color
    emitter.particleBlendMode = .add // Bright effect

    // Remove emitter after particles die out
    emitter.run(SKAction.sequence([
        SKAction.wait(forDuration: Double(emitter.particleLifetime + emitter.particleLifetimeRange)),
        SKAction.removeFromParent()
    ]))
    return emitter
}

func createImpactEmitter(position: CGPoint) -> SKEmitterNode {
    let emitter = SKEmitterNode()
    emitter.position = position
    emitter.particleTexture = SKTexture(imageNamed: "spark")
    emitter.particleBirthRate = 200
    emitter.numParticlesToEmit = 20
    emitter.particleLifetime = 0.2
    emitter.particleLifetimeRange = 0.1
    emitter.particleSpeed = 100
    emitter.particleSpeedRange = 30
    emitter.emissionAngle = 0
    emitter.emissionAngleRange = .pi * 2
    emitter.particleAlpha = 0.9
    emitter.particleAlphaSpeed = -2.0
    emitter.particleScale = 0.15
    emitter.particleScaleRange = 0.05
    emitter.particleScaleSpeed = -0.5
    emitter.particleColor = .lightGray
    emitter.particleColorBlendFactor = 1.0
    emitter.particleBlendMode = .alpha

    emitter.run(SKAction.sequence([
        SKAction.wait(forDuration: Double(emitter.particleLifetime + emitter.particleLifetimeRange)),
        SKAction.removeFromParent()
    ]))
    return emitter
}

func createMuzzleFlashEmitter(position: CGPoint, angle: CGFloat) -> SKEmitterNode {
    let emitter = SKEmitterNode()
    emitter.position = position
    emitter.particleTexture = SKTexture(imageNamed: "spark")
    emitter.particleBirthRate = 500 // Burst
    emitter.numParticlesToEmit = 15
    emitter.particleLifetime = 0.1
    emitter.particleLifetimeRange = 0.05
    emitter.particleSpeed = 50
    emitter.particleSpeedRange = 20
    emitter.emissionAngle = angle + .pi / 2 // Point outwards from gun barrel
    emitter.emissionAngleRange = .pi / 8 // Narrow cone
    emitter.particleAlpha = 0.9
    emitter.particleAlphaSpeed = -5.0 // Fade fast
    emitter.particleScale = 0.2
    emitter.particleScaleRange = 0.05
    emitter.particleScaleSpeed = -1.0
    emitter.particleColor = .yellow
    emitter.particleColorBlendFactor = 1.0
    emitter.particleBlendMode = .add

    emitter.run(SKAction.sequence([
        SKAction.wait(forDuration: Double(emitter.particleLifetime + emitter.particleLifetimeRange)),
        SKAction.removeFromParent()
    ]))
    return emitter
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    // Game entities
    var player: SKShapeNode?
    var playerHealth = 100 // Example starting health
    let maxPlayerHealth = 100 // Define max health
    var scoreLabel: SKLabelNode?
    var healthLabel: SKLabelNode?
    var score = 0

    // --- Upgrade System ---
    var fireRateLevel = 0
    let fireRateUpgradeThresholds = [50, 150, 300, 500] // Score needed for next level
    let basePlayerFireRate: TimeInterval = 0.35 // Starting fire rate
    let maxFireRateLevel = 4 // Corresponds to thresholds array size
    var permanentPlayerFireRate: TimeInterval = 0.35 // Current permanent fire rate
    var multiShotLevel = 0
    let multiShotUpgradeThresholds = [100, 250, 450] // Different thresholds for variety
    let maxMultiShotLevel = 3 // Max 3 extra projectiles (4 total)
    let multiShotSpreadAngle: CGFloat = 0.1 // Radians (about 5.7 degrees per extra shot)
    var projectileSpeedLevel = 0
    let projectileSpeedUpgradeThresholds = [75, 200, 400, 600] // Yet another set of thresholds
    let basePlayerProjectileSpeed: CGFloat = 500.0
    let maxProjectileSpeedLevel = 4
    var permanentPlayerProjectileSpeed: CGFloat = 500.0
    var upgradeNoticeLabel: SKLabelNode?
    var downgradeNoticeLabel: SKLabelNode? // For showing downgrade
    var gameOverLabel: SKLabelNode?
    var restartLabel: SKLabelNode?
    var gameOverOverlay: SKShapeNode?

    // Timers and counters
    var lastUpdateTime: TimeInterval = 0
    var timeSinceEnemySpawn: TimeInterval = 0
    var enemySpawnRate: TimeInterval = 1.5 // Spawn an enemy every 1.5 seconds
    var timeSinceEnemyFire: TimeInterval = 0
    var enemyFireRate: TimeInterval = 2.0 // Enemies fire (on average) every 2 seconds
    var lastPlayerFireTime: TimeInterval = 0
    var powerUpDuration: TimeInterval = 5.0 // How long power-ups last
    var powerUpTimer: TimeInterval = 0
    var isPowerUpActive = false
    let powerUpFireRate: TimeInterval = 0.1 // Fixed rate during power-up

    // Physics categories (using bitmasks)
    struct PhysicsCategory {
        static let none: UInt32 = 0
        static let player: UInt32 = 0b1       // 1
        static let enemy: UInt32 = 0b10      // 2
        static let playerProjectile: UInt32 = 0b100 // 4
        static let enemyProjectile: UInt32 = 0b1000 // 8
        static let powerUp: UInt32 = 0b10000 // 16
    }

    // Root node for shake
    var worldNode: SKNode?
    var isGameOver = false

    override func didMove(to view: SKView) {
        // Initial scene setup
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0) // Dark grey background
        physicsWorld.gravity = .zero // No gravity needed for a top-down shooter
        physicsWorld.contactDelegate = self

        // Create world node for shaking
        worldNode = SKNode()
        if let worldNode = worldNode { addChild(worldNode) }

        // Add background
        let starfield = createStarfield(frame: self.frame)
        starfield.zPosition = -10 // Ensure background is behind everything
        worldNode?.addChild(starfield)

        // Initial setup
        resetGameVariables() // Call the reset function
        setupPlayer()
        setupUI()
        updateUI() // Ensure initial UI state is correct
        isGameOver = false
    }

    func resetGameVariables() {
        // Reset player state
        playerHealth = maxPlayerHealth
        score = 0
        fireRateLevel = 0
        multiShotLevel = 0
        projectileSpeedLevel = 0
        recalculateAllPermanentStats() // Recalculate based on reset levels

        // Reset timers
        lastUpdateTime = 0
        timeSinceEnemySpawn = 0
        timeSinceEnemyFire = 0
        lastPlayerFireTime = 0
        powerUpTimer = 0
        isPowerUpActive = false
        // Note: isGameOver is handled separately in didMove and restartGame
    }

    func setupPlayer() {
        player?.removeFromParent() // Remove existing player if any
        
        let playerSize = CGSize(width: 40, height: 40)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -playerSize.width / 2, y: -playerSize.height / 2))
        path.addLine(to: CGPoint(x: playerSize.width / 2, y: -playerSize.height / 2))
        path.addLine(to: CGPoint(x: 0, y: playerSize.height / 2))
        path.closeSubpath()

        player = SKShapeNode(path: path)
        player?.fillColor = .cyan
        player?.strokeColor = .white
        player?.lineWidth = 1
        player?.position = CGPoint(x: frame.midX, y: frame.minY + 75)
        player?.name = "player"

        player?.physicsBody = SKPhysicsBody(polygonFrom: path)
        player?.physicsBody?.categoryBitMask = PhysicsCategory.player
        player?.physicsBody?.contactTestBitMask = PhysicsCategory.enemyProjectile
        player?.physicsBody?.collisionBitMask = PhysicsCategory.none
        player?.physicsBody?.affectedByGravity = false
        player?.physicsBody?.isDynamic = false

        if let player = player {
            worldNode?.addChild(player)
        }
    }

    func setupUI() {
        let fontName = "HelveticaNeue-CondensedBold"
        // Calculate safe area insets, providing default padding if view isn't ready
        let topPadding = view?.safeAreaInsets.top ?? 20 // Default padding if safeAreaInsets not available yet
        let horizontalPadding: CGFloat = 20
        let verticalPosition = frame.maxY - topPadding - 25 // Position below safe area top

        scoreLabel?.removeFromParent()
        scoreLabel = SKLabelNode(fontNamed: fontName)
        scoreLabel?.text = "Score: 0"
        scoreLabel?.fontSize = 22
        scoreLabel?.fontColor = .white
        scoreLabel?.horizontalAlignmentMode = .left
        scoreLabel?.position = CGPoint(x: frame.minX + horizontalPadding, y: verticalPosition)
        if let scoreLabel = scoreLabel { addChild(scoreLabel) }

        healthLabel?.removeFromParent()
        healthLabel = SKLabelNode(fontNamed: fontName)
        healthLabel?.text = "Health: \(playerHealth)"
        healthLabel?.fontSize = 22
        healthLabel?.fontColor = .cyan
        healthLabel?.horizontalAlignmentMode = .right
        healthLabel?.position = CGPoint(x: frame.maxX - horizontalPadding, y: verticalPosition)
        if let healthLabel = healthLabel { addChild(healthLabel) }

        upgradeNoticeLabel?.removeFromParent()
        upgradeNoticeLabel = SKLabelNode(fontNamed: fontName)
        upgradeNoticeLabel?.text = "Upgrade!"
        upgradeNoticeLabel?.fontSize = 28
        upgradeNoticeLabel?.fontColor = .yellow
        upgradeNoticeLabel?.position = CGPoint(x: frame.midX, y: frame.midY + 60)
        upgradeNoticeLabel?.alpha = 0
        upgradeNoticeLabel?.zPosition = 100
        if let upgradeNoticeLabel = upgradeNoticeLabel { addChild(upgradeNoticeLabel) }

        downgradeNoticeLabel?.removeFromParent()
        downgradeNoticeLabel = SKLabelNode(fontNamed: fontName)
        downgradeNoticeLabel?.text = "Downgrade!"
        downgradeNoticeLabel?.fontSize = 28
        downgradeNoticeLabel?.fontColor = .orange
        downgradeNoticeLabel?.position = CGPoint(x: frame.midX, y: frame.midY + 25)
        downgradeNoticeLabel?.alpha = 0
        downgradeNoticeLabel?.zPosition = 100
        if let downgradeNoticeLabel = downgradeNoticeLabel { addChild(downgradeNoticeLabel) }
        
        // Game Over UI (initially hidden)
        gameOverOverlay?.removeFromParent() // Remove if exists
        gameOverOverlay = SKShapeNode(rect: self.frame) // Cover whole screen
        gameOverOverlay?.fillColor = .black
        gameOverOverlay?.strokeColor = .clear
        gameOverOverlay?.alpha = 0 // Start hidden
        gameOverOverlay?.zPosition = 90 // Below labels, above world
        if let overlay = gameOverOverlay { addChild(overlay) } // Add to scene

        gameOverLabel?.removeFromParent()
        gameOverLabel = SKLabelNode(fontNamed: fontName)
        gameOverLabel?.text = "Game Over"
        gameOverLabel?.fontSize = 40 // Slightly smaller
        gameOverLabel?.fontColor = .white
        gameOverLabel?.position = CGPoint(x: frame.midX, y: frame.midY + 30) // Adjusted position
        gameOverLabel?.alpha = 0
        gameOverLabel?.zPosition = 100
        if let gameOverLabel = gameOverLabel { addChild(gameOverLabel) }
        
        restartLabel?.removeFromParent()
        restartLabel = SKLabelNode(fontNamed: fontName)
        restartLabel?.text = "Tap to Restart"
        restartLabel?.fontSize = 24 // Adjusted size
        restartLabel?.fontColor = .lightGray
        restartLabel?.position = CGPoint(x: frame.midX, y: frame.midY - 30) // Adjusted position
        restartLabel?.alpha = 0
        restartLabel?.zPosition = 100
        if let restartLabel = restartLabel { addChild(restartLabel) }
    }

    func updateUI() {
        scoreLabel?.text = "Score: \(score)"
        healthLabel?.text = "Health: \(playerHealth)"
        if playerHealth > 70 { healthLabel?.fontColor = .cyan }
        else if playerHealth > 35 { healthLabel?.fontColor = .yellow }
        else { healthLabel?.fontColor = .red }
    }

    func spawnEnemy() {
        let enemySize = CGSize(width: 35, height: 35)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: enemySize.height / 2))
        path.addLine(to: CGPoint(x: -enemySize.width / 2, y: -enemySize.height / 2))
        path.addLine(to: CGPoint(x: enemySize.width / 2, y: -enemySize.height / 2))
        path.closeSubpath()
        let enemy = SKShapeNode(path: path)
        enemy.fillColor = .red
        enemy.strokeColor = SKColor(red: 0.6, green: 0, blue: 0, alpha: 1.0)
        enemy.lineWidth = 1
        enemy.name = "enemy"
        let randomX = CGFloat.random(in: frame.minX + enemySize.width/2 ... frame.maxX - enemySize.width/2)
        enemy.position = CGPoint(x: randomX, y: frame.maxY + enemySize.height/2)
        enemy.physicsBody = SKPhysicsBody(polygonFrom: path)
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile
        enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.linearDamping = 0
        enemy.physicsBody?.velocity = CGVector(dx: 0, dy: -150)
        worldNode?.addChild(enemy)
    }

    func spawnPowerUp(at position: CGPoint) {
        let powerUpSize = CGSize(width: 25, height: 25) // Slightly larger
        let powerUp = SKShapeNode(circleOfRadius: powerUpSize.width / 2)
        powerUp.fillColor = .green
        powerUp.strokeColor = .white
        powerUp.lineWidth = 1.5
        powerUp.glowWidth = 8 // More glow
        powerUp.position = position
        powerUp.name = "powerUp"

        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: powerUpSize.width / 2)
        powerUp.physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        powerUp.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile
        powerUp.physicsBody?.collisionBitMask = PhysicsCategory.none
        powerUp.physicsBody?.affectedByGravity = false
        powerUp.physicsBody?.velocity = CGVector(dx: 0, dy: -50)

        // Add pulsing animation
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.6),
            SKAction.scale(to: 1.0, duration: 0.6)
        ]))
        powerUp.run(pulse)

        worldNode?.addChild(powerUp)

        let removeAction = SKAction.sequence([
            SKAction.wait(forDuration: 8.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        powerUp.run(removeAction)
    }

    // Function to get the current effective fire rate
    func getCurrentFireRate() -> TimeInterval {
        return isPowerUpActive ? powerUpFireRate : permanentPlayerFireRate
    }

    func getCurrentProjectileSpeed() -> CGFloat {
        // Note: Power-up doesn't affect projectile speed in this example
        return permanentPlayerProjectileSpeed
    }

    func firePlayerProjectile(at location: CGPoint) {
        guard !isGameOver else { return } // Don't fire if game over
        guard CACurrentMediaTime() - lastPlayerFireTime > getCurrentFireRate() else {
            return
        }
        lastPlayerFireTime = CACurrentMediaTime()
        guard let playerPosition = player?.position else { return }
        let numberOfProjectiles = multiShotLevel + 1
        let baseAngle = atan2(location.y - playerPosition.y, location.x - playerPosition.x)
        let currentSpeed = getCurrentProjectileSpeed()
        let muzzleOffset: CGFloat = 25
        let muzzleX = playerPosition.x + muzzleOffset * cos(baseAngle)
        let muzzleY = playerPosition.y + muzzleOffset * sin(baseAngle)
        let muzzlePosition = CGPoint(x: muzzleX, y: muzzleY)
        for i in 0..<numberOfProjectiles {
            let projectile = createBaseProjectile(at: muzzlePosition)
            var currentAngle = baseAngle
            if numberOfProjectiles > 1 {
                let angleOffset = (CGFloat(i) - CGFloat(numberOfProjectiles - 1) / 2.0) * multiShotSpreadAngle
                currentAngle += angleOffset
            }
            let direction = CGVector(dx: cos(currentAngle), dy: sin(currentAngle))
            projectile.physicsBody?.velocity = CGVector(dx: direction.dx * currentSpeed, dy: direction.dy * currentSpeed)
            projectile.zRotation = currentAngle - .pi / 2
            if i == (numberOfProjectiles - 1) / 2 { 
                let flashEmitter = createMuzzleFlashEmitter(position: muzzlePosition, angle: baseAngle)
                worldNode?.addChild(flashEmitter)
            }
            worldNode?.addChild(projectile)
            let removeAction = SKAction.sequence([
                SKAction.wait(forDuration: 3.0),
                SKAction.removeFromParent()
            ])
            projectile.run(removeAction, withKey: "projectileRemove_\(i)")
        }
    }

    // Helper to create a single projectile node with physics
    func createBaseProjectile(at position: CGPoint) -> SKShapeNode {
        let projectileSize = CGSize(width: 4, height: 12)
        let projectile = SKShapeNode(rectOf: projectileSize, cornerRadius: 2)
        projectile.fillColor = .yellow
        projectile.strokeColor = .orange
        projectile.glowWidth = 3
        projectile.lineWidth = 0
        projectile.position = position
        projectile.name = "playerProjectile"
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectileSize)
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.playerProjectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyProjectile | PhysicsCategory.powerUp
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        projectile.physicsBody?.linearDamping = 0
        return projectile
    }

    func fireEnemyProjectile(from enemy: SKShapeNode) {
        guard !isGameOver else { return } // Don't fire if game over
        guard let playerPosition = player?.position else { return }
        let enemyPosition = enemy.position
        let projectileSize = CGSize(width: 8, height: 8)
        let projectile = SKShapeNode(circleOfRadius: projectileSize.width / 2)
        projectile.fillColor = .magenta
        projectile.strokeColor = .red
        projectile.glowWidth = 2
        projectile.lineWidth = 0
        projectile.position = enemyPosition
        projectile.name = "enemyProjectile"
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectileSize.width / 2)
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.enemyProjectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.playerProjectile
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        let dx = playerPosition.x - enemyPosition.x
        let dy = playerPosition.y - enemyPosition.y
        let magnitude = sqrt(dx*dx + dy*dy)
        guard magnitude > 0 else { return }
        let direction = CGVector(dx: dx / magnitude, dy: dy / magnitude)
        let speed: CGFloat = 250.0
        projectile.physicsBody?.velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        worldNode?.addChild(projectile)
        let removeAction = SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.removeFromParent()
        ])
        projectile.run(removeAction)
    }

    // Touch handling for aiming and firing
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOver {
            restartGame()
            return
        }

        guard let touch = touches.first else { return }
        let location = touch.location(in: worldNode!) // Use worldNode coordinates

        // Check if the touch is on the player initially (optional: for drag offset)
        // let touchedNodes = worldNode?.nodes(at: location)
        // if touchedNodes?.contains(player!) == true { ... }

        // Immediately try firing at the tap location
        firePlayerProjectile(at: location)

        // Move player to touch X on initial tap as well - REMOVED
        // movePlayer(to: location.x)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOver { return } // Ignore touches if game over

        // We are a fixed turret, so dragging does nothing for movement.
        // Optionally, could implement drag-firing here if desired.
        // guard let touch = touches.first else { return }
        // let location = touch.location(in: worldNode!) // Use worldNode coordinates
        // movePlayer(to: location.x) - REMOVED
    }

    // Game loop updates
    override func update(_ currentTime: TimeInterval) {
        if isGameOver { return } // Don't update game logic if over
        
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // --- Enemy Spawning ---
        timeSinceEnemySpawn += dt
        if timeSinceEnemySpawn >= enemySpawnRate {
            spawnEnemy()
            timeSinceEnemySpawn = 0 // Reset timer
        }

        // --- Enemy Firing ---
        timeSinceEnemyFire += dt
        if timeSinceEnemyFire >= enemyFireRate {
            // Randomly decide if an enemy fires to make it less predictable
            if Int.random(in: 0...2) == 0 { // ~33% chance each interval
                var potentialShooters: [SKShapeNode] = []
                worldNode?.children.forEach { node in
                    // Find visible enemies
                    if node.name == "enemy" && node.position.y < frame.maxY {
                        if let enemyNode = node as? SKShapeNode {
                             potentialShooters.append(enemyNode)
                        }
                    }
                }
                // Pick a random enemy to fire
                if let shooter = potentialShooters.randomElement() {
                    fireEnemyProjectile(from: shooter)
                }
            }
            timeSinceEnemyFire = 0 // Reset timer regardless of firing
        }

        // --- Power-up Timer ---
        if isPowerUpActive {
            powerUpTimer -= dt
            if powerUpTimer <= 0 {
                deactivatePowerUp()
            }
        }

        // --- Cleanup Off-screen Nodes ---
        cleanupOffscreenNodes()
    }

    func activatePowerUp() {
        print("Power-up activated! Fire rate set to \(powerUpFireRate)")
        isPowerUpActive = true
        powerUpTimer = powerUpDuration
        // Visual feedback
        player?.run(SKAction.sequence([
            SKAction.colorize(with: .green, colorBlendFactor: 1.0, duration: 0.1),
            SKAction.wait(forDuration: powerUpDuration - 0.2),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        ]), withKey: "powerUpColor") // Use a key to manage action
    }

    func deactivatePowerUp() {
        print("Power-up deactivated. Fire rate restored to \(permanentPlayerFireRate)")
        isPowerUpActive = false
        // Ensure color is reset
        player?.removeAction(forKey: "powerUpColor")
        player?.fillColor = .cyan
    }

    // --- Stat Recalculation --- Needed for upgrades/downgrades
    func recalculateFireRate() {
        permanentPlayerFireRate = basePlayerFireRate * pow(0.85, TimeInterval(fireRateLevel))
    }

    func recalculateProjectileSpeed() {
        permanentPlayerProjectileSpeed = basePlayerProjectileSpeed * (1.0 + 0.15 * CGFloat(projectileSpeedLevel))
    }

    func recalculateAllPermanentStats() {
        recalculateFireRate()
        recalculateProjectileSpeed()
        // Multi-shot level doesn't have a separate stat, it's used directly
    }

    func applyFireRateUpgrade() {
        guard fireRateLevel < maxFireRateLevel else { return } // Already max level

        fireRateLevel += 1
        // Example: Reduce fire interval by 15% each level
        recalculateFireRate()

        print("Fire Rate Upgraded! Level \(fireRateLevel), New Rate: \(permanentPlayerFireRate)")
        showUpgradeNotice(message: "Fire Rate Increased!")
    }

    func applyMultiShotUpgrade() {
        guard multiShotLevel < maxMultiShotLevel else { return }
        multiShotLevel += 1
        print("Multi-Shot Upgraded! Level \(multiShotLevel), Projectiles: \(multiShotLevel + 1)")
        showUpgradeNotice(message: "Multi-Shot Increased!")
    }

    func applyProjectileSpeedUpgrade() {
        guard projectileSpeedLevel < maxProjectileSpeedLevel else { return }
        projectileSpeedLevel += 1
        // Example: Increase speed by 15% each level
        recalculateProjectileSpeed()
        print("Projectile Speed Upgraded! Level \(projectileSpeedLevel), New Speed: \(permanentPlayerProjectileSpeed)")
        showUpgradeNotice(message: "Projectile Speed Increased!")
    }

    func applyRandomDowngrade() {
        var availableDowngrades: [() -> Void] = []

        if fireRateLevel > 0 {
            availableDowngrades.append { [weak self] in
                guard let self = self else { return } // Use guard let for safety
                self.fireRateLevel -= 1
                self.recalculateFireRate() // Use the recalculate function
                self.showDowngradeNotice(message: "Fire Rate Decreased!")
                print("Downgraded Fire Rate to Level \(self.fireRateLevel)")
            }
        }
        if multiShotLevel > 0 {
            availableDowngrades.append { [weak self] in
                guard let self = self else { return }
                self.multiShotLevel -= 1
                // No recalculate needed for multishot, level is used directly
                self.showDowngradeNotice(message: "Multi-Shot Decreased!")
                print("Downgraded Multi-Shot to Level \(self.multiShotLevel)")
            }
        }
        if projectileSpeedLevel > 0 {
            availableDowngrades.append { [weak self] in
                guard let self = self else { return }
                self.projectileSpeedLevel -= 1
                self.recalculateProjectileSpeed() // Use the recalculate function
                self.showDowngradeNotice(message: "Projectile Speed Decreased!")
                print("Downgraded Projectile Speed to Level \(self.projectileSpeedLevel)")
            }
        }

        // If there are any upgrades to remove, pick one randomly
        if let downgradeAction = availableDowngrades.randomElement() {
            downgradeAction()
            // Play sound placeholder
            // run(SKAction.playSoundFileNamed("downgrade.wav", waitForCompletion: false))
        }
    }

    func showUpgradeNotice(message: String) {
        upgradeNoticeLabel?.text = message // Set custom message
        upgradeNoticeLabel?.setScale(1.5)
        upgradeNoticeLabel?.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.2)
            ]),
            SKAction.wait(forDuration: 1.3),
            SKAction.fadeOut(withDuration: 0.3)
        ]))
    }

    func showDowngradeNotice(message: String) {
        downgradeNoticeLabel?.text = message
        downgradeNoticeLabel?.setScale(1.5)
        downgradeNoticeLabel?.run(SKAction.sequence([
             SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.2)
            ]),
            SKAction.wait(forDuration: 1.3),
            SKAction.fadeOut(withDuration: 0.3)
        ]))
    }

    func cleanupOffscreenNodes() {
        worldNode?.children.forEach { node in
            // Remove nodes that go way off screen
            if node.position.y < frame.minY - 100 || node.position.y > frame.maxY + 100 ||
               node.position.x < frame.minX - 100 || node.position.x > frame.maxX + 100
            {
                 // Only remove nodes that should be removed (enemies, projectiles)
                 if node.name == "enemy" || node.name == "playerProjectile" || node.name == "enemyProjectile" || node.name == "powerUp" {
                    node.removeFromParent()
                 }
            }
        }
    }

    // Physics contact handling
    func didBegin(_ contact: SKPhysicsContact) {
        if isGameOver { return } // Ignore contacts if game is over
        
        guard let nodeA = contact.bodyA.node, let nodeB = contact.bodyB.node else { return }
        // Check parentage against worldNode
        guard let parentA = nodeA.parent, let parentB = nodeB.parent else { return }
        // Only process contacts where both nodes are direct children of worldNode
        guard parentA == worldNode && parentB == worldNode else { return }

        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask

        let playerNode = (maskA == PhysicsCategory.player) ? nodeA : (maskB == PhysicsCategory.player) ? nodeB : nil
        let enemyNode = (maskA == PhysicsCategory.enemy) ? nodeA : (maskB == PhysicsCategory.enemy) ? nodeB : nil
        let playerProjectileNode = (maskA == PhysicsCategory.playerProjectile) ? nodeA : (maskB == PhysicsCategory.playerProjectile) ? nodeB : nil
        let enemyProjectileNode = (maskA == PhysicsCategory.enemyProjectile) ? nodeA : (maskB == PhysicsCategory.enemyProjectile) ? nodeB : nil
        let powerUpNode = (maskA == PhysicsCategory.powerUp) ? nodeA : (maskB == PhysicsCategory.powerUp) ? nodeB : nil

        // Use optional casting `as?` for safety
        // Player Projectile vs Enemy
        if let projectile = playerProjectileNode as? SKShapeNode, let enemy = enemyNode as? SKShapeNode {
            handleEnemyHit(projectile: projectile, enemy: enemy, at: contact.contactPoint)
        }
        // Enemy Projectile vs Player
        if let projectile = enemyProjectileNode as? SKShapeNode, let player = playerNode as? SKShapeNode {
            handlePlayerHit(projectile: projectile, player: player, at: contact.contactPoint)
        }
        // Player Projectile vs Enemy Projectile
        if let pProjectile = playerProjectileNode as? SKShapeNode, let eProjectile = enemyProjectileNode as? SKShapeNode {
            handleProjectileCollision(playerProjectile: pProjectile, enemyProjectile: eProjectile, at: contact.contactPoint)
        }
        // Player Projectile vs PowerUp
        if let projectile = playerProjectileNode as? SKShapeNode, let powerUp = powerUpNode as? SKShapeNode {
            handlePowerUpShot(projectile: projectile, powerUp: powerUp)
        }
    }

    func handleEnemyHit(projectile: SKShapeNode, enemy: SKShapeNode, at position: CGPoint) {
        projectile.removeFromParent()
        enemy.removeFromParent()
        score += 10
        updateUI()

        // Chance to gain health
        let healthGainChance = 10 // 10% chance
        if Int.random(in: 1...100) <= healthGainChance {
            playerHealth = min(playerHealth + 10, maxPlayerHealth) // Gain 10 health, capped
            print("Gained Health!")
            // Optional: Add visual/audio feedback for health gain
        }

        // Check for upgrades (can only get one upgrade per kill for simplicity)
        var upgraded = false
        if fireRateLevel < maxFireRateLevel && score >= fireRateUpgradeThresholds[fireRateLevel] {
            applyFireRateUpgrade()
            upgraded = true
        }
        if !upgraded && multiShotLevel < maxMultiShotLevel && score >= multiShotUpgradeThresholds[multiShotLevel] {
            applyMultiShotUpgrade()
            upgraded = true // Prevent checking further upgrades this hit
        }
        if !upgraded && projectileSpeedLevel < maxProjectileSpeedLevel && score >= projectileSpeedUpgradeThresholds[projectileSpeedLevel] {
            applyProjectileSpeedUpgrade()
            upgraded = true
        }

        // Chance to spawn power-up
        if !isPowerUpActive && Int.random(in: 0..<5) == 0 {
            spawnPowerUp(at: position)
        }
        // TODO: Add explosion effects, sound, etc.
    }

    func handlePlayerHit(projectile: SKShapeNode, player: SKShapeNode, at position: CGPoint) {
        projectile.removeFromParent()
        playerHealth -= 25 // Decrease health
        updateUI()

        // Apply Downgrade
        applyRandomDowngrade()

        // Simple hit flash
        player.run(SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.9, duration: 0.05),
            SKAction.wait(forDuration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        ]))

        if playerHealth <= 0 {
            gameOver()
        }
    }

    func handlePowerUpShot(projectile: SKShapeNode, powerUp: SKShapeNode) {
        projectile.removeFromParent()
        powerUp.removeFromParent()
        
        if !isPowerUpActive {
            activatePowerUp()
        }
        // TODO: Add sound effect for power-up collection
    }

    func handleProjectileCollision(playerProjectile: SKShapeNode, enemyProjectile: SKShapeNode, at position: CGPoint) {
        // Simply remove both projectiles on collision
        playerProjectile.removeFromParent()
        enemyProjectile.removeFromParent()
        // TODO: Add a small visual effect (e.g., spark) at the collision point
        print("Projectile collision!")
    }

    func gameOver() {
        guard !isGameOver else { return } // Prevent running multiple times
        isGameOver = true
        print("Game Over!")

        // Stop world node actions (like shake)
        worldNode?.removeAllActions()
        worldNode?.position = .zero // Reset position if shaken
        worldNode?.isPaused = true // Pause enemy movement/spawning within worldNode

        // Show Overlay
        gameOverOverlay?.run(SKAction.fadeAlpha(to: 0.7, duration: 0.4)) // Fade in overlay

        // Update Game Over label text with final score
        gameOverLabel?.text = "Game Over - Score: \(score)"
        
        // Show labels after a short delay
        let labelFadeIn = SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.4)
        ])
        gameOverLabel?.run(labelFadeIn)
        restartLabel?.run(labelFadeIn)

        // Optional: Fade out remaining projectiles/enemies slightly later?
        // Or just leave them paused.
    }

    func restartGame() {
        guard isGameOver else { return } // Only restart if game is actually over
        print("Restarting Game...")
        
        // Hide Game Over UI and Overlay
        gameOverOverlay?.alpha = 0 // Hide immediately
        gameOverLabel?.alpha = 0
        restartLabel?.alpha = 0
        
        // Remove all game-related nodes from worldNode
        worldNode?.children.forEach { node in
            if node.name == "enemy" || node.name == "playerProjectile" || node.name == "enemyProjectile" || node.name == "powerUp" {
                node.removeFromParent()
            }
            // Also remove emitters that might be lingering
            if node is SKEmitterNode {
                node.removeFromParent()
            }
        }
        
        // Unpause world
        worldNode?.isPaused = false
        
        // Reset game state
        resetGameVariables()
        
        // Recreate player
        setupPlayer()
        
        // Update UI to initial state
        updateUI()
        
        // Ready to play
        isGameOver = false
    }
} 