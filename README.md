# PR Status Bar

Your open GitHub PRs in the macOS menu bar (and the Linux tray, see [Linux](#linux)).

Menu bar reads `ready/total` with a seal when nothing needs you, or
`2✓ 3!` (2 ready, 3 waiting on you) otherwise. The dropdown lists each PR with:

- review decision (approved / changes requested / review required, hover for who)
- Activation Senior Engineers approval (`akeneo/activation-senior-engineers`)
- unresolved review threads
- CI rollup, merge conflicts, draft

**Ready** = not draft, a senior approved, no unresolved threads, CI green, no conflicts.
**Needs you** = changes requested, unresolved threads, conflicts or red CI.

Click a row to open the PR. Polls every 2 minutes.

## Install

```sh
brew tap JordanChazottes/pr-status-bar
brew install --cask pr-status-bar
open -a PRStatusBar
```

Requires an Apple Silicon Mac on macOS 13+. It has no auth of its own: it shells out to
the `gh` CLI (installed by the cask), so `gh auth login` is all it needs.

## Linux

A tray version lives in `linux/`: Python + GTK3 AppIndicator, same query, same ready and
needs-you rules. It works anywhere that shows AppIndicator / StatusNotifierItem icons: KDE,
XFCE, Cinnamon, Waybar's tray, and GNOME with the AppIndicator extension (preinstalled on
Ubuntu; `gnome-shell-extension-appindicator` on Fedora).

```sh
# Debian/Ubuntu (Fedora: python3-gobject libayatana-appindicator-gtk3,
# Arch: python-gobject libayatana-appindicator)
sudo apt install python3-gi gir1.2-ayatanaappindicator3-0.1 gh
gh auth login
./linux/install.sh            # installs to ~/.local, autostarts on login, launches
./linux/install.sh uninstall
```

Tray menus are plain text (no colors, no hover), so each row is a strip of emoji cells
before the title, and a Legend submenu explains them. The `ready/total` label sits next to
the icon on GNOME and Unity; KDE shows only the icon. Tests: `cd linux && python3 -m unittest`.
Team, org and search query live at the top of `linux/pr_status_core.py`.

## Build from source

```sh
./build.sh          # PRStatusBar.app
./build.sh test     # run the checks
./build.sh install  # copy to ~/Applications and launch
```

Plain `swiftc`, no SwiftPM or Xcode: SwiftPM can't link manifests on the macOS 27
Command Line Tools, and the CLT ships without the SwiftUI macro plugin, so avoid
`@State` (and other SwiftUI macros) in views.

Team, org and search query live in `Config` in `Sources/PRStatusCore/GitHubResponse.swift`.

## Release

```sh
./release.sh 0.2.0
```

Builds and tests on this Mac, publishes `PRStatusBar-0.2.0.zip` as a GitHub release and
bumps the cask in [homebrew-pr-status-bar](https://github.com/JordanChazottes/homebrew-pr-status-bar).
The source of that cask lives in `homebrew/Casks/`.

## License

MIT
