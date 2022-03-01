#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

LIBHWID="${ROOT}/libhwid"

function clean_libhwid {
    local mtk_build="$1"
    if [ -d "${mtk_build}" ]; then
        rm -r "${mtk_build}"
    fi
}

function build_libhwid {
    local mtk_plat=$(config_value "$1" plat)
    local mtk_build="build-${mtk_plat}"
    local clean="${2:-false}"

    display_current_build "$1" "libhwid" ""

    pushd "${LIBHWID}"
    [[ "${clean}" == true ]] && clean_libhwid "${mtk_build}"

    aarch64_env

    meson "${mtk_build}" -DSoC="${mtk_plat^^}" --cross-file "${SRC}/config/meson.cross"
    ninja -C "${mtk_build}"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
