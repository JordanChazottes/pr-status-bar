// Plain-executable tests: SwiftPM and swift-testing don't work with the macOS 27 CLT.
import Foundation
import PRStatusCore

private var failures = 0

private func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition {
        failures += 1
        print("✗ line \(line): \(message)")
    }
}

private func parse(reviews: String, threads: String = "[]", decision: String = "\"APPROVED\"", mergeable: String = "MERGEABLE") -> PullRequest {
    let json = """
    {"data":{
      "organization":{"team":{"members":{"nodes":[{"login":"senior"}]}}},
      "search":{"nodes":[{
        "number":1,"title":"t","url":"https://github.com/o/r/pull/1","isDraft":false,
        "reviewDecision":\(decision),"mergeable":"\(mergeable)",
        "repository":{"nameWithOwner":"o/r"},
        "latestOpinionatedReviews":{"nodes":\(reviews)},
        "reviewThreads":{"nodes":\(threads)},
        "commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}
      }]}
    }}
    """
    return try! GitHubResponse.parse(Data(json.utf8))[0]
}

let senior = #"[{"state":"APPROVED","author":{"login":"senior"}}]"#

do {
    let pr = parse(reviews: senior)
    check(pr.seniorApprovers == ["senior"], "senior approver detected")
    check(pr.isReady, "senior-approved green PR is ready")
    check(!pr.needsAuthor, "ready PR doesn't need the author")
}

do {
    let pr = parse(reviews: #"[{"state":"APPROVED","author":{"login":"peer"}}]"#)
    check(pr.approvers == ["peer"], "peer approver listed")
    check(!pr.seniorApproved, "peer is not a senior")
    check(!pr.isReady, "peer-only approval is not ready")
}

do {
    let pr = parse(reviews: senior, threads: #"[{"isResolved":false},{"isResolved":true}]"#)
    check(pr.openThreads == 1, "only unresolved threads count")
    check(!pr.isReady && pr.needsAuthor, "open thread blocks and needs the author")
}

do {
    let pr = parse(reviews: "[]", decision: "null", mergeable: "CONFLICTING")
    check(pr.reviewDecision == nil, "null review decision parses")
    check(pr.hasConflicts && pr.needsAuthor, "conflicts need the author")
}

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("✓ all checks passed")
