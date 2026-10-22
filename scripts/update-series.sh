#!/usr/bin/env bash
# update-series.sh <git-url>#<ref> — replace patches/ with the commits of <ref> on top of FPC_SOURCE_COMMIT
# and pin the resulting tree in toolchain.conf (FPC_EXPECT_TREE). After it: review `git diff`, commit, and
# tag the next build (<version>-b<N+1>); the build workflow does the rest.
#
#   scripts/update-series.sh /path/to/fpcsrc#patched-trunk
#   scripts/update-series.sh https://example.org/fpc.git#my-branch
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=/dev/null
. "$here/toolchain.conf"
spec=${1:?usage: update-series.sh <git-url>#<ref>}
url=${spec%%#*}; ref=${spec#*#}
case $url in /*) url=file://$url ;; esac

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q
git -C "$tmp" fetch -q --depth 1 "$FPC_SOURCE_URL" "$FPC_SOURCE_COMMIT"
git -C "$tmp" fetch -q --shallow-exclude="$FPC_SOURCE_COMMIT" "$url" "$ref" 2>/dev/null \
  || git -C "$tmp" fetch -q "$url" "$ref"
head=$(git -C "$tmp" rev-parse FETCH_HEAD)
git -C "$tmp" merge-base --is-ancestor "$FPC_SOURCE_COMMIT" "$head" \
  || { echo "update-series: $ref does not contain $FPC_SOURCE_COMMIT" >&2; exit 1; }
n=$(git -C "$tmp" rev-list --count "$FPC_SOURCE_COMMIT..$head")
tree=$(git -C "$tmp" rev-parse "$head^{tree}")

rm -f "$here"/patches/*.patch
git -C "$tmp" format-patch -q --no-signature --zero-commit -o "$here/patches" "$FPC_SOURCE_COMMIT..$head"
# our own patches carry SERIES_AUTHOR (toolchain.conf); upstream authors stay as they are
if [ -n "${SERIES_AUTHOR:-}" ]; then
  name=${SERIES_AUTHOR%% <*}
  for f in "$here"/patches/*.patch; do
    sed "s|^From: $name <[^>]*>\$|From: $SERIES_AUTHOR|" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
fi
sed -i.bak "s/^FPC_EXPECT_TREE=.*/FPC_EXPECT_TREE=$tree/" "$here/toolchain.conf" && rm -f "$here/toolchain.conf.bak"
echo "patches/: $n patches from $ref@$head; FPC_EXPECT_TREE=$tree"
