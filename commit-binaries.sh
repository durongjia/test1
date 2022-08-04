#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

function usage {
    cat <<DELIM__
usage: $(basename "$0") [options]

$ $(basename "$0") --from-repo=<repo root directory> --to-repo=<repo root directory> --to-project=<project sub-path>

Options:
  --from-repo     Absolute path to the source repo
  --from-projects (OPTIONAL) space-separated list of relative source projects. Defaults to all
  --to-repo       Absolute path to the destination repo
  --to-project    Relative path in the destination repo where git commit is ran
  --title-prefix  (OPTIONAL) commit message title prefix. Defaults to "generic"
  --dry-run       (OPTIONAL) don't commit, pass --dry-run to git instead
  --help          (OPTIONAL) display usage

Examples:
  $ $(basename "$0") --from-repo=/home/user/src/android-common-kernel --from-projects='common hikey-modules' \\
                       --to-repo=/home/user/src/aosp --to-project=device/amlogic/yukawa-kernel
DELIM__
}

function commit_binaries {
    echo "TODO: implement me"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    commit_binaries "$@"
fi
