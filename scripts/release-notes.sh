#!/bin/sh
# release-notes.sh TAG — release body.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
tag=${1:?usage: release-notes.sh TAG}
vdir=$here/versions/${tag%%[-+]*}
. "$vdir/toolchain.conf"
id=$(echo "$tag" | sed 's/-b\([0-9][0-9]*\)$/+\1/')
n=$(find "$vdir/patches" -name '*.patch' | wc -l | tr -d ' ')
cat <<NOTES
FPC $id (\`fpc -iW\`) for Linux, macOS and Windows, with every cross compiler each host can build from free tools.
Targets per host: [MATRIX.md](https://github.com/$TOOLCHAIN_REPO/blob/$tag/versions/$FPC_VERSION/MATRIX.md).

Built from FPC \`$FPC_SOURCE_COMMIT\` with $n patches (\`versions/$FPC_VERSION/patches/\`). The \`-source\` archive is
the complete source; \`binutils-2.42.tar.xz\` is the source of the GNU binutils in each host archive.

GitHub Actions:

    - uses: $TOOLCHAIN_REPO@v1
      with:
        version: $tag
        targets: x86_64-win64   # optional

Linux and macOS:

    curl -fsSLO https://raw.githubusercontent.com/$TOOLCHAIN_REPO/$tag/scripts/install.sh
    sh install.sh $tag

Windows:

    iwr https://raw.githubusercontent.com/$TOOLCHAIN_REPO/$tag/scripts/install.ps1 -OutFile install.ps1
    ./install.ps1 -Identity '$tag'
NOTES
