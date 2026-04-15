import SwiftUI
import CadenceCore

public enum AppTab: Hashable {
    case home, history, trends, settings
}

public struct CadenceRootView: View {
    @State private var model: AppModel
    @State private var selectedTab: AppTab = .home
    @State private var showingWorkout = false
    @State private var showingRunLog = false

    public init(model: AppModel = .live()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(
                    selectedTab: $selectedTab,
                    startWorkout: { showingWorkout = true },
                    logRun: { showingRunLog = true }
                )
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "calendar") }
            .tag(AppTab.history)

            NavigationStack {
                TrendsView()
            }
            .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.trends)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(AppTab.settings)
        }
        .tint(.cadenceAccent)
        .environment(model)
        .workoutCover(isPresented: $showingWorkout) {
            ActiveWorkoutView()
                .environment(model)
        }
        .sheet(isPresented: $showingRunLog) {
            RunLogView()
                .environment(model)
        }
        .task {
            await model.importFromHealth()
            await model.sync()
        }
    }
}

struct CadenceRootView_Previews: PreviewProvider {
    static var previews: some View {
        CadenceRootView(model: .preview())
    }
}
