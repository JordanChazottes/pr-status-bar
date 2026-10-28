import PRStatusCore
import SwiftUI

@main
struct PRStatusBarApp: App {
    @StateObject private var service: PRService

    init() {
        // MenuBarExtra content only loads on first open, so kick polling off here
        // to keep the menu bar label live from launch.
        let service = PRService()
        _service = StateObject(wrappedValue: service)
        Task { @MainActor in service.start() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(service: service)
        } label: {
            MenuBarLabel(state: service.state)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let state: PRService.State

    var body: some View {
        switch state {
        case .loading:
            Image(systemName: "arrow.triangle.pull")
        case .error:
            Image(systemName: "exclamationmark.triangle")
        case .loaded(let prs):
            let summary = Summary(prs)
            // Menu bar labels drop colors, so the symbol + text carry everything.
            Image(systemName: summary.needsAuthor > 0 ? "arrow.triangle.pull" : "checkmark.seal")
            Text(summary.needsAuthor > 0
                ? "\(summary.ready)✓ \(summary.needsAuthor)!"
                : "\(summary.ready)/\(summary.total)")
                .monospacedDigit()
        }
    }
}
