import SwiftUI
import MonitorKit

struct InkMenuBarLabel: View {
    @ObservedObject var viewModel: MonViewModel
    @StateObject private var animator = InkAnimator(retina: NSScreen.main?.backingScaleFactor ?? 1 > 1)

    var body: some View {
        Group {
            if viewModel.sessions.isEmpty {
                // 세션 없으면 정적 아이콘
                Image(systemName: "drop")
            } else if let image = animator.currentImage {
                Image(nsImage: image)
            }
        }
        .onChange(of: viewModel.sessions) { _, newSessions in
            animator.updateSessions(newSessions, idleTimeout: viewModel.idleTimeout)
        }
    }
}
