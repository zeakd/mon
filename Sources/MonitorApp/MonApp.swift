import SwiftUI
import MonitorKit

@main
struct MonApp: App {
    @StateObject private var viewModel = MonViewModel()

    var body: some Scene {
        MenuBarExtra {
            SessionListView(viewModel: viewModel)
        } label: {
            InkMenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
