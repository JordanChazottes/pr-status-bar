import PRStatusCore
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var service: PRService
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Divider()
            footer
        }
        .frame(width: 460)
    }

    @ViewBuilder
    private var content: some View {
        switch service.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding()
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .padding()
        case .loaded(let prs) where prs.isEmpty:
            Text("No open PRs. Go touch grass.").foregroundStyle(.secondary).padding()
        case .loaded(let prs):
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(prs) { pr in
                        Button { openURL(pr.url) } label: { PRRow(pr: pr) }
                            .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 520)
        }
    }

    private var footer: some View {
        HStack {
            if let date = service.lastUpdated {
                Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Refresh") { Task { await service.refresh() } }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(10)
    }
}

private struct PRRow: View {
    let pr: PullRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: pr.isReady ? "checkmark.circle.fill" : pr.needsAuthor ? "exclamationmark.circle.fill" : "clock")
                    .foregroundStyle(pr.isReady ? .green : pr.needsAuthor ? .orange : .secondary)
                Text(pr.title).lineLimit(1).font(.system(size: 13, weight: .medium))
            }
            HStack(spacing: 10) {
                Text("\(pr.repo.split(separator: "/").last ?? "")#\(pr.number)")
                    .foregroundStyle(.secondary)
                if pr.isDraft { Badge("Draft", "pencil", .secondary) }
                review
                senior
                if pr.openThreads > 0 { Badge("\(pr.openThreads)", "bubble.left", .orange, help: "Unresolved threads") }
                checks
                if pr.hasConflicts { Badge("Conflicts", "arrow.triangle.merge", .red) }
            }
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var review: some View {
        switch pr.reviewDecision {
        case .approved: Badge("Approved", "hand.thumbsup", .green, help: pr.approvers.joined(separator: ", "))
        case .changesRequested: Badge("Changes", "xmark.octagon", .red, help: pr.changesRequestedBy.joined(separator: ", "))
        case .reviewRequired, nil: Badge("Review", "eye", .secondary, help: pr.approvers.joined(separator: ", "))
        }
    }

    @ViewBuilder private var senior: some View {
        if pr.seniorApproved {
            Badge("Senior", "star.fill", .green, help: pr.seniorApprovers.joined(separator: ", "))
        } else {
            Badge("Senior", "star", .secondary, help: "No Activation Senior Engineer approval yet")
        }
    }

    @ViewBuilder private var checks: some View {
        switch pr.checks {
        case .success: Badge("CI", "checkmark", .green)
        case .failure, .error: Badge("CI", "xmark", .red)
        case .pending, .expected: Badge("CI", "circle.dotted", .yellow)
        case nil: EmptyView()
        }
    }
}

private struct Badge: View {
    let text: String, symbol: String, color: Color, help: String

    init(_ text: String, _ symbol: String, _ color: Color, help: String = "") {
        self.text = text; self.symbol = symbol; self.color = color; self.help = help
    }

    var body: some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(color)
            .help(help)
    }
}
