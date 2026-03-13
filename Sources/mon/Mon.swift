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
                    printErr("usage: mon start <title>")
                    exit(1)
                }
                let title = args[2...].joined(separator: " ")
                let id = try store.start(title: title)
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
                        print("\(status) \(s.id.prefix(8))  \(s.title)  (\(s.machine), \(ago)s ago)")
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

    static func printHelp() {
        print("""
        mon — session monitor CLI

        usage:
          mon start <title>    register a session, prints id
          mon ping <id>        heartbeat (update timestamp)
          mon end <id>         end a session
          mon ls               list sessions
          mon prune            remove stale sessions (>24h)
        """)
    }

    static func printErr(_ msg: String) {
        FileHandle.standardError.write(Data((msg + "\n").utf8))
    }
}
