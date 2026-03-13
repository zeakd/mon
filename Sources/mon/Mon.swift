import Foundation
import MonitorKit

@main
struct Mon {
    static func main() {
        let args = CommandLine.arguments
        let command = args.count > 1 ? args[1] : "help"

        do {
            let store = try SessionStore()

            switch command {
            case "start":
                guard args.count > 2 else {
                    printErr("usage: mon start <title> [--focus auto|<command>]")
                    exit(1)
                }
                var (title, focusCmd) = parseStart(Array(args[2...]))
                if focusCmd == "auto" {
                    focusCmd = detectFocusCommand()
                }
                let id = try store.start(title: title, focusCommand: focusCmd)
                print(id)

            case "ping":
                guard args.count > 2 else {
                    printErr("usage: mon ping <id>")
                    exit(1)
                }
                try store.ping(args[2])

            case "end":
                guard args.count > 2 else {
                    printErr("usage: mon end <id>")
                    exit(1)
                }
                try store.end(args[2])

            case "ls":
                let sessions = try store.list()
                if sessions.isEmpty {
                    print("no active sessions")
                } else {
                    let timeout: TimeInterval = 30
                    for s in sessions {
                        let status = s.isActive(timeout: timeout) ? "●" : "○"
                        let ago = Int(Date().timeIntervalSince(s.updatedAt))
                        let focus = s.canFocus ? " [focus]" : ""
                        print("\(status) \(s.id.prefix(8))  \(s.title)  (\(s.machine), \(ago)s ago)\(focus)")
                    }
                }

            case "prune":
                try store.prune()
                print("pruned stale sessions")

            default:
                printHelp()
            }
        } catch {
            printErr("error: \(error.localizedDescription)")
            exit(1)
        }
    }

    /// "title words --focus some command" → ("title words", "some command")
    static func parseStart(_ args: [String]) -> (title: String, focusCmd: String?) {
        if let idx = args.firstIndex(of: "--focus") {
            let titleParts = args[..<idx]
            let focusParts = args[(idx + 1)...]
            return (titleParts.joined(separator: " "), focusParts.joined(separator: " "))
        }
        return (args.joined(separator: " "), nil)
    }

    /// 현재 터미널 환경을 감지하여 포커스 커맨드 생성
    static func detectFocusCommand() -> String? {
        let env = ProcessInfo.processInfo.environment

        // 1. tmux — 가장 정확한 포커스
        if let _ = env["TMUX"], let pane = env["TMUX_PANE"] {
            return "tmux select-pane -t \(pane) && tmux select-window -t \(pane)"
        }

        // 2. iTerm2 — ITERM_SESSION_ID로 특정 탭 포커스
        if let sessionId = env["ITERM_SESSION_ID"] {
            // iTerm2 AppleScript로 특정 세션 포커스
            let script = """
                tell application "iTerm2"
                    activate
                    repeat with w in windows
                        repeat with t in tabs of w
                            repeat with s in sessions of t
                                if unique ID of s is "\(sessionId)" then
                                    select t
                                    select w
                                    return
                                end if
                            end repeat
                        end repeat
                    end repeat
                end tell
                """
            return "osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'"
        }

        // 3. Terminal.app — tty로 특정 탭 포커스
        if let tty = ttyName() {
            let script = """
                tell application "Terminal"
                    activate
                    repeat with w in windows
                        repeat with t in tabs of w
                            if tty of t is "\(tty)" then
                                set selected tab of w to t
                                set index of w to 1
                                return
                            end if
                        end repeat
                    end repeat
                end tell
                """
            return "osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'"
        }

        // 4. fallback — 감지 실패
        return nil
    }

    /// 현재 tty 이름 반환 (/dev/ttys003 등)
    static func ttyName() -> String? {
        if isatty(STDIN_FILENO) != 0 {
            return String(cString: ttyname(STDIN_FILENO))
        }
        return nil
    }

    static func printHelp() {
        print("""
        mon — session monitor CLI

        usage:
          mon start <title> [--focus auto|<cmd>]  register session, prints id
          mon ping <id>                           heartbeat
          mon end <id>                            end session
          mon ls                                  list sessions
          mon prune                               remove stale (>24h)

        focus:
          --focus auto   auto-detect terminal (tmux/iTerm2/Terminal.app)
          --focus <cmd>  custom shell command to run on click
        """)
    }

    static func printErr(_ msg: String) {
        FileHandle.standardError.write(Data((msg + "\n").utf8))
    }
}
