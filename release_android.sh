#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/build_all.sh"

PROJECTS_AIOT=("arm-trusted-firmware" "build" "libbase-prebuilts" "libdram"
               "lk" "optee-os" "optee-ta/kmgk" "optee-ta/optee-otp" "u-boot")

function check_local_changes {
    local projects=("$@")

    for project in "${projects[@]}"; do
        pushd "${ROOT}/${project}"
        if ! git diff-index --quiet HEAD; then
            error_exit "Local changes detected in: ${project}"
        fi
        popd
    done
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

    local body="This update contains following changes:\n"
    local commit_changes="${SRC}/.android_commit_changes"
    if [ -f "${commit_changes}" ]; then
        mapfile < "${commit_changes}" lines
        for line in "${lines[@]}"; do
            body+="${line}\n"
        done
    else
        body+="XXXX\n"
    fi

    body+="\n"
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

function add_commit_msg {
    local -n commits_msg_ref="$1"
    local mtk_config="$2"
    local mtk_android_out="$3"
    local toplevel=""
    local commits_msg_value=""

    # mtk_config: keep only basename without extension
    mtk_config=$(basename "$2")
    mtk_config="${mtk_config%.*}"

    pushd "${mtk_android_out}"
    toplevel=$(git rev-parse --sq --show-toplevel)
    if [[ -v "commits_msg_ref[${toplevel}]" ]]; then
        commits_msg_value="${commits_msg_ref[${toplevel}]}"
        if ! [[ ${commits_msg_value} =~ ${mtk_config} ]]; then
            unset commits_msg_ref["${toplevel}"]
            commits_msg_ref+=(["${toplevel}"]="${commits_msg_value}/${mtk_config}")
        fi
    else
        commits_msg_ref+=(["${toplevel}"]="${mtk_config}")
    fi
    popd
}

function usage {
    cat <<DELIM__
usage: $(basename "$0") [options]

$ $(basename "$0") --aosp=/home/julien/Documents/mediatek/android

Options:
  --aosp     Android Root path
  --commit   (OPTIONAL) commit binaries in AOSP
  --config   (OPTIONAL) release ONLY for this board config file
  --help     (OPTIONAL) display usage
  --mode     (OPTIONAL) [release|debug|factory] build only one mode
  --silent   (OPTIONAL) silent build commands
  --skip-ta  (OPTIONAL) skip build Trusted Applications

By default release and debug modes are built.

The changes specified in the commit msg can be read from:
${SRC}/.android_commit_changes
DELIM__
}

function main {
    local aosp=""
    local commit=false
    local config=""
    local silent=false
    local skip_ta=false
    local mode_list=(debug release)

    local opts_args="aosp:,commit,config:,help,mode:,silent,skip-ta"
    local opts=$(getopt -o '' -l "${opts_args}" -- "$@")
    eval set -- "${opts}"

    while true; do
        case "$1" in
            --aosp) aosp=$(find_path "$2"); shift 2 ;;
            --commit) commit=true; shift ;;
            --config)
                config=$(find_path "$2")
                [ -z "${config}" ] && error_usage_exit "Cannot find board config file"
                shift 2 ;;
            --help) usage; exit 0 ;;
            --mode) mode_list=("$2"); shift 2 ;;
            --silent) silent=true; shift ;;
            --skip-ta) skip_ta=true; shift ;;
            --) shift; break ;;
        esac
    done

    # check arguments
    [ -z "${aosp}" ] && error_usage_exit "Cannot find Android Root Path"

    # set configs list
    declare -a configs
    if [ -n "${config}" ]; then
        configs=("${config}")
    else
        configs=("${SRC}"/config/boards/*.yaml)
    fi

    # build configs
    local mtk_binaries_path=""
    local out_dir=""
    declare -A commits_msg

    check_local_changes "${PROJECTS_AIOT[@]}"

    check_env

    pushd "${SRC}"
    for mtk_config in "${configs[@]}"; do
        mtk_binaries_path=$(config_value "${mtk_config}" android.binaries_path)

        for mode in "${mode_list[@]}"; do
            ! [[ " ${MODES[*]} " =~ " ${mode} " ]] && error_usage_exit "${mode} mode not supported"

            if [[ "${silent}" == true ]]; then
                display_current_build "${mtk_config}" "all" "${mode}"
                build_all "${mtk_config}" "true" "${mode}" &> /dev/null
            else
                build_all "${mtk_config}" "true" "${mode}"
            fi

            if [ -d "${aosp}/${mtk_binaries_path}" ]; then
                add_commit_msg commits_msg "${mtk_config}" "${aosp}/${mtk_binaries_path}"
            else
                error_exit "cannot copy binaries, ${aosp}/${mtk_binaries_path} not found"
            fi

            # Trusted Applications
            if [[ "${skip_ta}" == false ]]; then
                if [[ "${silent}" == true ]]; then
                    build_android_ta "${mtk_config}" "true" "${mode}" &> /dev/null
                else
                    build_android_ta "${mtk_config}" "true" "${mode}"
                fi
            fi

            # Copy binaries
            out_dir=$(out_dir "${mtk_config}" "${mode}")
            cp -r "${out_dir}/"* "${aosp}/${mtk_binaries_path}"
        done
    done
    popd

    # commits message
    local commit_body=$(commit_msg_body "aiot" "${PROJECTS_AIOT[@]}")
    local commit_title=""
    local commit_msg=""
    for path in "${!commits_msg[@]}"; do
        pushd "${path}"

        # display commit
        display_commit_msg_header "${path}"
        commit_title="${commits_msg[${path}]}: update binaries\n\n"
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
