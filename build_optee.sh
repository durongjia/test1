#!/bin/bash 
set -e
set -u
set -o pipefail

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

OPTEE="${ROOT}/optee-os"

function clean_optee {
    if [ -d "out" ]; then
        rm -rf out
    fi
}

function build_optee {
    local MTK_PLAT=$(config_value "$1" plat)
    local OPTEE_FLAGS=$(config_value "$1" optee.flags)
    local OPTEE_BOARD=$(config_value "$1" optee.board)
    local clean="${2:-false}"
    local MODE="${3:-release}"
    local OUT_DIR=$(out_dir $1 $MODE)

    echo "--------------------> MODE: ${MODE} <--------------------"

    ! [ -d "${OUT_DIR}" ] && mkdir -p "${OUT_DIR}"

    pushd "${OPTEE}"
    [[ "${clean}" == true ]] && clean_optee "${MTK_PLAT}"

    if [[ "${MODE}" == "debug" ]]; then
       OPTEE_FLAGS="${OPTEE_FLAGS} DEBUG=1"
    else
       OPTEE_FLAGS="${OPTEE_FLAGS} DEBUG=0 CFG_TEE_CORE_LOG_LEVEL=0 CFG_UART_ENABLE=n"
    fi

    aarch64_env
    if [ -n "${OPTEE_BOARD}" ]; then
        make -j$(nproc) PLATFORM="mediatek-${OPTEE_BOARD}" $OPTEE_FLAGS all
    else
        make -j$(nproc) PLATFORM="mediatek-${MTK_PLAT}" $OPTEE_FLAGS all
    fi
    cp out/arm-plat-mediatek/core/tee.bin "${OUT_DIR}/tee-${MODE}.bin"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
