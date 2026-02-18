import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack(path: Bindable(coordinator).navigationPath) {
            TaskListView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppCoordinator())
        .modelContainer(for: [TaskItem.self, TaskList.self], inMemory: true)
}
