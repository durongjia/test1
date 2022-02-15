#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"
source "${SRC}/build_libdram.sh"
source "${SRC}/secure.sh"

MBEDTLS="${ROOT}/mbedtls"

function clean_bl2 {
    local mtk_plat="$1"
    if [ -d "build/${mtk_plat}" ]; then
        rm -r "build/${mtk_plat}"
    fi
}

function build_bl2 {
    local mtk_plat=$(config_value "$1" plat)
    local atf_project=$(config_value "$1" bl2.project)
    local mtk_cflags=$(config_value "$1" bl2.cflags)
    local mtk_libdram_board=$(config_value "$1" libdram.board)
    local libdram_a="${LIBDRAM}/build-${mtk_libdram_board}/src/${mtk_plat}/libdram.a"
    local clean="${2:-false}"
    local mode="${3:-release}"
    local out_dir=$(out_dir "$1" "${mode}")
    local bl2_out_dir=""
    local extra_flags=""
    local libbase_path="${ROOT}/libbase-prebuilts/${mtk_plat}/libbase.a"

    display_current_build "$1" "bl2" "${mode}"

    if [[ "${mode}" == "debug" ]]; then
        extra_flags="DEBUG=1"
        bl2_out_dir="build/${mtk_plat}/debug"
    else
        extra_flags="DEBUG=0"
        bl2_out_dir="build/${mtk_plat}/release"
    fi

    if  [ -a "${libbase_path}" ]; then
        extra_flags+=" LIBBASE=${libbase_path}"
    fi

    if [[ "${mode}" == "factory" ]]; then
        local rot_key=""
        get_rot_key "$1" rot_key
        extra_flags+=" MBEDTLS_DIR=${MBEDTLS} TRUSTED_BOARD_BOOT=1 GENERATE_COT=1"
        extra_flags+=" ROT_KEY=${rot_key}"
    fi

    ! [ -d "${out_dir}" ] && mkdir -p "${out_dir}"

    if [[ "${clean}" == true ]]; then
        build_libdram "$1" true false "${mode}"
    else
        # check if libdram has been compiled
        ! [ -a "${libdram_a}" ] && build_libdram "$1" false false "${mode}"
    fi

    pushd "${ROOT}/${atf_project}"
    [[ "${clean}" == true ]] && clean_bl2 "${mtk_plat}"

    aarch64_env

    make E=0 CFLAGS="${mtk_cflags}" PLAT="${mtk_plat}" LIBDRAM="${libdram_a}" ${extra_flags} bl2

    pushd "${bl2_out_dir}"
    cp bl2.bin bl2.img.tmp
    truncate -s%4 bl2.img.tmp

    "${SRC}/mkimage" -T mtk_image -a 0x201000 -e 0x201000 -n "media=emmc;aarch64=1" \
                     -d bl2.img.tmp bl2.img

    rm bl2.img.tmp
    cp bl2.img "${out_dir}/bl2-${mode}.img"
    popd

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
