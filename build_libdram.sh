#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

LIBDRAM="${ROOT}/libdram"

function clean_libdram {
    local mtk_build="$1"
    local mtk_board="$2"
    local libdram_config="$3"

    [ -d "${mtk_build}" ] && rm -r "${mtk_build}"
    if [ -e "${libdram_config}" ] && [ -d "boards/${mtk_board}/" ]; then
        rm -r "boards/${mtk_board}/"
    fi
}

function build_libdram {
    local mtk_board=$(config_value "$1" libdram.board)
    local mtk_build=""
    local clean="${2:-false}"
    local build_for_lk="$3"
    local libdram_config="${SRC}/config/libdram/${mtk_board}"

    if [[ "${build_for_lk}" == true ]]; then
        mtk_build="build-${mtk_board}-lk"
    else
        mtk_build="build-${mtk_board}"
    fi

    pushd "${LIBDRAM}"
    [[ "${clean}" == true ]] && clean_libdram "${mtk_build}" "${mtk_board}" "${libdram_config}"

    if [ -e "${libdram_config}" ]; then
        mkdir -p "boards/${mtk_board}"
        cp "${libdram_config}" "boards/${mtk_board}/meson.build"
    fi

    aarch64_env
    if [[ "${build_for_lk}" == true ]]; then
        meson "${mtk_build}" -Dboard="${mtk_board}" -Dlk=true --cross-file meson.cross
    else
        meson "${mtk_build}" -Dboard="${mtk_board}" --cross-file meson.cross
    fi
    ninja -C "${mtk_build}"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
