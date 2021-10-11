#!/bin/bash
set -e
set -u
set -o pipefail

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"
source "${SRC}/build_libdram.sh"

LK="${ROOT}/lk"

function clean_lk {
    local MTK_BOARD="$1"
    if [ -d "build-${MTK_BOARD}" ]; then
        rm -r "build-${MTK_BOARD}"
    fi
}

function build_lk {
    local MTK_PLAT=$(config_value "$1" plat)
    local MTK_BOARD=$(config_value "$1" lk.board)
    local MTK_LIBDRAM_BOARD=$(config_value "$1" libdram.board)
    local LIBDRAM_A="${LIBDRAM}/build-${MTK_LIBDRAM_BOARD}-lk/src/${MTK_PLAT}/libdram.a"
    local clean="${2:-false}"
    local EXTRA_FLAGS=""
    local MODE="${3:-release}"
    local OUT_DIR=$(out_dir $1 $MODE)

    echo "--------------------> MODE: ${MODE} <--------------------"

    ! [ -d "${OUT_DIR}" ] && mkdir -p "${OUT_DIR}"

    if [[ "${clean}" == true ]]; then
        build_libdram "$1" true true
    else
        # check if libdram has been compiled
        ! [ -a "${LIBDRAM_A}" ] && build_libdram "$1" false true
    fi

    pushd "${LK}"
    if [[ "${clean}" == true ]]; then
        clean_lk "${MTK_BOARD}"
    fi

    if [[ "${MODE}" == "debug" ]]; then
        EXTRA_FLAGS="${EXTRA_FLAGS} DEBUG=1"
    else
        EXTRA_FLAGS="${EXTRA_FLAGS} DEBUG=0"
    fi

    aarch64_env
    make ARCH_arm64_TOOLCHAIN_PREFIX=aarch64-linux-gnu- CFLAGS="" ${EXTRA_FLAGS} \
         GLOBAL_CFLAGS="-mstrict-align" SECURE_BOOT_ENABLE=no LIBGCC="" \
         LIBDRAM="${LIBDRAM_A}" "${MTK_BOARD}"
    cp "build-${MTK_BOARD}/lk.bin" "${OUT_DIR}/lk-${MODE}.bin"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
