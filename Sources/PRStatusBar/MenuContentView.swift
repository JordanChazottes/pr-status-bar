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
        .frame(width: 760)
        .fixedSize(horizontal: false, vertical: true)
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
            PRHeader()
            Divider()
            // A ScrollView has no ideal height, so a MenuBarExtra window collapses
            // it to zero. Only scroll when the rows outgrow the cap, at a fixed height.
            if CGFloat(prs.count) * PRRow.height > Self.maxListHeight {
                ScrollView { rows(prs) }.frame(height: Self.maxListHeight)
            } else {
                rows(prs)
            }
        }
    }

    private static let maxListHeight: CGFloat = 520

    private func rows(_ prs: [PullRequest]) -> some View {
        VStack(spacing: 0) {
            ForEach(prs) { pr in
                Button { openURL(pr.url) } label: { PRRow(pr: pr) }
                    .buttonStyle(.plain)
            }
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

private enum Column {
    static let number: CGFloat = 52
    static let cell: CGFloat = 46
}

struct PRHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 14, height: 1)
            Text("PR").frame(width: Column.number, alignment: .leading)
            Text("Title").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(["Review", "Senior", "Threads", "CI", "Merge"], id: \.self) {
                Text($0).frame(width: Column.cell)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private struct PRRow: View {
    static let height: CGFloat = 28

    let pr: PullRequest

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: pr.isReady ? "checkmark.circle.fill" : pr.needsAuthor ? "exclamationmark.circle.fill" : "clock")
                .foregroundStyle(pr.isReady ? .green : pr.needsAuthor ? .orange : .secondary)
                .frame(width: 14)
            Text("#" + String(pr.number))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: Column.number, alignment: .leading)
                .help(pr.repo)
            Text(pr.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(pr.title)
            review
            senior
            Cell(pr.openThreads > 0 ? "bubble.left.fill" : "bubble.left", pr.openThreads > 0 ? .orange : .secondary,
                 text: pr.openThreads > 0 ? "\(pr.openThreads)" : nil, help: "\(pr.openThreads) unresolved thread(s)")
            checks
            merge
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
        .overlay(alignment: .bottom) { Color(nsColor: .separatorColor).frame(height: 1) }
        .contentShape(Rectangle())
    }

    @ViewBuilder private var review: some View {
        switch pr.reviewDecision {
        case .approved: Cell("hand.thumbsup.fill", .green, help: "Approved by \(pr.approvers.joined(separator: ", "))")
        case .changesRequested: Cell("xmark.octagon.fill", .red, help: "Changes requested by \(pr.changesRequestedBy.joined(separator: ", "))")
        case .reviewRequired, nil:
            Cell("eye", .secondary, help: pr.approvers.isEmpty ? "Review required" : "Review required, approved by \(pr.approvers.joined(separator: ", "))")
        }
    }

    @ViewBuilder private var senior: some View {
        if pr.seniorApproved {
            Cell("star.fill", .green, help: "Senior approval: \(pr.seniorApprovers.joined(separator: ", "))")
        } else {
            Cell("star", .secondary, help: "No Activation Senior Engineer approval yet")
        }
    }

    @ViewBuilder private var checks: some View {
        switch pr.checks {
        case .success: Cell("checkmark.circle.fill", .green, help: "CI passing")
        case .failure, .error: Cell("xmark.circle.fill", .red, help: "CI failing")
        case .pending, .expected: Cell("circle.dotted", .yellow, help: "CI running")
        case nil: Cell("minus", .secondary, help: "No CI")
        }
    }

    @ViewBuilder private var merge: some View {
        if pr.isDraft {
            Cell("pencil", .secondary, help: "Draft")
        } else if pr.hasConflicts {
            Cell("arrow.triangle.merge", .red, help: "Merge conflicts")
        } else {
            Cell("arrow.triangle.merge", .green, help: "No conflicts")
        }
    }
}

private struct Cell: View {
    let symbol: String, color: Color, text: String?, help: String

    init(_ symbol: String, _ color: Color, text: String? = nil, help: String) {
        self.symbol = symbol; self.color = color; self.text = text; self.help = help
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
            if let text { Text(text).monospacedDigit() }
        }
        .foregroundStyle(color)
        .frame(width: Column.cell)
        .help(help)
    }
}
