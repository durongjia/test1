#!/bin/bash

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

OPTEE="${ROOT}/optee-os"

function clean_optee {
    [ -d "out" ] && rm -rf out
}

function build_optee {
    local MTK_PLAT=$(config_value "$1" plat)
    local OPTEE_FLAGS=$(config_value "$1" optee.flags)
    local clean="$2"

    ! [ -d "${OUT}/${MTK_PLAT}" ] && mkdir "${OUT}/${MTK_PLAT}"

    pushd "${OPTEE}"
    [[ "${clean}" == true ]] && clean_optee "${MTK_PLAT}"

    aarch64_env
    make -j$(nproc) PLATFORM="mediatek-${MTK_PLAT}" $OPTEE_FLAGS all
    cp out/arm-plat-mediatek/core/tee.bin "${OUT}/${MTK_PLAT}/"

    clear_vars
    popd
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
