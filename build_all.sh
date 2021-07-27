#!/bin/bash

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/build_bl2.sh"
source "${SRC}/build_fip.sh"
source "${SRC}/build_lk.sh"
source "${SRC}/build_optee.sh"
source "${SRC}/build_uboot.sh"
source "${SRC}/utils.sh"

function build_all {
    local MTK_PLAT=$(config_value "$1" plat)
    local OUT_DIR=$(out_dir $1)
    local clean="$2"


    if [[ "${clean}" == true ]]; then
        [ -d "${OUT_DIR}" ] && rm -rf "${OUT_DIR}"
    fi

    # bl2
    build_bl2 "$@"

    # lk
    build_lk "$@"

    # uboot
    build_uboot "$@"
    build_uboot "$@" true

    # optee
    build_optee "$@"

    # fip
    if [ -e "${OUT_DIR}/u-boot.bin" ]; then
        build_fip "$1" "${OUT_DIR}/tee.bin" "${OUT_DIR}/u-boot.bin" \
                  "fip_noab.bin" "${clean}"
    fi

    if [ -e "${OUT_DIR}/u-boot-ab.bin" ]; then
        build_fip "$1" "${OUT_DIR}/tee.bin" "${OUT_DIR}/u-boot-ab.bin" \
                  "fip_ab.bin" "${clean}"
    fi
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
