#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"
source "${SRC}/build_libdram.sh"

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
    local clean="${2:-false}"
    local mode="${3:-release}"
    local out_dir=$(out_dir "$1" "${mode}")
    local extra_flags=""
    local libbase_path="${ROOT}/libbase-prebuilts/${mtk_plat}/libbase-lk.a"

    display_current_build "$1" "lk" "${mode}"

    if [[ "${mode}" == "debug" ]]; then
        extra_flags="DEBUG=1"
    else
        extra_flags="DEBUG=0"
    fi

    if  [ -a "${libbase_path}" ]; then
        extra_flags+=" LIBBASE=${libbase_path}"
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

    make ARCH_arm64_TOOLCHAIN_PREFIX=aarch64-linux-gnu- CFLAGS="" ${extra_flags} \
         GLOBAL_CFLAGS="-mstrict-align" SECURE_BOOT_ENABLE=no LIBGCC="" \
         LIBDRAM="${libdram_a}" "${mtk_board}"
    cp "build-${mtk_board}/lk.bin" "${out_dir}/lk-${mode}.bin"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
