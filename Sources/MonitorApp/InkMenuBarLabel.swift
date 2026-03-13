import SwiftUI
import MonitorKit

struct InkMenuBarLabel: View {
    @ObservedObject var viewModel: MonViewModel
    @StateObject private var animator = InkAnimator(retina: NSScreen.main?.backingScaleFactor ?? 1 > 1)

    var body: some View {
        Group {
            if viewModel.sessions.isEmpty {
                Image(systemName: "drop")
            } else if let image = animator.currentImage {
                Image(nsImage: image)
            } else {
                Image(systemName: "drop.fill")
            }
        }
        .task {
            animator.updateSessions(viewModel.sessions, idleTimeout: viewModel.idleTimeout)
        }
        .onChange(of: viewModel.sessions) { _, newSessions in
            animator.updateSessions(newSessions, idleTimeout: viewModel.idleTimeout)
        }
    }
}
