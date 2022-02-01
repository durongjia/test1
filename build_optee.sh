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
    local optee_flags="$1"
    local ta_dir=$(dirname "$2")

    pushd "${ta_dir}"
    make -j"$(nproc)" ${optee_flags}
    popd
}

function build_optee {
    local mtk_plat=$(config_value "$1" plat)
    local optee_flags=$(config_value "$1" optee.flags)
    local optee_board=$(config_value "$1" optee.board)
    local clean="${2:-false}"
    local mode="${3:-release}"
    local out_dir=$(out_dir "$1" "${mode}")
    local optee_out_dir="${OPTEE}/out/arm-plat-mediatek"
    local early_ta_paths=($(config_value "$1" optee.early_ta_paths))

    display_current_build "$1" "optee" "${mode}"

    # additional flags
    if [[ "${mode}" == "release" ]]; then
        optee_flags+=" DEBUG=0 CFG_TEE_CORE_LOG_LEVEL=0 CFG_UART_ENABLE=n"
    else
        optee_flags+=" DEBUG=1"
    fi

    if [ -n "${optee_board}" ]; then
        optee_flags+=" PLATFORM=mediatek-${optee_board}"
    else
        optee_flags+=" PLATFORM=mediatek-${mtk_plat}"
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
            build_ta "${optee_flags}" "${early_ta}"
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
