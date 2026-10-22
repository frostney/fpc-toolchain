#!/bin/sh
# release-notes.sh TAG — release body.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/toolchain.conf"
tag=$1
id=$(echo "$tag" | sed 's/-b\([0-9][0-9]*\)$/+\1/')
n=$(ls "$here"/patches/*.patch 2>/dev/null | wc -l | tr -d ' ')
cat <<NOTES
FPC $id (\`fpc -iW\`) for Linux, macOS and Windows, with every cross compiler each host can run.

Built from FPC \`$FPC_SOURCE_COMMIT\` with $n patches (\`patches/\`). The \`-source\` archive is the complete source.

GitHub Actions:

    - uses: $TOOLCHAIN_REPO@$tag
      with:
        targets: x86_64-win64   # optional

Linux and macOS:

    curl -fsSLO https://raw.githubusercontent.com/$TOOLCHAIN_REPO/$tag/scripts/install.sh
    sh install.sh $tag

Windows:

    iwr https://raw.githubusercontent.com/$TOOLCHAIN_REPO/$tag/scripts/install.ps1 -OutFile install.ps1
    ./install.ps1 -Identity '$tag'
NOTES
