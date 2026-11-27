import SwiftUI

@main
struct AgenteMobileApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
