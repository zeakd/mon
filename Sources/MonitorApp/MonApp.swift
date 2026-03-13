import SwiftUI
import AppKit
import MonitorKit

@main
struct MonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 빈 Scene — 실제 UI는 AppDelegate에서 NSStatusItem으로 관리
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var animator: InkAnimator!
    private var viewModel: MonViewModel!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = MonViewModel()
        animator = InkAnimator(retina: NSScreen.main?.backingScaleFactor ?? 1 > 1)

        // Status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "drop", accessibilityDescription: "Mon")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Popover (왼클릭)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 300)
        popover.behavior = .transient
        popover.delegate = self
        updatePopoverContent(showSettings: false)

        // 세션 변경 감시 → 잉크 업데이트
        startSessionWatch()

        // 바깥 클릭 시 popover 닫기
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // 우클릭 → 컨텍스트 메뉴
            showContextMenu()
        } else {
            // 왼클릭 → popover 토글
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            updatePopoverContent(showSettings: false)
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mon", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // 메뉴 표시 후 nil로 돌려야 다음 클릭이 정상 동작
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    @objc private func openSettings() {
        updatePopoverContent(showSettings: true)
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func updatePopoverContent(showSettings: Bool) {
        let view: AnyView
        if showSettings {
            view = AnyView(SettingsView().padding(.top, 4))
        } else {
            view = AnyView(SessionPopoverView(viewModel: viewModel))
        }
        popover.contentViewController = NSHostingController(rootView: view)
    }

    private func startSessionWatch() {
        // 타이머로 세션 변경 감시 + 잉크 이미지 업데이트
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.animator.updateSessions(self.viewModel.sessions, idleTimeout: self.viewModel.idleTimeout)
                if let image = self.animator.currentImage, !self.viewModel.sessions.isEmpty {
                    self.statusItem.button?.image = image
                } else if self.viewModel.sessions.isEmpty {
                    self.statusItem.button?.image = NSImage(systemSymbolName: "drop", accessibilityDescription: "Mon")
                }
            }
        }
    }
}
