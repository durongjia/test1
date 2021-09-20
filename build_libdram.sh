#!/bin/bash
set -e
set -u
set -o pipefail

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

LIBDRAM="${ROOT}/libdram"

function clean_libdram {
    local MTK_BUILD="$1"
    local MTK_BOARD="$2"
    local LIBDRAM_CONFIG="$3"

    [ -d "${MTK_BUILD}" ] && rm -r "${MTK_BUILD}"
    if [ -e "${LIBDRAM_CONFIG}" ] && [ -d "boards/${MTK_BOARD}/" ]; then
        rm -r "boards/${MTK_BOARD}/"
    fi
}

function build_libdram {
    local MTK_BOARD=$(config_value "$1" libdram.board)
    local MTK_BUILD=""
    local clean="${2:-false}"
    local build_for_lk="$3"
    local LIBDRAM_CONFIG="${SRC}/config/libdram/${MTK_BOARD}"

    if [[ "${build_for_lk}" == true ]]; then
        MTK_BUILD="build-${MTK_BOARD}-lk"
    else
        MTK_BUILD="build-${MTK_BOARD}"
    fi

    pushd "${LIBDRAM}"
    [[ "${clean}" == true ]] && clean_libdram "${MTK_BUILD}" "${MTK_BOARD}" "${LIBDRAM_CONFIG}"

    if [ -e "${LIBDRAM_CONFIG}" ]; then
        mkdir -p "boards/${MTK_BOARD}"
        cp "${LIBDRAM_CONFIG}" "boards/${MTK_BOARD}/meson.build"
    fi

    aarch64_env
    if [[ "${build_for_lk}" == true ]]; then
        meson "${MTK_BUILD}" -Dboard="${MTK_BOARD}" -Dlk=true --cross-file meson.cross
    else
        meson "${MTK_BUILD}" -Dboard="${MTK_BOARD}" --cross-file meson.cross
    fi
    ninja -C "${MTK_BUILD}"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
