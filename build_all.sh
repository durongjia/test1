#!/bin/bash
set -e
set -u
set -o pipefail

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/build_bl2.sh"
source "${SRC}/build_fip.sh"
source "${SRC}/build_lk.sh"
source "${SRC}/build_optee.sh"
source "${SRC}/build_uboot.sh"
source "${SRC}/utils.sh"

function build_all {
    local MTK_PLAT=$(config_value "$1" plat)
    local clean="${2:-false}"
    local MODE="${3:-release}"
    local OUT_DIR=$(out_dir $1 $MODE)

    echo "--------------------> MODE: ${MODE} <--------------------"

    if [[ "${clean}" == true ]]; then
        [ -d "${OUT_DIR}" ] && rm -rf "${OUT_DIR}"
    fi

    # bl2
    build_bl2 "$@"

    # lk
    build_lk "$@"
    # uboot
    build_uboot "$1" "$2" false "$3"

    # uboot build ab
    build_uboot "$1" "$2" true "$3"

    # optee
    build_optee "$@"

    # fip
    if [ -e "${OUT_DIR}/u-boot-${MODE}.bin" ]; then
        build_fip "$1" "${OUT_DIR}/tee-${MODE}.bin" "${OUT_DIR}/u-boot-${MODE}.bin" \
                  "fip_${MODE}_noab.bin" "${clean}" "${MODE}"
    fi

    if [ -e "${OUT_DIR}/u-boot-${MODE}-ab.bin" ]; then
        build_fip "$1" "${OUT_DIR}/tee-${MODE}.bin" "${OUT_DIR}/u-boot-${MODE}-ab.bin" \
                  "fip_${MODE}_ab.bin" "${clean}" "${MODE}"
    fi
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
