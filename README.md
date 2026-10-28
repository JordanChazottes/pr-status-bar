# PR Status Bar

Your open GitHub PRs in the macOS menu bar, inspired by
[claude-usage-bar](https://github.com/sdelanos/claude-usage-bar).

Menu bar reads `ready/total` with a seal when nothing needs you, or
`2✓ 3!` (2 ready, 3 waiting on you) otherwise. The dropdown lists each PR with:

- review decision (approved / changes requested / review required, hover for who)
- Activation Senior Engineers approval (`akeneo/activation-senior-engineers`)
- unresolved review threads
- CI rollup, merge conflicts, draft

**Ready** = not draft, a senior approved, no unresolved threads, CI green, no conflicts.
**Needs you** = changes requested, unresolved threads, conflicts or red CI.

Click a row to open the PR. Polls every 2 minutes.

## Auth

None of its own: it shells out to the `gh` CLI, so `gh auth login` is all it needs.

## Build

```sh
./build.sh          # PRStatusBar.app
./build.sh test     # run the checks
./build.sh install  # copy to ~/Applications and launch
```

Plain `swiftc`, no SwiftPM or Xcode: SwiftPM can't link manifests on the macOS 27
Command Line Tools, and the CLT ships without the SwiftUI macro plugin, so avoid
`@State` (and other SwiftUI macros) in views.

Team, org and search query live in `Config` in `Sources/PRStatusCore/GitHubResponse.swift`.
