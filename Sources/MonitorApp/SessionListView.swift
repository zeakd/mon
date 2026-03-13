import SwiftUI
import MonitorKit

/// 왼클릭 popover에 표시되는 세션 리스트
struct SessionPopoverView: View {
    @ObservedObject var viewModel: MonViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.sessions.isEmpty {
                Text("no sessions")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                if !viewModel.activeSessions.isEmpty {
                    sectionHeader("Active")
                    ForEach(viewModel.activeSessions) { session in
                        sessionRow(session, active: true)
                    }
                }
                if !viewModel.idleSessions.isEmpty {
                    sectionHeader("Idle")
                    ForEach(viewModel.idleSessions) { session in
                        sessionRow(session, active: false)
                    }
                }
            }
        }
        .frame(minWidth: 260)
        .padding(.vertical, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func sessionRow(_ session: Session, active: Bool) -> some View {
        HStack {
            Circle()
                .fill(active ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .font(.body)
                Text("\(session.machine) · \(timeAgo(session.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.canFocus {
                Image(systemName: "arrow.up.forward.square")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if let cmd = session.focusCommand {
                Task.detached {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    process.arguments = ["-c", cmd]
                    try? process.run()
                }
            }
        }
        .opacity(session.canFocus ? 1.0 : 0.8)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}
