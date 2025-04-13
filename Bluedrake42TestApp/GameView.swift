import SwiftUI
import SpriteKit

// Define the GameScene class (we'll create this file next)
// ... existing code ...

struct GameView: View {
    // Create an instance of our GameScene
    // Make the scene fill the available space and ignore safe areas
    var scene: SKScene {
        let scene = GameScene()
        scene.size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        scene.scaleMode = .aspectFill // Or .resizeFill depending on desired behavior
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea() // Make the game view full screen
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
    }
}
