#!/bin/bash

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

ATF_PRIVATE="${ROOT}/arm-trusted-firmware-private"

function clean_bl2 {
    local MTK_PLAT="$1"
    pushd "${ATF_PRIVATE}"
    [ -d "build/${MTK_PLAT}" ] && rm -r "build/${MTK_PLAT}"
    popd
}

function build_bl2 {
    local MTK_PLAT=$(config_value "$1" plat)
    local MTK_CFLAGS=$(config_value "$1" bl2.cflags)

    local clean="$2"
    ! [ -d "${OUT}/${MTK_PLAT}" ] && mkdir "${OUT}/${MTK_PLAT}"
    [[ "${clean}" == true ]] && clean_bl2 "${MTK_PLAT}"

    pushd "${ATF_PRIVATE}"
    aarch64_env
    make E=0 CFLAGS="${MTK_CFLAGS}" PLAT="${MTK_PLAT}" bl2

    pushd "build/${MTK_PLAT}/release"
    cp bl2.bin bl2.img.tmp
    truncate -s%4 bl2.img.tmp

    "${SRC}/mkimage" -T mtk_image -a 0x201000 -e 0x201000 -n "media=emmc;aarch64=1" \
		     -d bl2.img.tmp bl2.img

    rm bl2.img.tmp
    cp bl2.img "${OUT}/${MTK_PLAT}/"
    popd

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi