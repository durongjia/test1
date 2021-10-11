#!/bin/bash
set -e
set -u
set -o pipefail

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

UBOOT="${ROOT}/u-boot"

function clean_uboot {
    make mrproper
}

function build_uboot {
    local MTK_PLAT=$(config_value "$1" plat)
    local clean="${2:-false}"
    local build_ab="${3:-false}"
    local MODE="${4:-release}"
    local OUT_DIR=$(out_dir $1 $MODE)

    echo "--------------------> FORCE MODE: ${MODE} <--------------------"

    local MTK_DEFCONFIG
    local UBOOT_OUT_BIN
    if [[ "${build_ab}" == true ]]; then
        MTK_DEFCONFIG=$(config_value "$1" uboot.ab_defconfig)
        UBOOT_OUT_BIN="${OUT_DIR}/u-boot-${MODE}-ab.bin"
        UBOOT_OUT_ENV="${OUT_DIR}/u-boot-initial-${MODE}-env_ab"
    else
        MTK_DEFCONFIG=$(config_value "$1" uboot.defconfig)
        UBOOT_OUT_BIN="${OUT_DIR}/u-boot-${MODE}.bin"
        UBOOT_OUT_ENV="${OUT_DIR}/u-boot-initial-${MODE}-env_noab"
    fi

    if [ -z "${MTK_DEFCONFIG}" ]; then
        if [[ "${build_ab}" == true ]]; then
            echo "uboot: skip build, ab_defconfig not provided"
        else
            echo "uboot: skip build, defconfig not provided"
        fi
        return
    fi

    ! [ -d "${OUT_DIR}" ] && mkdir -p "${OUT_DIR}"

    pushd "${UBOOT}"
    [[ "${clean}" == true ]] && clean_uboot "${MTK_PLAT}"

    aarch64_env
    export ARCH=arm64

    make "${MTK_DEFCONFIG}"
    if [[ "${MODE}" == "release" ]]; then
        scripts/kconfig/merge_config.sh .config "${BUILD}/config/defconfig_fragment/uboot-release.config"
    fi
    make -j$(nproc)

    ./scripts/get_default_envs.sh > "${UBOOT_OUT_ENV}"
    cp u-boot.bin "${UBOOT_OUT_BIN}"

    unset ARCH
    clear_vars
    popd
}

# main
function usage {
    cat <<DELIM__
usage: $(basename $0) [options]

$ $(basename $0) --config=i500-pumpkin.yaml --build_ab

Options:
  --config   Mediatek board config file
  --build_ab (OPTIONAL) use ab defconfig
  --clean    (OPTIONAL) clean before build
  --debug    (OPTIONAL) build bootloader in debug mode
DELIM__
    exit 1
}

function main {
    local build_ab=false
    local clean=false
    local config=""
    local mode=""

    local OPTS=$(getopt -o '' -l build_ab,clean,config:,debug -- "$@")
    eval set -- "${OPTS}"

    while true; do
        case "$1" in
            --build_ab) build_ab=true; shift ;;
            --config) config=$(readlink -e "$2"); shift 2 ;;
            --clean) clean=true; shift ;;
            --debug) mode=debug; shift ;;
            --) shift; break ;;
            *) usage ;;
        esac
    done

    # check arguments
    [ -z "${config}" ] && echo "Cannot find board config file" && usage

    # build uboot
    check_env
    build_uboot "${config}" "${clean}" "${build_ab}" "${mode}"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
