import Foundation
import PRStatusCore

@MainActor
final class PRService: ObservableObject {
    enum State {
        case loading
        case loaded([PullRequest])
        case error(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var lastUpdated: Date?
    private var loop: Task<Void, Never>?

    private static let interval: Duration = .seconds(120)

    func start() {
        guard loop == nil else { return }
        loop = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    func refresh() async {
        do {
            let data = try await GH.run(["api", "graphql", "-f", "query=\(Config.graphQL)"])
            let prs = try GitHubResponse.parse(data)
            state = .loaded(prs.sorted { ($0.isReady ? 0 : 1, $0.number) < ($1.isReady ? 0 : 1, $1.number) })
            lastUpdated = Date()
        } catch {
            state = .error(String(describing: error))
        }
    }
}

/// Shells out to the `gh` CLI so the app reuses the existing login and never stores a token.
enum GH {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    // GUI apps don't inherit the shell PATH.
    private static let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]

    static func run(_ args: [String]) async throws -> Data {
        guard let gh = candidates.first(where: FileManager.default.isExecutableFile) else {
            throw Failure(description: "gh CLI not found. brew install gh && gh auth login")
        }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let out = Pipe(), err = Pipe()
            process.executableURL = URL(fileURLWithPath: gh)
            process.arguments = args
            process.standardOutput = out
            process.standardError = err
            process.terminationHandler = { p in
                let data = out.fileHandleForReading.readDataToEndOfFile()
                if p.terminationStatus == 0 {
                    continuation.resume(returning: data)
                } else {
                    let message = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    continuation.resume(throwing: Failure(description: message.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
