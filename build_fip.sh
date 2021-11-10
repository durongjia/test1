#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

ATF="${ROOT}/arm-trusted-firmware"

function clean_fip {
    local mtk_plat="$1"
    if [ -d "build/${mtk_plat}" ]; then
        rm -r "build/${mtk_plat}"
    fi
}

function build_fip {
    local mtk_plat=$(config_value "$1" plat)
    local mtk_cflags=$(config_value "$1" fip.cflags)
    local log_level=$(config_value "$1" fip.log_level)
    local bl32_bin="$2"
    local bl33_bin="$3"
    local fip_bin="$4"
    local clean="${5:-false}"
    local extra_flags=""
    local mode="${6:-release}"
    local out_dir=$(out_dir "$1" "${mode}")

    echo "--------------------> MODE: ${mode} <--------------------"

    if [[ "${mode}" == "debug" ]]; then
        extra_flags="${extra_flags} DEBUG=1 log_level=${log_level} ENABLE_LTO=1"
    else
        extra_flags="${extra_flags} DEBUG=0 log_level=0"
    fi

    ! [ -d "${out_dir}" ] && mkdir -p "${out_dir}"

    pushd "${ATF}"
    [[ "${clean}" == true ]] && clean_fip "${mtk_plat}"

    arm-none_env
    make E=0 CFLAGS="${mtk_cflags}" PLAT="${mtk_plat}" BL32="${bl32_bin}" BL33="${bl33_bin}" \
         ${extra_flags} SPD=opteed NEED_BL32=yes NEED_BL33=yes bl31 fip

    cp "build/${mtk_plat}/${mode}/fip.bin" "${out_dir}/${fip_bin}"

    clear_vars
    popd
}

# main
function usage {
    cat <<DELIM__
usage: $(basename "$0") [options]

$ $(basename "$0") --config=i500-pumpkin.yaml --bl32=tee.bin --bl33=u-boot.bin --output=fip-test.bin

Options:
  --config   Mediatek board config file
  --bl32     Path to bl32 binary
  --bl33     Path to bl33 binary
  --output   Output name of fip binary
  --clean    (OPTIONAL) clean before build
  --debug    (OPTIONAL) build bootloader in debug mode
DELIM__
    exit 1
}

function main {
    local bl32=""
    local bl33=""
    local config=""
    local clean=false
    local output=""
    local mode=""

    local opts=$(getopt -o '' -l bl32:,bl33:,clean,config:,output:,debug -- "$@")
    eval set -- "${opts}"

    while true; do
        case "$1" in
            --bl32) bl32=$(readlink -e "$2"); shift 2 ;;
            --bl33) bl33=$(readlink -e "$2"); shift 2 ;;
            --clean) clean=true; shift ;;
            --config) config=$(readlink -e "$2"); shift 2 ;;
            --output) output=$2; shift 2 ;;
            --debug) mode=debug; shift ;;
            --) shift; break ;;
            *) usage; break ;;
        esac
    done

    # check arguments
    [ -z "${config}" ] && echo "Cannot find board config file" && usage
    [ -z "${bl32}" ] && echo "Cannot find bl32" && usage
    [ -z "${bl33}" ] && echo "Cannot find bl33" && usage
    [ -z "${output}" ] && echo "Please provide fip output name" && usage

    # build fip
    check_env
    build_fip "${config}" "${bl32}" "${bl33}" "${output}" "${clean}" "${mode}"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
