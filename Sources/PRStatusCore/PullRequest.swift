import Foundation

public enum ReviewDecision: String, Decodable, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
}

public enum ChecksState: String, Decodable, Sendable {
    case success = "SUCCESS"
    case failure = "FAILURE"
    case error = "ERROR"
    case pending = "PENDING"
    case expected = "EXPECTED"

    public var isFailing: Bool { self == .failure || self == .error }
}

public struct PullRequest: Identifiable, Sendable, Equatable {
    public let repo: String
    public let number: Int
    public let title: String
    public let url: URL
    public let isDraft: Bool
    public let reviewDecision: ReviewDecision?
    public let hasConflicts: Bool
    public let approvers: [String]
    public let changesRequestedBy: [String]
    public let openThreads: Int
    public let checks: ChecksState?
    public let seniorApprovers: [String]

    public var id: String { "\(repo)#\(number)" }
    public var seniorApproved: Bool { !seniorApprovers.isEmpty }

    /// Mergeable as far as people are concerned: a senior signed off, nothing
    /// left to answer, CI green, no conflicts.
    public var isReady: Bool {
        !isDraft
            && reviewDecision != .changesRequested
            && seniorApproved
            && openThreads == 0
            && checks == .success
            && !hasConflicts
    }

    /// Something only the author can unblock.
    public var needsAuthor: Bool {
        !isDraft && (reviewDecision == .changesRequested || openThreads > 0 || hasConflicts || checks?.isFailing == true)
    }
}

public struct Summary: Sendable, Equatable {
    public let total: Int
    public let ready: Int
    public let needsAuthor: Int

    public init(_ prs: [PullRequest]) {
        total = prs.count
        ready = prs.filter(\.isReady).count
        needsAuthor = prs.filter(\.needsAuthor).count
    }
}
