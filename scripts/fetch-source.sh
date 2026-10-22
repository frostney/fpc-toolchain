#!/usr/bin/env bash
# fetch-source.sh VERSION DEST
#
# Produce the exact FPC source tree this repository builds:
#   FPC_SOURCE_URL @ FPC_SOURCE_COMMIT (shallow fetch by SHA)
#   + the carried patch series (FPC_PATCH_DIR, applied with `git am` in name order)
#     or, with FPC_PATCH_GIT=<url>#<ref>, the commits of <ref> on top of FPC_SOURCE_COMMIT.
# Verifies FPC_EXPECT_TREE when set and writes DEST/.fpc-toolchain-source (provenance record).
#
# Settings come from toolchain.conf; any of them can be overridden from the environment.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
ver=${1:?usage: fetch-source.sh VERSION DEST}; dest=${2:?usage: fetch-source.sh VERSION DEST}

env_url=${FPC_SOURCE_URL-}; env_commit=${FPC_SOURCE_COMMIT-}; env_pdir=${FPC_PATCH_DIR-}
env_pgit=${FPC_PATCH_GIT-}; env_tree=${FPC_EXPECT_TREE-unset}
# shellcheck source=/dev/null
. "$here/scripts/lib.sh"
load_version "$ver"
FPC_SOURCE_URL=${env_url:-$FPC_SOURCE_URL}
FPC_SOURCE_COMMIT=${env_commit:-$FPC_SOURCE_COMMIT}
FPC_PATCH_DIR=${env_pdir:-$FPC_PATCH_DIR}
FPC_PATCH_GIT=${env_pgit:-${FPC_PATCH_GIT-}}
[ "$env_tree" != unset ] && FPC_EXPECT_TREE=$env_tree
case $FPC_PATCH_DIR in /*) ;; *) FPC_PATCH_DIR=$vdir/$FPC_PATCH_DIR ;; esac

if [ -e "$dest" ]; then
  echo "fetch-source: $dest exists; remove it first" >&2; exit 1
fi
mkdir -p "$dest"
cd "$dest"
git init -q
git config core.autocrlf false
git config advice.detachedHead false
# Fixed identity: the commit SHAs of applied patches are not part of the contract (the tree is).
export GIT_COMMITTER_NAME=fpc-toolchain GIT_COMMITTER_EMAIL=fpc-toolchain@localhost
git remote add origin "$FPC_SOURCE_URL"
git fetch -q --depth 1 origin "$FPC_SOURCE_COMMIT"
git checkout -q FETCH_HEAD

series=none
if [ -n "$FPC_PATCH_GIT" ]; then
  url=${FPC_PATCH_GIT%%#*}; ref=${FPC_PATCH_GIT#*#}
  git fetch -q --shallow-exclude="$FPC_SOURCE_COMMIT" "$url" "$ref" 2>/dev/null \
    || git fetch -q "$url" "$ref"
  head=$(git rev-parse FETCH_HEAD)
  git -c advice.detachedHead=false checkout -q "$head"
  # Accept only a ref whose history contains the base.
  git merge-base --is-ancestor "$FPC_SOURCE_COMMIT" HEAD 2>/dev/null \
    || { echo "fetch-source: $ref does not contain $FPC_SOURCE_COMMIT" >&2; exit 1; }
  series="git:$url#$ref@$head ($(git rev-list --count "$FPC_SOURCE_COMMIT"..HEAD) commits)"
else
  shopt -s nullglob
  patches=("$FPC_PATCH_DIR"/*.patch)
  if [ ${#patches[@]} -gt 0 ]; then
    git am -q --keep-cr --committer-date-is-author-date "${patches[@]}"
    series="dir:$(basename "$FPC_PATCH_DIR") ${#patches[@]} patches sha256:$(cat "${patches[@]}" | sha256sum | cut -c1-16)"
  fi
fi

tree=$(git rev-parse 'HEAD^{tree}')
if [ -n "${FPC_EXPECT_TREE:-}" ] && [ "$tree" != "$FPC_EXPECT_TREE" ]; then
  echo "fetch-source: tree $tree != expected $FPC_EXPECT_TREE" >&2; exit 1
fi
{
  echo "source_url=$FPC_SOURCE_URL"
  echo "source_commit=$FPC_SOURCE_COMMIT"
  echo "series=$series"
  echo "tree=$tree"
} > .fpc-toolchain-source
cat .fpc-toolchain-source
