#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

LIBDRAM="${ROOT}/libdram"

function get_libdram_customer {
    local customer_config=$(config_value "$1" customer_config)
    local mtk_board="$2"
    local libdram_customer=""

    if [ -n "${customer_config}" ]; then
        local libdram="${ROOT}/${customer_config}/libdram/${mtk_board}"
        if [ -e "${libdram}" ]; then
            libdram_customer="${libdram}";
        fi
    fi

    echo "${libdram_customer}"
}

function clean_libdram {
    local mtk_build="$1"
    local mtk_board="$2"

    [ -d "${mtk_build}" ] && rm -r "${mtk_build}"
    [ -d "boards/${mtk_board}" ] && rm -r "boards/${mtk_board}"
}

function build_libdram {
    local mtk_board=$(config_value "$1" libdram.board)
    local mtk_build="build-${mtk_board}"
    local clean="${2:-false}"
    local build_for_lk="$3"
    local mode="${4:-release}"
    local libdram_customer=$(get_libdram_customer "$1" "${mtk_board}")
    local build="libdram"
    local extra_flags=""

    if [[ "${build_for_lk}" == true ]]; then
        mtk_build="build-${mtk_board}-lk"
        build="libdram lk"
    fi

    display_current_build "$1" "${build}" "${mode}"

    pushd "${LIBDRAM}"

    [[ "${clean}" == true ]] && clean_libdram "${mtk_build}" "${mtk_board}"

    if [ -n "${libdram_customer}" ]; then
        mkdir -p "boards/${mtk_board}"
        cp "${libdram_customer}" "boards/${mtk_board}/meson.build"
    fi

    aarch64_env

    if [[ "${build_for_lk}" == true ]]; then
        extra_flags="-Dlk=true"
    fi
    meson "${mtk_build}" -Dboard="${mtk_board}" ${extra_flags} --cross-file "${SRC}/config/meson.cross"
    ninja -C "${mtk_build}"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
