#!/bin/bash

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

LIBDRAM="${ROOT}/libdram"

function clean_libdram {
    local MTK_BUILD="$1"
    [ -d "${MTK_BUILD}" ] && rm -r "${MTK_BUILD}"
}

function build_libdram {
    local MTK_BOARD=$(config_value "$1" libdram.board)
    local MTK_BUILD=""
    local clean="$2"
    local build_for_lk="$3"

    if [[ "${build_for_lk}" == true ]]; then
	MTK_BUILD="build-${MTK_BOARD}-lk"
    else
	MTK_BUILD="build-${MTK_BOARD}"
    fi

    pushd "${LIBDRAM}"
    [[ "${clean}" == true ]] && clean_libdram "${MTK_BUILD}"

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
