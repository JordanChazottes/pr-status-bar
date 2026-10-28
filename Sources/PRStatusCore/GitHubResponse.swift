import Foundation

public enum Config {
    public static let seniorTeamOrg = "akeneo"
    public static let seniorTeamSlug = "activation-senior-engineers"
    public static let searchQuery = "is:pr is:open author:@me archived:false"

    public static let graphQL = """
    query {
      organization(login: "\(seniorTeamOrg)") {
        team(slug: "\(seniorTeamSlug)") { members(first: 100) { nodes { login } } }
      }
      search(query: "\(searchQuery)", type: ISSUE, first: 50) {
        nodes {
          ... on PullRequest {
            number title url isDraft reviewDecision mergeable
            repository { nameWithOwner }
            latestOpinionatedReviews(first: 50) { nodes { state author { login } } }
            reviewThreads(first: 100) { nodes { isResolved } }
            commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
          }
        }
      }
    }
    """
}

private struct Nodes<T: Decodable>: Decodable { let nodes: [T] }
private struct Login: Decodable { let login: String }

private struct Response: Decodable {
    struct DataField: Decodable {
        struct Org: Decodable {
            struct Team: Decodable { let members: Nodes<Login> }
            let team: Team?
        }
        let organization: Org?
        let search: Nodes<RawPR>
    }
    let data: DataField
}

private struct RawPR: Decodable {
    struct Repo: Decodable { let nameWithOwner: String }
    struct Review: Decodable { let state: String; let author: Login? }
    struct Thread: Decodable { let isResolved: Bool }
    struct Commit: Decodable {
        struct Inner: Decodable {
            struct Rollup: Decodable { let state: ChecksState }
            let statusCheckRollup: Rollup?
        }
        let commit: Inner
    }

    let number: Int
    let title: String
    let url: URL
    let isDraft: Bool
    let reviewDecision: ReviewDecision?
    let mergeable: String
    let repository: Repo
    let latestOpinionatedReviews: Nodes<Review>
    let reviewThreads: Nodes<Thread>
    let commits: Nodes<Commit>
}

public enum GitHubResponse {
    public static func parse(_ data: Data) throws -> [PullRequest] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let seniors = Set(response.data.organization?.team?.members.nodes.map(\.login) ?? [])

        return response.data.search.nodes.map { raw in
            let reviews = raw.latestOpinionatedReviews.nodes
            let logins = { (state: String) in reviews.filter { $0.state == state }.compactMap(\.author?.login) }
            let approvers = logins("APPROVED")
            return PullRequest(
                repo: raw.repository.nameWithOwner,
                number: raw.number,
                title: raw.title,
                url: raw.url,
                isDraft: raw.isDraft,
                reviewDecision: raw.reviewDecision,
                hasConflicts: raw.mergeable == "CONFLICTING",
                approvers: approvers,
                changesRequestedBy: logins("CHANGES_REQUESTED"),
                openThreads: raw.reviewThreads.nodes.filter { !$0.isResolved }.count,
                checks: raw.commits.nodes.first?.commit.statusCheckRollup?.state,
                seniorApprovers: approvers.filter(seniors.contains)
            )
        }
    }
}
