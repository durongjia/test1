#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

UBOOT="${ROOT}/u-boot"

function clean_uboot {
    make mrproper
}

function build_uboot {
    local clean="${2:-false}"
    local build_ab="${3:-false}"
    local mode="${4:-release}"
    local out_dir=$(out_dir "$1" "${mode}")
    local build="uboot"

    local mtk_defconfig=""
    local uboot_out_bin=""
    local uboot_out_env=""
    if [[ "${build_ab}" == true ]]; then
        mtk_defconfig=$(config_value "$1" uboot.ab_defconfig)
        uboot_out_bin="${out_dir}/u-boot-${mode}-ab.bin"
        uboot_out_env="${out_dir}/u-boot-initial-${mode}-env_ab"
        build="uboot ab"
    else
        mtk_defconfig=$(config_value "$1" uboot.defconfig)
        uboot_out_bin="${out_dir}/u-boot-${mode}.bin"
        uboot_out_env="${out_dir}/u-boot-initial-${mode}-env_noab"
    fi

    display_current_build "$1" "${build}" "${mode}"

    if [ -z "${mtk_defconfig}" ]; then
        if [[ "${build_ab}" == true ]]; then
            echo "uboot: skip build, ab_defconfig not provided"
        else
            echo "uboot: skip build, defconfig not provided"
        fi
        return
    fi

    ! [ -d "${out_dir}" ] && mkdir -p "${out_dir}"

    pushd "${UBOOT}"
    [[ "${clean}" == true ]] && clean_uboot

    aarch64_env
    export ARCH=arm64

    make "${mtk_defconfig}"
    if [[ "${mode}" == "release" ]]; then
        scripts/kconfig/merge_config.sh .config "${BUILD}/config/defconfig_fragment/uboot-release.config"
    fi
    make -j"$(nproc)"

    ./scripts/get_default_envs.sh > "${uboot_out_env}"
    cp u-boot.bin "${uboot_out_bin}"

    unset ARCH
    clear_vars
    popd
}

# main
function usage {
    cat <<DELIM__
usage: $(basename "$0") [options]

$ $(basename "$0") --config=i500-pumpkin.yaml --build_ab

Options:
  --config   Mediatek board config file
  --build_ab (OPTIONAL) use ab defconfig
  --clean    (OPTIONAL) clean before build
  --debug    (OPTIONAL) build bootloader in debug mode
  --help     (OPTIONAL) display usage
DELIM__
}

function main {
    local build_ab=false
    local clean=false
    local config=""
    local mode=""

    local opts_args="build_ab,clean,config:,debug,help"
    local opts=$(getopt -o '' -l "${opts_args}" -- "$@")
    eval set -- "${opts}"

    while true; do
        case "$1" in
            --build_ab) build_ab=true; shift ;;
            --config) config=$(find_path "$2"); shift 2 ;;
            --clean) clean=true; shift ;;
            --debug) mode=debug; shift ;;
            --help) usage; exit 0 ;;
            --) shift; break ;;
        esac
    done

    # check arguments
    [ -z "${config}" ] && error_exit "Cannot find board config file"

    # build uboot
    check_env
    build_uboot "${config}" "${clean}" "${build_ab}" "${mode}"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
