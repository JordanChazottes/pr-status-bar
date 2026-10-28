"""Port of Tests/main.swift. Run with: python3 -m unittest (from linux/)."""
import json
import unittest

from pr_status_core import Summary, parse

SENIOR = [{"state": "APPROVED", "author": {"login": "senior"}}]


def pr(reviews, threads=(), decision="APPROVED", mergeable="MERGEABLE", checks="SUCCESS", number=1):
    return {
        "number": number, "title": "t", "url": f"https://github.com/o/r/pull/{number}", "isDraft": False,
        "reviewDecision": decision, "mergeable": mergeable,
        "repository": {"nameWithOwner": "o/r"},
        "latestOpinionatedReviews": {"nodes": list(reviews)},
        "reviewThreads": {"nodes": list(threads)},
        "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": checks}}}]},
    }


def parse_nodes(*nodes):
    return parse(json.dumps({"data": {
        "organization": {"team": {"members": {"nodes": [{"login": "senior"}]}}},
        "search": {"nodes": list(nodes)},
    }}))


class ParseTest(unittest.TestCase):
    def test_senior_approved_green_pr_is_ready(self):
        [p] = parse_nodes(pr(SENIOR))
        self.assertEqual(p.senior_approvers, ("senior",))
        self.assertTrue(p.is_ready)
        self.assertFalse(p.needs_author)

    def test_peer_only_approval_is_not_ready(self):
        [p] = parse_nodes(pr([{"state": "APPROVED", "author": {"login": "peer"}}]))
        self.assertEqual(p.approvers, ("peer",))
        self.assertFalse(p.senior_approved)
        self.assertFalse(p.is_ready)

    def test_only_unresolved_threads_count(self):
        [p] = parse_nodes(pr(SENIOR, threads=[{"isResolved": False}, {"isResolved": True}]))
        self.assertEqual(p.open_threads, 1)
        self.assertFalse(p.is_ready)
        self.assertTrue(p.needs_author)

    def test_null_decision_and_conflicts(self):
        [p] = parse_nodes(pr([], decision=None, mergeable="CONFLICTING"))
        self.assertIsNone(p.review_decision)
        self.assertTrue(p.has_conflicts and p.needs_author)

    def test_missing_rollup_means_no_ci(self):
        node = pr(SENIOR)
        node["commits"]["nodes"][0]["commit"]["statusCheckRollup"] = None
        [p] = parse_nodes(node)
        self.assertIsNone(p.checks)
        self.assertFalse(p.is_ready)

    def test_ready_prs_sort_first(self):
        prs = parse_nodes(pr([], number=1), pr(SENIOR, number=2))
        self.assertEqual([p.number for p in prs], [2, 1])


class SummaryTest(unittest.TestCase):
    def test_label(self):
        prs = parse_nodes(pr(SENIOR, number=1), pr([], checks="FAILURE", number=2), pr([], number=3))
        summary = Summary.of(prs)
        self.assertEqual((summary.total, summary.ready, summary.needs_author), (3, 1, 1))
        self.assertEqual(summary.label, "1✓ 1!")
        self.assertEqual(Summary.of(prs[:1]).label, "1/1")


if __name__ == "__main__":
    unittest.main()
