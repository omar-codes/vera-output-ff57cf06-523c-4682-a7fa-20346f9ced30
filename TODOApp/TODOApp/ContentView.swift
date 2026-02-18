import SwiftUI
import SwiftData

struct ContentView: View {
    // Navigation shell implemented in Story 1.2
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("TODOApp")
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [], inMemory: true)
}
