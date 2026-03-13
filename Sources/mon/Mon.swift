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
                    printErr("usage: mon start <title> [--focus <command>]")
                    exit(1)
                }
                let (title, focusCmd) = parseStart(Array(args[2...]))
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

    static func printHelp() {
        print("""
        mon — session monitor CLI

        usage:
          mon start <title> [--focus <cmd>]  register session, prints id
          mon ping <id>                      heartbeat
          mon end <id>                       end session
          mon ls                             list sessions
          mon prune                          remove stale (>24h)

        focus:
          --focus <cmd>  shell command to run when session is clicked
                         e.g. --focus "osascript -e 'tell app \\"Terminal\\" to activate'"
        """)
    }

    static func printErr(_ msg: String) {
        FileHandle.standardError.write(Data((msg + "\n").utf8))
    }
}
