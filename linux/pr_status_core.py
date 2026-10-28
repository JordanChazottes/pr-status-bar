"""PR model and GitHub response parsing. No GTK here, so the tests run anywhere.

Mirrors Sources/PRStatusCore: keep the query and the ready rules in sync with it.
"""
from __future__ import annotations

import json
from dataclasses import dataclass

SENIOR_TEAM_ORG = "akeneo"
SENIOR_TEAM_SLUG = "activation-senior-engineers"
SEARCH_QUERY = "is:pr is:open author:@me archived:false"

GRAPHQL = """
query {
  organization(login: "%s") {
    team(slug: "%s") { members(first: 100) { nodes { login } } }
  }
  search(query: "%s", type: ISSUE, first: 50) {
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
""" % (SENIOR_TEAM_ORG, SENIOR_TEAM_SLUG, SEARCH_QUERY)


@dataclass(frozen=True)
class PullRequest:
    repo: str
    number: int
    title: str
    url: str
    is_draft: bool
    review_decision: str | None  # APPROVED, CHANGES_REQUESTED, REVIEW_REQUIRED
    has_conflicts: bool
    approvers: tuple[str, ...]
    changes_requested_by: tuple[str, ...]
    open_threads: int
    checks: str | None  # SUCCESS, FAILURE, ERROR, PENDING, EXPECTED
    senior_approvers: tuple[str, ...]

    @property
    def senior_approved(self) -> bool:
        return bool(self.senior_approvers)

    @property
    def checks_failing(self) -> bool:
        return self.checks in ("FAILURE", "ERROR")

    @property
    def is_ready(self) -> bool:
        """Mergeable as far as people are concerned: a senior signed off, nothing
        left to answer, CI green, no conflicts."""
        return (
            not self.is_draft
            and self.review_decision != "CHANGES_REQUESTED"
            and self.senior_approved
            and self.open_threads == 0
            and self.checks == "SUCCESS"
            and not self.has_conflicts
        )

    @property
    def needs_author(self) -> bool:
        """Something only the author can unblock."""
        return not self.is_draft and (
            self.review_decision == "CHANGES_REQUESTED"
            or self.open_threads > 0
            or self.has_conflicts
            or self.checks_failing
        )


@dataclass(frozen=True)
class Summary:
    total: int
    ready: int
    needs_author: int

    @classmethod
    def of(cls, prs: list[PullRequest]) -> Summary:
        return cls(len(prs), sum(pr.is_ready for pr in prs), sum(pr.needs_author for pr in prs))

    @property
    def label(self) -> str:
        if self.needs_author:
            return f"{self.ready}✓ {self.needs_author}!"
        return f"{self.ready}/{self.total}"


def parse(text: str) -> list[PullRequest]:
    """Ready PRs first, then by number."""
    data = json.loads(text)["data"]
    team = (data.get("organization") or {}).get("team") or {}
    seniors = {m["login"] for m in team.get("members", {}).get("nodes", [])}

    prs = []
    for raw in data["search"]["nodes"]:
        reviews = raw["latestOpinionatedReviews"]["nodes"]

        def logins(state: str) -> tuple[str, ...]:
            return tuple(r["author"]["login"] for r in reviews if r["state"] == state and r.get("author"))

        approvers = logins("APPROVED")
        commit = (raw["commits"]["nodes"] or [{}])[0].get("commit") or {}
        prs.append(
            PullRequest(
                repo=raw["repository"]["nameWithOwner"],
                number=raw["number"],
                title=raw["title"],
                url=raw["url"],
                is_draft=raw["isDraft"],
                review_decision=raw.get("reviewDecision"),
                has_conflicts=raw["mergeable"] == "CONFLICTING",
                approvers=approvers,
                changes_requested_by=logins("CHANGES_REQUESTED"),
                open_threads=sum(not t["isResolved"] for t in raw["reviewThreads"]["nodes"]),
                checks=(commit.get("statusCheckRollup") or {}).get("state"),
                senior_approvers=tuple(a for a in approvers if a in seniors),
            )
        )
    return sorted(prs, key=lambda pr: (not pr.is_ready, pr.number))
