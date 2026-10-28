#!/usr/bin/env bash
#
# Cuts a release from this Mac: builds the app, publishes it as a GitHub
# release and points the Homebrew cask at it.
#
#   ./release.sh 0.2.0
#
# Uses the gh login of $OWNER without switching the active gh account.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

OWNER=JordanChazottes
REPO="$OWNER/pr-status-bar"
TAP="$OWNER/homebrew-pr-status-bar"
CASK_PATH=Casks/pr-status-bar.rb

VERSION="${1:?usage: ./release.sh <version>, e.g. 0.2.0}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must be x.y.z" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Commit your changes first" >&2; exit 1; }

export GH_TOKEN="$(gh auth token --user "$OWNER")"

./build.sh test
VERSION="$VERSION" ./build.sh

ZIP="PRStatusBar-$VERSION.zip"
ditto -ck --keepParent PRStatusBar.app ".build/$ZIP"
SHA="$(shasum -a 256 ".build/$ZIP" | awk '{print $1}')"

git tag "v$VERSION"
git push "https://github.com/$REPO.git" "v$VERSION"
gh release create "v$VERSION" ".build/$ZIP" --repo "$REPO" --title "v$VERSION" \
    --notes "brew tap $OWNER/pr-status-bar && brew install --cask pr-status-bar"

current="$(gh api "repos/$TAP/contents/$CASK_PATH")"
updated="$(gh api "repos/$TAP/contents/$CASK_PATH" -H "Accept: application/vnd.github.raw" \
    | sed -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/")"
gh api -X PUT "repos/$TAP/contents/$CASK_PATH" \
    -f message="pr-status-bar $VERSION" \
    -f content="$(printf '%s\n' "$updated" | base64)" \
    -f sha="$(jq -r .sha <<<"$current")" >/dev/null

echo "✅ Released v$VERSION (sha256 $SHA)"
