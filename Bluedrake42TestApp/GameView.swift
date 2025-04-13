import SwiftUI

// MARK: - Data Models

struct Item: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var description: String
    var quantity: Int = 1
    // Add other relevant properties like weight, value, type, etc.

    // Provide default ID in init
    init(id: UUID = UUID(), name: String, description: String, quantity: Int = 1) {
        self.id = id
        self.name = name
        self.description = description
        self.quantity = quantity
    }

    // Explicit CodingKeys if needed, especially if JSON keys differ or for clarity
    enum CodingKeys: String, CodingKey {
        case id, name, description, quantity
    }
}

struct Equipment: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var description: String
    // Add properties like bonus stats (e.g., scavenging speed, carry capacity, protection)

    init(id: UUID = UUID(), name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description
    }
}

struct Scavenger: Identifiable, Codable {
    let id: UUID
    var name: String
    var level: Int = 1
    var experience: Int = 0
    var equippedWeapon: Equipment?
    var equippedArmor: Equipment?
    var equippedGear: Equipment? // e.g., backpack
    var inventory: [Item] = []
    var status: Status = .idle

    enum Status: String, Codable {
        case idle = "Idle"
        case scavenging = "Scavenging"
        case returning = "Returning"
    }

    init(id: UUID = UUID(), name: String, level: Int = 1, experience: Int = 0, equippedWeapon: Equipment? = nil, equippedArmor: Equipment? = nil, equippedGear: Equipment? = nil, inventory: [Item] = [], status: Status = .idle) {
        self.id = id
        self.name = name
        self.level = level
        self.experience = experience
        self.equippedWeapon = equippedWeapon
        self.equippedArmor = equippedArmor
        self.equippedGear = equippedGear
        self.inventory = inventory
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id, name, level, experience, equippedWeapon, equippedArmor, equippedGear, inventory, status
    }
}

struct Mission: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var duration: TimeInterval
    var difficulty: Int
    var potentialRewards: [Item]
    var assignedScavengerId: UUID?
    var startTime: Date?
    var isCompleted: Bool = false
    var expirationDate: Date? // Added for expiration

    init(id: UUID = UUID(), name: String, description: String, duration: TimeInterval, difficulty: Int, potentialRewards: [Item], assignedScavengerId: UUID? = nil, startTime: Date? = nil, isCompleted: Bool = false, expirationDate: Date? = nil) {
        self.id = id; self.name = name; self.description = description; self.duration = duration; self.difficulty = difficulty; self.potentialRewards = potentialRewards; self.assignedScavengerId = assignedScavengerId; self.startTime = startTime; self.isCompleted = isCompleted;
        // Set expiration only if not already assigned/started
        self.expirationDate = (assignedScavengerId == nil && startTime == nil) ? expirationDate : nil
    }

    // Add CodingKeys including the new property
    enum CodingKeys: String, CodingKey { case id, name, description, duration, difficulty, potentialRewards, assignedScavengerId, startTime, isCompleted, expirationDate }
}

struct BaseResources: Codable {
    var scrap: Int = 100
    var food: Int = 50
    var water: Int = 50
    // Add other resources like building materials, medicine, etc.
}

// MARK: - Game State Manager

@MainActor
class GameManager: ObservableObject {
    @Published var resources = BaseResources()
    @Published var scavengers: [Scavenger] = []
    @Published var availableMissions: [Mission] = []
    @Published var activeMissions: [Mission] = []
    @Published var availableEquipment: [Equipment] = []
    @Published var baseInventory: [Item] = []

    // Mission Generation/Expiration Settings
    private let maxAvailableMissions = 5
    private let missionGenInterval: TimeInterval = 120 // 2 minutes
    private let missionLifespan: TimeInterval = 600 // 10 minutes
    private var lastMissionGenTime: Date?

    private let saveFileURL: URL
    private var gameLoopTimer: Timer?

    // Nested struct for saving Date as TimeInterval
    struct MissionSaveData: Codable {
        let id: UUID
        var name: String
        var description: String
        var duration: TimeInterval
        var difficulty: Int
        var potentialRewards: [Item]
        var assignedScavengerId: UUID?
        var startTimeInterval: TimeInterval?
        var isCompleted: Bool
        var expirationTimeInterval: TimeInterval?

        init(mission: Mission) {
            self.id = mission.id
            self.name = mission.name
            self.description = mission.description
            self.duration = mission.duration
            self.difficulty = mission.difficulty
            self.potentialRewards = mission.potentialRewards
            self.assignedScavengerId = mission.assignedScavengerId
            self.startTimeInterval = mission.startTime?.timeIntervalSince1970
            self.isCompleted = mission.isCompleted
            self.expirationTimeInterval = mission.expirationDate?.timeIntervalSince1970
        }

        func toMission() -> Mission {
            Mission(
                id: self.id,
                name: self.name,
                description: self.description,
                duration: self.duration,
                difficulty: self.difficulty,
                potentialRewards: self.potentialRewards,
                assignedScavengerId: self.assignedScavengerId,
                startTime: self.startTimeInterval != nil ? Date(timeIntervalSince1970: self.startTimeInterval!) : nil,
                isCompleted: self.isCompleted,
                expirationDate: self.expirationTimeInterval != nil ? Date(timeIntervalSince1970: self.expirationTimeInterval!) : nil
            )
        }
    }

    // Nested Struct for Save Data
    struct SaveData: Codable {
        var resources: BaseResources
        var scavengers: [Scavenger]
        var availableMissions: [MissionSaveData]
        var activeMissions: [MissionSaveData]
        var availableEquipment: [Equipment]
        var baseInventory: [Item]
        var lastMissionGenTimeInterval: TimeInterval?
        var lastActiveTimeInterval: TimeInterval?
    }

    init() {
        // Determine save file location
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            saveFileURL = documentsDirectory.appendingPathComponent("gameState.json")
        } else {
            fatalError("Could not find documents directory.")
        }
        print("[DEBUG] GameManager Initialized. Save file URL: \(saveFileURL.path)")

        // Load game and get last active time
        let lastActiveTimeInterval = loadGame() // loadGame now returns the timestamp

        // If loading failed or first launch, populate initial data
        if scavengers.isEmpty && availableMissions.isEmpty {
            populateInitialData()
        }
        if lastMissionGenTime == nil {
            lastMissionGenTime = Date() // Start generation timer if not loaded
        }

        // Calculate offline progress if applicable
        if let loadedTime = lastActiveTimeInterval {
            let lastActiveDate = Date(timeIntervalSince1970: loadedTime)
            let elapsedOfflineTime = Date().timeIntervalSince(lastActiveDate)
            print("[DEBUG] App was inactive for \(String(format: "%.1f", elapsedOfflineTime)) seconds.")
            if elapsedOfflineTime > 1.0 { // Only calculate if more than a second passed
                calculateOfflineProgress(elapsedTime: elapsedOfflineTime)
                // Save immediately after calculating offline progress
                saveGame()
            }
        } else {
            print("[DEBUG] No last active time found (first launch?). Skipping offline calculation.")
        }

        startGameLoopTimer()
    }

    // Update populateInitialData to add expiration dates
    func populateInitialData() {
        print("[DEBUG] Populating initial game data...")
        self.resources = BaseResources()
        self.scavengers = [ Scavenger(name: "Rook"), Scavenger(name: "Piper") ]
        let now = Date()
        self.availableMissions = [
             Mission(name: "Rusted Pipe Cache", description: "Search the nearby collapsed tunnel.", duration: 60, difficulty: 1, potentialRewards: [Item(name: "Scrap", description: "Basic crafting material.", quantity: 5)], expirationDate: now.addingTimeInterval(missionLifespan)),
             Mission(name: "Abandoned Gas Station", description: "Looks risky, but might have supplies.", duration: 300, difficulty: 3, potentialRewards: [Item(name: "Scrap", description: "Basic crafting material.", quantity: 15), Item(name: "Food", description: "Essential sustenance.", quantity: 2)], expirationDate: now.addingTimeInterval(missionLifespan))
        ]
        self.availableEquipment = [
             Equipment(name: "Makeshift Shiv", description: "Better than nothing."),
             Equipment(name: "Leather Vest", description: "Some basic protection."),
             Equipment(name: "Small Rucksack", description: "Increases carry capacity slightly.")
        ]
        self.baseInventory = []
        self.activeMissions = []
        self.lastMissionGenTime = Date() // Set initial generation time
        print("[DEBUG] Initial data population complete.")
    }

    // Update saveGame to use SaveData struct
    func saveGame() {
        print("[DEBUG] Attempting to save game state..." )
        // Update last active time *before* saving
        let currentTimeInterval = Date().timeIntervalSince1970

        let dataToSave = SaveData(
            resources: self.resources,
            scavengers: self.scavengers,
            availableMissions: self.availableMissions.map { MissionSaveData(mission: $0) },
            activeMissions: self.activeMissions.map { MissionSaveData(mission: $0) },
            availableEquipment: self.availableEquipment,
            baseInventory: self.baseInventory,
            lastMissionGenTimeInterval: self.lastMissionGenTime?.timeIntervalSince1970,
            lastActiveTimeInterval: currentTimeInterval // Save current time
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(dataToSave)
            try data.write(to: saveFileURL, options: [.atomicWrite])
            print("[DEBUG] Game state saved successfully at \(Date(timeIntervalSince1970: currentTimeInterval)).")
        } catch {
            print("[DEBUG] ERROR: Failed to save game state: \(error.localizedDescription)")
        }
    }

    // loadGame now returns the last active time interval
    func loadGame() -> TimeInterval? {
        print("[DEBUG] Attempting to load game state from \(saveFileURL.path)..." )
        guard FileManager.default.fileExists(atPath: saveFileURL.path) else {
            print("[DEBUG] Save file does not exist. Will proceed with initial data.")
            return nil
        }
        let decoder = JSONDecoder()
        do {
            let data = try Data(contentsOf: saveFileURL)
            let loadedData = try decoder.decode(SaveData.self, from: data)

            self.resources = loadedData.resources
            self.scavengers = loadedData.scavengers
            self.availableMissions = loadedData.availableMissions.map { $0.toMission() }
            self.activeMissions = loadedData.activeMissions.map { $0.toMission() }
            self.availableEquipment = loadedData.availableEquipment
            self.baseInventory = loadedData.baseInventory
            self.lastMissionGenTime = loadedData.lastMissionGenTimeInterval != nil ? Date(timeIntervalSince1970: loadedData.lastMissionGenTimeInterval!) : nil
            let loadedLastActiveTime = loadedData.lastActiveTimeInterval

            print("[DEBUG] Game state loaded successfully. Last active time: \(loadedLastActiveTime != nil ? String(describing: Date(timeIntervalSince1970: loadedLastActiveTime!)) : "None")" )
            return loadedLastActiveTime
        } catch {
            print("[DEBUG] ERROR: Failed to load game state: \(error.localizedDescription). Populating initial data instead.")
            // Reset state before populating
            self.resources = BaseResources()
            self.scavengers = []
            self.availableMissions = []
            self.activeMissions = []
            self.availableEquipment = []
            self.baseInventory = []
            self.lastMissionGenTime = nil
            // Don't call populateInitialData here, let init handle it
            return nil
        }
    }

    func assignScavenger(missionId: UUID, scavengerId: UUID) {
        print("[DEBUG] Attempting assignment: MissionID=\(missionId), ScavengerID=\(scavengerId)")
        // Find the mission index
        guard let missionIndex = availableMissions.firstIndex(where: { $0.id == missionId }) else {
            print("[DEBUG] ERROR: Mission not found or not available.")
            return
        }

        // Find the scavenger index
        guard let scavengerIndex = scavengers.firstIndex(where: { $0.id == scavengerId }) else {
            print("[DEBUG] ERROR: Scavenger not found.")
            return
        }

        // Check if scavenger is idle
        guard scavengers[scavengerIndex].status == .idle else {
            print("[DEBUG] ERROR: Scavenger '\(scavengers[scavengerIndex].name)' (\(scavengerId)) is not idle (Status: \(scavengers[scavengerIndex].status.rawValue)).")
            // Optionally show an alert to the user
            return
        }

        // Update scavenger status
        scavengers[scavengerIndex].status = .scavenging

        // Update mission details and move it to active
        var missionToActivate = availableMissions.remove(at: missionIndex)
        missionToActivate.assignedScavengerId = scavengerId
        missionToActivate.startTime = Date() // Record start time
        missionToActivate.isCompleted = false // Ensure it's not marked completed

        activeMissions.append(missionToActivate)

        print("[DEBUG] Successfully assigned '\(scavengers[scavengerIndex].name)' to '\(missionToActivate.name)'")
        // TODO: Save game state after successful assignment
        saveGame()
    }

    // Function to start the main game loop timer
    func startGameLoopTimer() {
        // Ensure any existing timer is invalidated before starting a new one
        gameLoopTimer?.invalidate()

        // Schedule a timer that fires every second
        gameLoopTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Ensure the update runs on the main actor
            Task { @MainActor [weak self] in
                self?.updateGameTick()
            }
        }
        // Add the timer to the main run loop to ensure it fires during UI updates/scrolling
        RunLoop.current.add(gameLoopTimer!, forMode: .common)
        print("Game loop timer started.")
    }

    // Main game update function called by the timer
    func updateGameTick() {
        let now = Date()
        print("[DEBUG] Game Tick at \(now)")
        checkMissionCompletion(currentTime: now)
        checkMissionExpiration(currentTime: now)
        checkMissionGeneration(currentTime: now)
        // TODO: Add other periodic updates
    }

    // Pass current time to avoid redundant Date() calls
    func checkMissionCompletion(currentTime: Date) {
        guard !activeMissions.isEmpty else { return } // Don't log if nothing to check
        print("[DEBUG] Checking \(activeMissions.count) active missions for completion...")
        var indicesToRemove: [Int] = []
        for (index, mission) in activeMissions.enumerated() {
            guard let startTime = mission.startTime else { continue }
            let completionTime = startTime.addingTimeInterval(mission.duration)
            let remaining = completionTime.timeIntervalSince(currentTime)
            // print("[DEBUG]   - Active Mission '\(mission.name)': Remaining=\(remaining)s") // Optional: Very verbose
            if remaining <= 0 {
                print("[DEBUG] Mission '\(mission.name)' completed!")
                if let scavengerIndex = scavengers.firstIndex(where: { $0.id == mission.assignedScavengerId }) {
                    scavengers[scavengerIndex].status = .idle
                    print("[DEBUG]   - Scavenger '\(scavengers[scavengerIndex].name)' set to idle.")
                }
                addRewardsToBase(rewards: mission.potentialRewards)
                indicesToRemove.append(index)
            }
        }
        if !indicesToRemove.isEmpty {
            for index in indicesToRemove.sorted(by: >) { activeMissions.remove(at: index) }
            print("[DEBUG] Removed \(indicesToRemove.count) completed mission(s).")
            saveGame()
        }
    }

    // New function to check for expired available missions
    func checkMissionExpiration(currentTime: Date) {
        guard !availableMissions.isEmpty else { return } // Don't log if nothing to check
        print("[DEBUG] Checking \(availableMissions.count) available missions for expiration...")
        var indicesToRemove: [Int] = []
        for (index, mission) in availableMissions.enumerated() {
            if let expiration = mission.expirationDate {
                 let remaining = expiration.timeIntervalSince(currentTime)
                 // print("[DEBUG]   - Available Mission '\(mission.name)': Expires in \(remaining)s") // Optional: Very verbose
                 if remaining <= 0 {
                    print("[DEBUG] Mission '\(mission.name)' expired.")
                    indicesToRemove.append(index)
                }
            }
        }
        if !indicesToRemove.isEmpty {
            for index in indicesToRemove.sorted(by: >) { availableMissions.remove(at: index) }
            print("[DEBUG] Removed \(indicesToRemove.count) expired mission(s).")
            saveGame() // Save after removing expired missions
        }
    }

    // New function to check if a new mission should be generated
    func checkMissionGeneration(currentTime: Date) {
        print("[DEBUG] Checking mission generation: Count=\(availableMissions.count)/\(maxAvailableMissions)")
        guard availableMissions.count < maxAvailableMissions else {
             print("[DEBUG]   - Max available missions reached. Skipping generation.")
             return
        }
        guard let lastGen = lastMissionGenTime else {
            print("[DEBUG]   - No last generation time found. Generating initial mission.")
            generateNewMission(currentTime: currentTime)
            return
        }
        let timeSinceLastGen = currentTime.timeIntervalSince(lastGen)
        print("[DEBUG]   - Time since last generation: \(String(format: "%.1f", timeSinceLastGen))s / \(missionGenInterval)s")
        if timeSinceLastGen >= missionGenInterval {
            print("[DEBUG]   - Generation interval reached. Generating new mission.")
            generateNewMission(currentTime: currentTime)
        } else {
             print("[DEBUG]   - Generation interval not yet reached.")
        }
    }

    // New function to generate a mission
    func generateNewMission(currentTime: Date) {
        // Define some mission templates
        let templates = [
            (name: "Scout Decrepit Warehouse", desc: "Looks unstable, might find something useful.", baseDur: 120.0, baseDiff: 2, rewards: [Item(name: "Scrap", description: "", quantity: 8), Item(name: "Components", description: "Can fix things.", quantity: 1)]),
            (name: "Check Abandoned Bunker", desc: "Sealed tight, maybe something inside?", baseDur: 600.0, baseDiff: 5, rewards: [Item(name: "Scrap", description: "", quantity: 20), Item(name: "Medicine", description: "Heals wounds.", quantity: 1)]),
            (name: "Rummage Through Rubble", desc: "Just piles of junk, mostly.", baseDur: 30.0, baseDiff: 1, rewards: [Item(name: "Scrap", description: "", quantity: 3)]),
            (name: "Investigate Crashed Vertibird", desc: "Military tech? Dangerous area.", baseDur: 450.0, baseDiff: 4, rewards: [Item(name: "Components", description: "", quantity: 3), Item(name: "Weapon Parts", description:"Upgrade potential.", quantity: 1)])
        ]

        let template = templates.randomElement()!
        let difficulty = max(1, template.baseDiff + Int.random(in: -1...1))
        let duration = max(30, template.baseDur * Double.random(in: 0.8...1.2))
        // Adjust reward quantity slightly based on difficulty variation
        let rewards = template.rewards.map { item -> Item in
            var newItem = item
            let quantityMultiplier = Double(difficulty) / Double(template.baseDiff)
            newItem.quantity = max(1, Int(Double(item.quantity) * quantityMultiplier * Double.random(in: 0.9...1.1)))
            return newItem
        }

        let newMission = Mission(
            name: template.name,
            description: template.desc,
            duration: duration,
            difficulty: difficulty,
            potentialRewards: rewards,
            expirationDate: currentTime.addingTimeInterval(missionLifespan)
        )

        availableMissions.append(newMission)
        lastMissionGenTime = currentTime // Reset generation timer
        print("[DEBUG] Generated new mission: '\(newMission.name)' (Difficulty: \(newMission.difficulty), Duration: \(String(format: "%.1f", newMission.duration))s, Expires: \(newMission.expirationDate!))")
        saveGame() // Save after generating a new mission
    }

    // Helper function to add collected items to the base inventory
    func addRewardsToBase(rewards: [Item]) {
        print("[DEBUG] Adding rewards to base:")
        for reward in rewards {
            if let existingItemIndex = baseInventory.firstIndex(where: { $0.name == reward.name }) {
                // Item already exists, increase quantity
                baseInventory[existingItemIndex].quantity += reward.quantity
                 print("[DEBUG]   - Added \(reward.quantity)x '\(reward.name)'. New total: \(baseInventory[existingItemIndex].quantity)")
            } else {
                // New item, add it to the inventory
                baseInventory.append(reward)
                 print("[DEBUG]   - Added new item: \(reward.quantity)x '\(reward.name)'")
            }
        }
    }

    // New function for offline calculations
    func calculateOfflineProgress(elapsedTime: TimeInterval) {
        print("[DEBUG] Calculating offline progress for \(String(format: "%.1f", elapsedTime))s...")
        let offlineStartDate = Date().addingTimeInterval(-elapsedTime) // Approximate start of offline period

        // --- 1. Offline Mission Completion --- (Must be done first)
        var completedMissionIndices: [Int] = []
        var rewardsToGrant: [Item] = []
        print("[DEBUG]   Checking \(activeMissions.count) active missions for offline completion...")
        for (index, mission) in activeMissions.enumerated() {
            guard let startTime = mission.startTime else { continue }
            let completionDate = startTime.addingTimeInterval(mission.duration)
            let remainingTimeAtOfflineStart = max(0, completionDate.timeIntervalSince(offlineStartDate))

            if remainingTimeAtOfflineStart < elapsedTime {
                 print("[DEBUG]     - Mission '\(mission.name)' COMPLETED offline.")
                 completedMissionIndices.append(index)
                 rewardsToGrant.append(contentsOf: mission.potentialRewards)
                 // Update scavenger status immediately
                 if let scavengerIndex = scavengers.firstIndex(where: { $0.id == mission.assignedScavengerId }) {
                     scavengers[scavengerIndex].status = .idle
                     print("[DEBUG]       - Scavenger '\(scavengers[scavengerIndex].name)' set to idle.")
                 }
            }
        }
        // Add rewards gathered offline
        if !rewardsToGrant.isEmpty {
            addRewardsToBase(rewards: rewardsToGrant)
        }
        // Remove completed missions (process in reverse to avoid index issues)
        if !completedMissionIndices.isEmpty {
            for index in completedMissionIndices.sorted(by: >) {
                 activeMissions.remove(at: index)
             }
             print("[DEBUG]   Removed \(completedMissionIndices.count) missions completed offline.")
        }

        // --- 2. Offline Mission Expiration --- (Uses remaining available missions)
        var expiredMissionIndices: [Int] = []
        print("[DEBUG]   Checking \(availableMissions.count) available missions for offline expiration...")
        for (index, mission) in availableMissions.enumerated() {
            guard let expirationDate = mission.expirationDate else { continue }
            let remainingTimeAtOfflineStart = max(0, expirationDate.timeIntervalSince(offlineStartDate))

            if remainingTimeAtOfflineStart < elapsedTime {
                print("[DEBUG]     - Mission '\(mission.name)' EXPIRED offline.")
                expiredMissionIndices.append(index)
            }
        }
        // Remove expired missions
        if !expiredMissionIndices.isEmpty {
             for index in expiredMissionIndices.sorted(by: >) {
                 availableMissions.remove(at: index)
             }
             print("[DEBUG]   Removed \(expiredMissionIndices.count) missions expired offline.")
        }

        // --- 3. Offline Mission Generation --- (Based on time and current count)
        guard let lastGen = lastMissionGenTime else {
            print("[DEBUG]   Cannot calculate offline generation, last generation time is missing.")
            return // Should not happen if loaded/populated correctly
        }

        let timeSinceLastGenWhenOfflineStarted = offlineStartDate.timeIntervalSince(lastGen)
        let totalDurationToCheck = timeSinceLastGenWhenOfflineStarted + elapsedTime
        let numberOfGenerationsMissed = Int(floor(totalDurationToCheck / missionGenInterval))

        print("[DEBUG]   Checking offline mission generation: Missed intervals = \(numberOfGenerationsMissed)")

        var generatedCount = 0
        if numberOfGenerationsMissed > 0 {
            for i in 0..<numberOfGenerationsMissed {
                 if availableMissions.count >= maxAvailableMissions {
                     print("[DEBUG]     - Reached max available missions during offline generation. Stopping.")
                     break // Stop if we hit the cap
                 }
                 // Calculate the approximate time this mission *would* have generated
                 let generationTime = lastGen.addingTimeInterval(Double(i + 1) * missionGenInterval)
                 print("[DEBUG]     - Generating mission for offline interval \(i+1). Approx time: \(generationTime)")
                 generateNewMission(currentTime: generationTime) // Use the calculated time for expiration
                 generatedCount += 1
            }
        }

        // Update last generation time based on calculations
        if generatedCount > 0 {
             // Set it to the time the *last* offline generation would have happened
             self.lastMissionGenTime = lastGen.addingTimeInterval(Double(generatedCount) * missionGenInterval)
             print("[DEBUG]   Updated last mission generation time to: \(self.lastMissionGenTime!)")
        }
        print("[DEBUG] Offline progress calculation finished.")
    }

    // Make sure to invalidate the timer if the GameManager is deinitialized (though less critical for a main state object)
    deinit {
        gameLoopTimer?.invalidate()
        print("Game loop timer invalidated.")
    }
}

// MARK: - Main Game View

struct GameView: View {
    @StateObject private var gameManager = GameManager()
    @Environment(\.scenePhase) private var scenePhase // Observe scene phase

    var body: some View {
        TabView {
            BaseResourcesView()
                .tabItem {
                    Label("Base", systemImage: "house.fill")
                }

            ScavengersView()
                .tabItem {
                    Label("Scavengers", systemImage: "person.3.fill")
                }

            MissionsView()
                .tabItem {
                    Label("Missions", systemImage: "map.fill")
                }
        }
        .environmentObject(gameManager) // Inject the game manager into the environment
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .inactive || newPhase == .background {
                print("App moving to background/inactive, saving game...")
                gameManager.saveGame()
            }
        }
    }
}

// MARK: - Placeholder Tab Views

struct BaseResourcesView: View {
    @EnvironmentObject var gameManager: GameManager

    var body: some View {
        NavigationView {
            List {
                Section("Resources") {
                    Text("Scrap: \(gameManager.resources.scrap)")
                    Text("Food: \(gameManager.resources.food)")
                    Text("Water: \(gameManager.resources.water)")
                }
                inventorySection // Use the computed property here
            }
            .navigationTitle("Base Resources")
        }
    }

    // Computed property for the inventory section
    @ViewBuilder
    private var inventorySection: some View {
        Section("Base Inventory") {
            if gameManager.baseInventory.isEmpty {
                Text("No items in storage.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(gameManager.baseInventory) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("x\(item.quantity)")
                    }
                }
            }
        }
    }
}

struct ScavengersView: View {
     @EnvironmentObject var gameManager: GameManager

     var body: some View {
         NavigationView {
             List {
                 ForEach(gameManager.scavengers) { scavenger in
                     // TODO: Make this a NavigationLink to a ScavengerDetailView
                     VStack(alignment: .leading) {
                         Text(scavenger.name).font(.headline)
                         Text("Status: \(scavenger.status.rawValue)")
                         // TODO: Show more details (level, equipment?)
                     }
                 }
             }
             .navigationTitle("Scavengers")
             // TODO: Add button to recruit new scavengers?
         }
     }
 }


 struct MissionsView: View {
     @EnvironmentObject var gameManager: GameManager
     @State private var showingAssignSheet = false
     @State private var selectedMissionId: UUID?
     // Timer publisher to force UI updates for countdowns
     let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
     // State variable updated by the timer to trigger redraws
     @State private var currentTime = Date()

     var idleScavengers: [Scavenger] {
         gameManager.scavengers.filter { $0.status == .idle }
     }

     var body: some View {
         NavigationView {
             List {
                 availableMissionsSection
                 activeMissionsSection
             }
             .navigationTitle("Missions")
             .actionSheet(isPresented: $showingAssignSheet) {
                 ActionSheet(
                     title: Text("Assign Scavenger"),
                     message: Text("Select an idle scavenger for this mission."),
                     buttons: actionSheetButtons()
                 )
             }
             // Update currentTime when the view appears and whenever the timer fires
             // Although the state update happens here, the .onReceive in activeMissionRow uses it
             .onReceive(timer) { inputTime in
                 currentTime = inputTime
             }
             .onAppear {
                 // Initialize currentTime when the view appears
                 currentTime = Date()
             }
         }
     }

    // MARK: - Computed View Properties

    @ViewBuilder
    private var availableMissionsSection: some View {
        Section("Available Missions") {
            if gameManager.availableMissions.isEmpty {
                Text("No available missions.").foregroundColor(.secondary)
            } else {
                ForEach(gameManager.availableMissions) { mission in
                    Button {
                        if !idleScavengers.isEmpty {
                            selectedMissionId = mission.id
                            showingAssignSheet = true
                        } else {
                            print("No idle scavengers available to assign.")
                        }
                    } label: {
                        missionRow(mission: mission) // Use helper view function
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var activeMissionsSection: some View {
        Section("Active Missions") {
            if gameManager.activeMissions.isEmpty {
                Text("No active missions.").foregroundColor(.secondary)
            } else {
                ForEach(gameManager.activeMissions) { mission in
                    activeMissionRow(mission: mission) // Use helper view function
                }
            }
        }
    }

    // MARK: - Helper View Functions

    @ViewBuilder
    private func missionRow(mission: Mission) -> some View {
        VStack(alignment: .leading) {
            Text(mission.name).font(.headline)
            Text(mission.description).font(.caption).foregroundColor(.gray)
            HStack {
                Text("Duration: \(formattedDuration(mission.duration))")
                Spacer()
                Text("Difficulty: \(mission.difficulty)")
            }
            Text("Rewards: \(mission.potentialRewards.map { "\($0.name) (\($0.quantity))" }.joined(separator: ", "))")
                .font(.footnote)
                .foregroundColor(.secondary)
            // Show expiration time for available missions
            if mission.expirationDate != nil {
                let timeUntilExpiry = calculateRemainingTime(startTime: currentTime, duration: mission.expirationDate!.timeIntervalSince(currentTime))
                if timeUntilExpiry > 0 {
                    Text("Expires in: \(formattedDuration(timeUntilExpiry))")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                } else {
                     Text("Expiring...")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .contentShape(Rectangle())
    }

     @ViewBuilder
     private func activeMissionRow(mission: Mission) -> some View {
         // Calculate remaining time based on the currentTime state variable
         let remainingTime = calculateRemainingTime(startTime: mission.startTime, duration: mission.duration)

         VStack(alignment: .leading) {
             Text(mission.name).font(.headline)
             if let scavenger = gameManager.scavengers.first(where: { $0.id == mission.assignedScavengerId }) {
                 Text("Assigned: \(scavenger.name)").font(.subheadline)
             }

             // Display the calculated remaining time
             if remainingTime > 0 {
                 Text("Time Left: \(formattedDuration(remainingTime))")
                     .font(.caption)
                     .foregroundColor(.orange)
             } else if mission.startTime != nil {
                 // Show completing only if the mission has started
                 Text("Completing...")
                     .font(.caption)
                     .foregroundColor(.green)
             } else {
                 Text("Starting...").font(.caption).foregroundColor(.gray)
             }
         }
         // No need for .onReceive here anymore if the parent view updates currentTime
     }

    // Helper function to calculate remaining time based on the current time state
    private func calculateRemainingTime(startTime: Date?, duration: TimeInterval) -> TimeInterval {
        guard let startTime = startTime else { return 0 }
        let completionDate = startTime.addingTimeInterval(duration)
        return max(0, completionDate.timeIntervalSince(currentTime))
    }

    // MARK: - Action Sheet Helper

    private func actionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = idleScavengers.map { scavenger in
            .default(Text(scavenger.name)) {
                if let missionId = selectedMissionId {
                    gameManager.assignScavenger(missionId: missionId, scavengerId: scavenger.id)
                }
            }
        }
        buttons.append(.cancel())
        return buttons
    }

    // MARK: - Formatting Helper

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
 }


// MARK: - Preview

#Preview {
    GameView()
}
