#!/bin/bash

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/build_bl2.sh"
source "${SRC}/build_fip.sh"
source "${SRC}/build_optee.sh"
source "${SRC}/build_uboot.sh"
source "${SRC}/utils.sh"

function build_all {
    local MTK_PLAT=$(config_value "$1" plat)

    # bl2
    build_bl2 "$@"

    # uboot
    build_uboot "$@"
    build_uboot "$@" true

    # optee
    build_optee "$@"

    # fip
    if [ -e "${OUT}/${MTK_PLAT}/u-boot.bin" ]; then
	build_fip "$1" "${OUT}/${MTK_PLAT}/tee.bin" "${OUT}/${MTK_PLAT}/u-boot.bin" "fip_noab.bin"
    fi

    if [ -e "${OUT}/${MTK_PLAT}/u-boot-ab.bin" ]; then
	build_fip "$1" "${OUT}/${MTK_PLAT}/tee.bin" "${OUT}/${MTK_PLAT}/u-boot-ab.bin"  "fip_ab.bin"
    fi
}

main "$@"
