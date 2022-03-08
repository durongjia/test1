#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

OPTEE="${ROOT}/optee-os"

function clean_optee {
    if [ -d "out" ]; then
        rm -rf out
    fi
}

function build_ta {
    local clean="$1"
    local optee_flags="$2"
    local ta_dir=$(dirname "$3")

    pushd "${ta_dir}"
    echo "-> Build Trusted Application: ${ta_dir}"
    [[ "${clean}" == true ]] && make clean
    make -j"$(nproc)" ${optee_flags}
    popd
}

function get_optee_flags {
    local mtk_plat=$(config_value "$1" plat)
    local flags=$(config_value "$1" optee.flags)
    local board=$(config_value "$1" optee.board)
    local mode="$2"
    local -n optee_flags_ref="$3"

    # additional flags
    case "${mode}" in
        "release") flags+=" DEBUG=0 CFG_TEE_CORE_LOG_LEVEL=0 CFG_UART_ENABLE=n" ;;
        "debug") flags+=" DEBUG=1" ;;
        "factory")
            flags+=" DEBUG=0 CFG_TEE_CORE_LOG_LEVEL=0 CFG_UART_ENABLE=n"

            # RPMB
            flags+=" CFG_RPMB_FS=y CFG_RPMB_WRITE_KEY=y"

            # AVB TA
            flags+=" CFG_IN_TREE_EARLY_TAS=avb/023f8f1a-292a-432b-8fc4-de8471358067"
    esac

    if [ -n "${board}" ]; then
        flags+=" PLATFORM=mediatek-${board}"
    else
        flags+=" PLATFORM=mediatek-${mtk_plat}"
    fi

    optee_flags_ref="${flags}"
}

function build_optee {
    local mtk_plat=$(config_value "$1" plat)
    local clean="${2:-false}"
    local mode="${3:-release}"
    local out_dir=$(out_dir "$1" "${mode}")
    local optee_flags=""
    local optee_out_dir="${OPTEE}/out/arm-plat-mediatek"
    local early_ta_paths=($(config_value "$1" optee.early_ta_paths))

    display_current_build "$1" "optee" "${mode}"

    get_optee_flags "$1" "${mode}" optee_flags

    # OTP TA
    if [[ "${mode}" == "factory" ]]; then
        early_ta_paths+=("optee-ta/optee-otp/ta/3712bdda-569f-4940-b749-fb3b06a5fd86.elf")
    fi

    # setup env
    ! [ -d "${out_dir}" ] && mkdir -p "${out_dir}"

    pushd "${OPTEE}"
    [[ "${clean}" == true ]] && clean_optee "${mtk_plat}"

    aarch64_env

    # build early TA
    if [ "${#early_ta_paths[@]}" -gt 0 ]; then
        make -j"$(nproc)" ${optee_flags} ta_dev_kit
        export TA_DEV_KIT_DIR="${optee_out_dir}/export-ta_arm64"

        early_ta_paths=("${early_ta_paths[@]/#/${ROOT}/}")
        for early_ta in "${early_ta_paths[@]}"; do
            build_ta "${clean}" "${optee_flags}" "${early_ta}"
            optee_flags+=" EARLY_TA_PATHS+=${early_ta}"
        done
    fi

    # build tee binary
    make -j"$(nproc)" ${optee_flags} all

    cp out/arm-plat-mediatek/core/tee.bin "${out_dir}/tee-${mode}.bin"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
