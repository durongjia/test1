#!/bin/bash
set -e
set -u
set -o pipefail

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/build_all.sh"

PROJECTS_AIOT=("arm-trusted-firmware" "arm-trusted-firmware-mt8516"
               "libdram" "lk" "optee-os" "u-boot")
PROJECTS_RICH_IOT=("build")

function check_local_changes {
    local STATUS

    for PROJECT in "${PROJECTS[@]}"; do
        pushd "${ROOT}/${PROJECT}"
        if ! $(git diff-index --quiet HEAD); then
            echo "Local changes detected in: ${PROJECT}"
            exit 1
        fi
        popd
    done
}

function display_commit_msg_header {
    printf "%0.s#" {1..80}
    printf "\n######"
    printf "%0.s " {1..27}
    printf "COMMIT MESSAGE"
    printf "%0.s " {1..27}
    printf "######\n"
    printf "%0.s#" {1..80}
    printf "\n\n"
}

function display_commit_msg {
    local REMOTE_NAME=$1 && shift
    local PROJECTS=($@)

    local REMOTE_URL
    local HEAD
    local BRANCH
    for PROJECT in "${PROJECTS[@]}"; do
        pushd "${ROOT}/${PROJECT}"
        printf "%s Project: ${PROJECT}:\n" "-"

        REMOTE_URL=$(git remote get-url ${REMOTE_NAME})
        printf "URL: ${REMOTE_URL}\n"

        BRANCH=$(repo info . 2>&1 | perl -ne 'print "$1" if /^Manifest revision: (.*)/')
        printf "Branch: ${BRANCH}\n"

        HEAD=$(git log --oneline --no-decorate -1)
        printf "HEAD: ${HEAD}\n\n"
        popd
    done
}

function copy_binaries {
    local MTK_OUT="$1"
    local MTK_ANDROID_OUT="$2"
    local BINARIES=("bl2.img" "fip_ab.bin" "fip_noab.bin" "lk.bin"
                    "u-boot-initial-env_ab" "u-boot-initial-env_noab")

    for BINARY in "${BINARIES[@]}"; do
        cp "${MTK_OUT}${BINARY}" "${MTK_ANDROID_OUT}"
    done
}

function usage {
    cat <<DELIM__
usage: $(basename $0) [options]

$ $(basename $0) --aosp=/home/julien/Documents/mediatek/android

Options:
  --aosp     Android Root path
DELIM__
    exit 1
}

function main {
    local aosp

    local OPTS=$(getopt -o '' -l aosp: -- "$@")
    eval set -- "${OPTS}"

    while true; do
        case "$1" in
            --aosp) aosp=$(readlink -e "$2"); shift 2 ;;
            --) shift; break ;;
            *) usage ;;
        esac
    done

    # check arguments
    [ -z "${aosp}" ] && echo "Cannot find Android Root Path" && usage

    # build all configs
    local MTK_PLAT
    local MTK_BINARIES_PATH
    local OUT_DIR

    check_local_changes

    pushd "${SRC}"
    for MTK_CONFIG in $(ls config/boards/*.yaml); do
        MTK_PLAT=$(config_value "${MTK_CONFIG}" plat)
        MTK_BINARIES_PATH=$(config_value "${MTK_CONFIG}" android.binaries_path)
        OUT_DIR=$(out_dir "${MTK_CONFIG}")

        echo "-> Build: ${MTK_CONFIG}"
        build_all "${MTK_CONFIG}" "true"
        if [ -d "${aosp}/${MTK_BINARIES_PATH}" ]; then
            copy_binaries "${OUT_DIR}/" "${aosp}/${MTK_BINARIES_PATH}"
        else
            echo "ERROR: cannot copy binaries, ${aosp}/${MTK_BINARIES_PATH} not found"
            exit 1
        fi
    done
    popd

    # display commit message
    display_commit_msg_header
    printf "soc: mt8167/mt8183: update binaries\n\n"
    printf "This update contains following changes:\nXXXX\n\n"

    display_commit_msg "aiot" "${PROJECTS_AIOT[@]}"
    display_commit_msg "rich-iot" "${PROJECTS_RICH_IOT[@]}"
}

main "$@"
