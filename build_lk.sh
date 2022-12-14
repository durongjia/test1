#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/build_libdram.sh"
source "${SRC}/secure.sh"
source "${SRC}/utils.sh"

LK="${ROOT}/lk"

function clean_lk {
    local mtk_board="$1"
    if [ -d "build-${mtk_board}" ]; then
        rm -r "build-${mtk_board}"
    fi
}

function build_lk {
    local mtk_plat=$(config_value "$1" plat)
    local mtk_board=$(config_value "$1" lk.board)
    local mtk_libdram_board=$(config_value "$1" libdram.board)
    local libdram_a="${LIBDRAM}/build-${mtk_libdram_board}-lk/src/${mtk_plat}/libdram.a"
    local libbase_a="${ROOT}/libbase-prebuilts/${mtk_plat}/libbase-lk.a"
    local clean="${2:-false}"
    local mode="${3:-release}"
    local out_dir=$(out_dir "$1" "${mode}")
    local extra_flags=""

    display_current_build "$1" "lk" "${mode}"

    if [[ "${mode}" == "debug" ]]; then
        extra_flags="DEBUG=1"
    else
        extra_flags="DEBUG=0"
    fi

    ! [ -d "${out_dir}" ] && mkdir -p "${out_dir}"

    if [[ "${clean}" == true ]]; then
        build_libdram "$1" true true "${mode}"
    else
        # check if libdram has been compiled
        ! [ -a "${libdram_a}" ] && build_libdram "$1" false true "${mode}"
    fi

    pushd "${LK}"
    [[ "${clean}" == true ]] && clean_lk "${mtk_board}"

    aarch64_env

    make ARCH_arm64_TOOLCHAIN_PREFIX=${CROSS_COMPILE} CFLAGS="" ${extra_flags} \
         GLOBAL_CFLAGS="-mstrict-align -mno-outline-atomics" SECURE_BOOT_ENABLE=no LIBGCC="" \
         LIBDRAM="${libdram_a}" LIBBASE="${libbase_a}" "${mtk_board}"

    cp "build-${mtk_board}/lk.bin" "${out_dir}/lk-${mode}.bin"
    if [[ "${mode}" == "factory" ]]; then
        sign_lk_image "build-${mtk_board}/lk.bin" "${out_dir}/lk-${mode}.sign"
    fi

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
