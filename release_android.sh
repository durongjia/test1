#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/build_all.sh"
source "${SRC}/commit-binaries.sh"

PROJECTS_AIOT=("arm-trusted-firmware" "build" "libbase-prebuilts" "libdram" "lk"
               "optee-os" "optee-ta/kmgk" "optee-ta/optee-otp" "optee-ta/optee_test"
               "u-boot")

function add_commit_msg {
    local -n commits_msg_ref="$1"
    local title_prefix="$2"
    local mtk_android_out="$3"
    local toplevel=""
    local commits_msg_value=""

    pushd "${mtk_android_out}"
    toplevel=$(git rev-parse --sq --show-toplevel)
    if [[ -v "commits_msg_ref[${toplevel}]" ]]; then
        commits_msg_value="${commits_msg_ref[${toplevel}]}"
        if ! [[ ${commits_msg_value} =~ ${title_prefix} ]]; then
            unset commits_msg_ref["${toplevel}"]
            commits_msg_ref+=(["${toplevel}"]="${commits_msg_value}/${title_prefix}")
        fi
    else
        commits_msg_ref+=(["${toplevel}"]="${title_prefix}")
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
  --no-build (OPTIONAL) don't rebuild the images
  --silent   (OPTIONAL) silent build commands
  --skip-ta  (OPTIONAL) skip build Trusted Applications

By default release and debug modes are built.

DELIM__
}

function find_all_configs {
    local -n configs_ref="$1"

    configs_ref=("${SRC}"/config/boards/*.yaml)

    for root_folder in "${ROOT}"/config_*; do
        for config_folder in "${root_folder}"/boards/*.yaml; do
            configs_ref+=("${config_folder}")
        done
    done
}

function main {
    local aosp=""
    local commit=false
    local config=""
    local build=true
    local silent=false
    local skip_ta=false
    local mode_list=(debug release)

    local opts_args="aosp:,commit,config:,help,mode:,no-build,silent,skip-ta"
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
            --no-build) build=false; shift ;;
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
        find_all_configs configs
    fi

    # build configs
    local mtk_binaries_path=""
    local out_dir=""
    declare -A commits_msg

    check_local_changes "${ROOT}" "${PROJECTS_AIOT[@]}"

    check_env

    pushd "${SRC}"
    for mtk_config in "${configs[@]}"; do
        mtk_binaries_path=$(config_value "${mtk_config}" android.binaries_path)

        for mode in "${mode_list[@]}"; do
            ! [[ " ${MODES[*]} " =~ " ${mode} " ]] && error_usage_exit "${mode} mode not supported"

            if [[ "${build}" == true ]]; then
                if [[ "${silent}" == true ]]; then
                    display_current_build "${mtk_config}" "all" "${mode}"
                    build_all "${mtk_config}" "true" "${mode}" &> /dev/null
                else
                    build_all "${mtk_config}" "true" "${mode}"
                fi
            fi

            if ! [ -d "${aosp}/${mtk_binaries_path}" ]; then
                error_exit "cannot copy binaries, ${aosp}/${mtk_binaries_path} not found"
            fi

            # Trusted Applications
            if [[ "${build}" == true ]] && [[ "${skip_ta}" == false ]]; then
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
        commit_title_prefix=$(board_name ${mtk_config})
        add_commit_msg commits_msg "${commit_title_prefix}" "${aosp}/${mtk_binaries_path}"
    done
    popd

    for abspath in "${!commits_msg[@]}"; do
        commit_title_prefix="${commits_msg[${abspath}]}"
        # we need the project name for commit_binaries(), not the
        # full filepath
        to_project=${abspath#${aosp}/}

        if [ "${commit}" == true ]; then
            commit_binaries --from-repo="${ROOT}" --from-projects="${PROJECTS_AIOT[*]}" \
                            --to-repo="${aosp}" --to-project="${to_project}" \
                            --title-prefix="${commit_title_prefix}"
        else
            commit_binaries --from-repo="${ROOT}" --from-projects="${PROJECTS_AIOT[*]}" \
                            --to-repo="${aosp}" --to-project="${to_project}" \
                            --title-prefix="${commit_title_prefix}" \
                            --dry-run
        fi
    done
}

main "$@"
