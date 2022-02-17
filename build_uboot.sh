#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/secure.sh"
source "${SRC}/utils.sh"

UBOOT="${ROOT}/u-boot"

function clean_uboot {
    make mrproper
}

function build_uboot {
    local clean="${2:-false}"
    local mode="${3:-release}"
    local out_dir=$(out_dir "$1" "${mode}")
    local defconfig_fragment="${BUILD}/config/defconfig_fragment/uboot-${mode}.config"

    local mtk_defconfig=""
    local uboot_out_bin=""
    local uboot_out_env=""
    mtk_defconfig=$(config_value "$1" uboot.defconfig)
    uboot_out_bin="${out_dir}/u-boot-${mode}.bin"
    uboot_out_env="${out_dir}/u-boot-initial-${mode}-env"

    display_current_build "$1" "uboot" "${mode}"

    if [ -z "${mtk_defconfig}" ]; then
        echo "uboot: skip build, defconfig not provided"
        return
    fi

    ! [ -d "${out_dir}" ] && mkdir -p "${out_dir}"

    pushd "${UBOOT}"
    [[ "${clean}" == true ]] && clean_uboot

    aarch64_env
    export ARCH=arm64

    # generate defconfig
    make "${mtk_defconfig}"
    if [ -a "${defconfig_fragment}" ]; then
        scripts/kconfig/merge_config.sh .config "${defconfig_fragment}"
    fi

    # avb key only on release/factory
    if ! [[ "${mode}" == "debug" ]]; then
        local avb_pub_key=""
        get_avb_pub_key "$1" avb_pub_key
        if [ -n "${avb_pub_key}" ]; then
            cp "${avb_pub_key}" "${mtk_defconfig}.avbpubkey"
            avb_pub_key="${mtk_defconfig}.avbpubkey"
            sed -i 's/^\(CONFIG_AVB_PUBKEY_FILE=\).*/\1\"'${avb_pub_key}'\"/' .config
        fi
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

$ $(basename "$0") --config=i500-pumpkin.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
  --mode     (OPTIONAL) [release|debug|factory] mode (default: release)
  --help     (OPTIONAL) display usage
DELIM__
}

function main {
    local clean=false
    local config=""
    local mode="release"

    local opts_args="clean,config:,mode:,help"
    local opts=$(getopt -o '' -l "${opts_args}" -- "$@")
    eval set -- "${opts}"

    while true; do
        case "$1" in
            --config) config=$(find_path "$2"); shift 2 ;;
            --clean) clean=true; shift ;;
            --mode) mode="$2"; shift 2 ;;
            --help) usage; exit 0 ;;
            --) shift; break ;;
        esac
    done

    # check arguments
    [ -z "${config}" ] && error_exit "Cannot find board config file"
    ! [[ " ${MODES[*]} " =~ " ${mode} " ]] && error_exit "${mode} mode not supported"

    # build uboot
    check_env
    build_uboot "${config}" "${clean}" "${mode}"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
