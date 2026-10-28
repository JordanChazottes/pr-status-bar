cask "pr-status-bar" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/JordanChazottes/pr-status-bar/releases/download/v#{version}/PRStatusBar-#{version}.zip"
  name "PR Status Bar"
  desc "Menu bar app showing the review status of your open GitHub pull requests"
  homepage "https://github.com/JordanChazottes/pr-status-bar"

  depends_on arch: :arm64
  depends_on macos: ">= :ventura"
  depends_on formula: "gh"

  app "PRStatusBar.app"

  # Ad-hoc signed, not notarized: drop the quarantine flag so Gatekeeper
  # doesn't block the first launch.
  postflight do
    system_command "/usr/bin/xattr",
                   args:         ["-cr", "#{appdir}/PRStatusBar.app"],
                   must_succeed: false
  end

  uninstall quit: "dev.jordanchazottes.pr-status-bar"

  caveats <<~EOS
    PR Status Bar reads your PRs through the gh CLI. If you haven't yet:

      gh auth login

    Then launch it with:  open -a PRStatusBar
  EOS
end
