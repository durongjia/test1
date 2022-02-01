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

function build_optee {
    local mtk_plat=$(config_value "$1" plat)
    local optee_flags=$(config_value "$1" optee.flags)
    local optee_board=$(config_value "$1" optee.board)
    local clean="${2:-false}"
    local mode="${3:-release}"
    local out_dir=$(out_dir "$1" "${mode}")

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

    # build tee binary
    make -j"$(nproc)" ${optee_flags} all

    cp out/arm-plat-mediatek/core/tee.bin "${out_dir}/tee-${mode}.bin"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
