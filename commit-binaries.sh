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

function display_center_msg {
    local line_length="$1"
    local msg="$2"
    local length=${#msg}
    local pad=$(((line_length - length) / 2))

    printf "%0.s " $(seq 1 ${pad})
    printf "${msg}"

    # if line_length is an odd number, add 1 to pad
    if [ $(((pad * 2) + length)) != "${line_length}" ]; then
        pad=$((pad + 1))
    fi

    printf "%0.s " $(seq 1 ${pad})
}

function display_commit_msg_header {
    local path="$1"

    printf "%0.s#" {1..90}
    printf "\n##"
    display_center_msg 86 "COMMIT MESSAGE IN:"
    printf "##\n##"
    display_center_msg 86 "${path}"
    printf "##\n"
    printf "%0.s#" {1..90}
    printf "\n\n"
}

function commit_msg_body {
    local remote_name=$1 && shift
    local projects=("$@")

    local remote_url=""
    local head=""
    local branch=""

    for project in "${projects[@]}"; do
        pushd "${ROOT}/${project}"
        body+="- Project: ${project}:\n"

        remote_url=$(git remote get-url "${remote_name}")
        body+="URL: ${remote_url}\n"

        branch=$(repo --color=never info . 2>&1 | perl -ne 'print "$1" if /^Manifest revision: (.*)/')
        body+="Branch: ${branch}\n"

        head=$(git log --oneline --no-decorate -1)
        body+="HEAD: ${head}\n\n"
        popd
    done

    echo "${body}"
}

function commit_binaries {
    echo "TODO: implement me"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    commit_binaries "$@"
fi
