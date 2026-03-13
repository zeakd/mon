import SwiftUI
import MonitorKit

struct SessionListView: View {
    @ObservedObject var viewModel: MonViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showSettings {
                SettingsView()
            } else {
                sessionList
            }

            Divider().padding(.vertical, 4)

            HStack {
                Button(showSettings ? "Back" : "Settings") {
                    withAnimation { showSettings.toggle() }
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 280)
    }

    @ViewBuilder
    private var sessionList: some View {
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
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}
