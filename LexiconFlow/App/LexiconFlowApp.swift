import SwiftUI
import SwiftData

@main
struct LexiconFlowApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Models will be added here in Phase 1
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// Placeholder view - will be replaced in Phase 1
struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint(.blue))

                Text("Lexicon Flow")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("iOS 26.2 • Coming Soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Lexicon Flow")
        }
    }
}
