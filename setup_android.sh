#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

function usage {
    cat <<DELIM__
usage: $(basename $0) [options]

$ $(basename $0) --aosp=/home/julien/Documents/mediatek/android --branch=jmasson/update-binaries

Options:
  --aosp     Android Root path
  --branch   Branch name
  --clean    (OPTIONAL) clean up AOSP projects
DELIM__
    exit 1
}

function projects_path {
    local -n projects_ref="$1"
    local aosp="$2"
    local MTK_BINARIES_PATH
    local toplevel

    pushd "${SRC}"
    for MTK_CONFIG in $(ls config/boards/*.yaml); do
        MTK_BINARIES_PATH=$(config_value "${MTK_CONFIG}" android.binaries_path)
        pushd "${aosp}/${MTK_BINARIES_PATH}"
        toplevel=$(git rev-parse --sq --show-toplevel)
        if [[ ! " ${projects_ref[*]} " =~ " ${toplevel} " ]]; then
            projects_ref+=("${toplevel}")
        fi
        popd
    done
}

function main {
    local aosp=""
    local branch=""
    local clean=false
    local OPTS=$(getopt -o '' -l aosp:,branch:,clean -- "$@")
    eval set -- "${OPTS}"

    while true; do
        case "$1" in
            --aosp) aosp=$(readlink -e "$2"); shift 2 ;;
            --branch) branch="$2"; shift 2 ;;
            --clean) clean=true; shift ;;
            --) shift; break ;;
            *) usage ;;
        esac
    done

    # check arguments
    [ -z "${aosp}" ] && echo "Cannot find Android Root Path" && usage
    [ -z "${branch}" ] && echo "Please provide branch name" && usage

    declare -a projects
    projects_path projects "${aosp}"
    for project in "${projects[@]}"; do
        pushd "${project}"
        echo "Setup: ${project}"

        # clean up project
        if [[ "${clean}" == true ]]; then
            git clean --quiet -xdf
            git reset --quiet --hard
        fi

        # check local changes
        if ! $(git diff-index --quiet HEAD); then
            echo "error: Local changes detected"
            exit 1
        fi

        # check if branch exist
        if $(git show-ref --quiet "${branch}"); then
            git checkout --quiet --detach
            git branch --quiet -D "${branch}"
        fi

        # detect remote: [aiot|baylibre]
        local remote="aiot"
        local output=$(git remote | grep baylibre)
        [ -n "${output}" ] && remote="baylibre"

        # create branch
        local repo_branch=$(repo info . 2>&1 | perl -ne 'print "$1" if /^Manifest revision: (.*)/')
        git fetch --quiet "${remote}" "${repo_branch}"
        git checkout --quiet "${remote}/${repo_branch}" -b "${branch}"
        popd
    done
}

main "$@"
