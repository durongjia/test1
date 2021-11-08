#!/bin/bash
set -e
set -u
set -o pipefail

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/build_all.sh"

PROJECTS_AIOT=("arm-trusted-firmware" "arm-trusted-firmware-mt8516"
               "libdram" "lk" "optee-os" "u-boot" "build")

function check_local_changes {
    local PROJECTS=($@)

    for PROJECT in "${PROJECTS[@]}"; do
        pushd "${ROOT}/${PROJECT}"
        if ! $(git diff-index --quiet HEAD); then
            echo "Local changes detected in: ${PROJECT}"
            exit 1
        fi
        popd
    done
}

function display_center_msg {
    local line_length="$1"
    local msg="$2"
    local length=${#msg}
    local pad=$(((line_length-length)/2))

    printf "%0.s " $(seq 1 $pad)
    printf "${msg}"

    # if line_length is an odd number, add 1 to pad
    if [ $(((pad*2)+length)) != $line_length ]; then
        pad=$((pad+1))
    fi

    printf "%0.s " $(seq 1 $pad)
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
    local REMOTE_NAME=$1 && shift
    local PROJECTS=($@)

    local REMOTE_URL
    local HEAD
    local BRANCH

    local BODY="This update contains following changes:\nXXXX\n\n"

    for PROJECT in "${PROJECTS[@]}"; do
        pushd "${ROOT}/${PROJECT}"
        BODY+="- Project: ${PROJECT}:\n"

        REMOTE_URL=$(git remote get-url ${REMOTE_NAME})
        BODY+="URL: ${REMOTE_URL}\n"

        BRANCH=$(repo info . 2>&1 | perl -ne 'print "$1" if /^Manifest revision: (.*)/')
        BODY+="Branch: ${BRANCH}\n"

        HEAD=$(git log --oneline --no-decorate -1)
        BODY+="HEAD: ${HEAD}\n\n"
        popd
    done

    echo $BODY
}

function add_commit_msg {
    local -n commits_msg_ref="$1"
    local MTK_CONFIG="$2"
    local MTK_ANDROID_OUT="$3"
    local toplevel
    local commits_msg_value

    # MTK_CONFIG: keep only basename without extension
    MTK_CONFIG=$(basename "$2")
    MTK_CONFIG="${MTK_CONFIG%.*}"

    pushd "${MTK_ANDROID_OUT}"
    toplevel=$(git rev-parse --sq --show-toplevel)
    if [[ -v "commits_msg_ref[${toplevel}]" ]] ; then
        commits_msg_value="${commits_msg_ref[${toplevel}]}"
        if ! [[ "$commits_msg_value" =~ "${MTK_CONFIG}" ]]; then
            unset commits_msg_ref[${toplevel}]
            commits_msg_ref+=(["${toplevel}"]="${commits_msg_value}/${MTK_CONFIG}")
        fi
    else
        commits_msg_ref+=(["${toplevel}"]="${MTK_CONFIG}")
    fi
    popd
}

function copy_binaries {
    local MTK_OUT="$1"
    local MTK_ANDROID_OUT="$2"
    local MODE=$4
    local BINARIES=("bl2-${MODE}.img" "fip_${MODE}_ab.bin" "fip_${MODE}_noab.bin" "lk-${MODE}.bin"
                    "u-boot-initial-${MODE}-env_ab" "u-boot-initial-${MODE}-env_noab")

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
  --commit   (OPTIONAL) commit binaries in AOSP
DELIM__
    exit 1
}

function main {
    local aosp
    local commit=false
    local mode_list=(
        debug
        release
        )
    local OPTS=$(getopt -o '' -l aosp:,commit -- "$@")
    eval set -- "${OPTS}"

    while true; do
        case "$1" in
            --aosp) aosp=$(readlink -e "$2"); shift 2 ;;
            --commit) commit=true; shift ;;
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
    declare -A commits_msg

    check_local_changes "${PROJECTS_AIOT[@]}"

    pushd "${SRC}"
    for MODE in "${mode_list[@]}"; do
        echo "----------------> Build: ${MODE} <----------------"
        for MTK_CONFIG in $(ls config/boards/*.yaml); do
            MTK_PLAT=$(config_value "${MTK_CONFIG}" plat)
            MTK_BINARIES_PATH=$(config_value "${MTK_CONFIG}" android.binaries_path)
            OUT_DIR=$(out_dir "${MTK_CONFIG}" "${MODE}")

            echo "-> Build: ${MTK_CONFIG}"
            build_all "${MTK_CONFIG}" "true" "${MODE}"
            if [ -d "${aosp}/${MTK_BINARIES_PATH}" ]; then
                copy_binaries "${OUT_DIR}/" "${aosp}/${MTK_BINARIES_PATH}" "${MTK_CONFIG}" "${MODE}"
                add_commit_msg commits_msg "${MTK_CONFIG}" "${aosp}/${MTK_BINARIES_PATH}"
            else
                echo "ERROR: cannot copy binaries, ${aosp}/${MTK_BINARIES_PATH} not found"
                exit 1
            fi
        done
    done
    popd

    # commits message
    local commit_body=$(commit_msg_body "aiot" "${PROJECTS_AIOT[@]}")
    local commit_title
    local commit_msg
    for path in "${!commits_msg[@]}"; do
        pushd "${path}"

        # display commit
        display_commit_msg_header "${path}"
        commit_title="${commits_msg[$path]}: update binaries\n\n"
        commit_msg=$(echo -e "${commit_title}${commit_body}")
        echo "${commit_msg}"

        if [[ "${commit}" == true ]]; then
            git add --all
            git commit --quiet -s -m "${commit_msg}"
        fi
        popd
    done
}

main "$@"
