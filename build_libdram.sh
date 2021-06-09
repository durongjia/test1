#!/bin/bash

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

LIBDRAM="${ROOT}/libdram"

function clean_libdram {
    local MTK_BOARD="$1"
    [ -d "build-${MTK_BOARD}" ] && rm -r "build-${MTK_BOARD}"
}

function build_libdram {
    local MTK_BOARD=$(config_value "$1" libdram.board)
    local clean="$2"

    pushd "${LIBDRAM}"
    [[ "${clean}" == true ]] && clean_libdram "${MTK_BOARD}"

    aarch64_env
    meson "build-${MTK_BOARD}" -Dboard="${MTK_BOARD}" --cross-file meson.cross
    ninja -C "build-${MTK_BOARD}"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
