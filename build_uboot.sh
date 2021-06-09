#!/bin/bash

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

UBOOT="${ROOT}/u-boot"

function clean_uboot {
    make clean
}

function build_uboot {
    local MTK_PLAT=$(config_value "$1" plat)
    local build_ab="$3"
    local clean="$2"

    local MTK_DEFCONFIG
    local UBOOT_OUT_BIN
    if [[ "${build_ab}" == true ]]; then
	MTK_DEFCONFIG=$(config_value "$1" uboot.ab_defconfig)
	UBOOT_OUT_BIN="${OUT}/${MTK_PLAT}/u-boot-ab.bin"
	UBOOT_OUT_ENV="${OUT}/${MTK_PLAT}/u-boot-initial-env_ab"
    else
	MTK_DEFCONFIG=$(config_value "$1" uboot.defconfig)
	UBOOT_OUT_BIN="${OUT}/${MTK_PLAT}/u-boot.bin"
	UBOOT_OUT_ENV="${OUT}/${MTK_PLAT}/u-boot-initial-env_noab"
    fi

    if [ -z "${MTK_DEFCONFIG}" ]; then
	if [[ "${build_ab}" == true ]]; then
	    echo "uboot: skip build, ab_defconfig not provided"
	else
	    echo "uboot: skip build, defconfig not provided"
	fi
	return
    fi

    ! [ -d "${OUT}/${MTK_PLAT}" ] && mkdir "${OUT}/${MTK_PLAT}"

    pushd "${UBOOT}"
    [[ "${clean}" == true ]] && clean_uboot "${MTK_PLAT}"

    aarch64_env
    export ARCH=arm64

    make "${MTK_DEFCONFIG}"
    make -j$(nproc)

    ./scripts/get_default_envs.sh > "${UBOOT_OUT_ENV}"
    cp u-boot.bin "${UBOOT_OUT_BIN}"

    unset ARCH
    clear_vars
    popd
}

# main
function usage {
      cat <<DELIM__
usage: $(basename $0) [options]

$ $(basename $0) --config=pumpkin-i500.yaml --build_ab

Options:
  --config   Mediatek board config file
  --build_ab (OPTIONAL) use ab defconfig
  --clean    (OPTIONAL) clean before build
DELIM__
    exit 1
}

function main {
    local build_ab=false
    local clean=false
    local config

    local OPTS=$(getopt -o '' -l build_ab,clean,config: -- "$@")
    eval set -- "${OPTS}"

    while true; do
	case "$1" in
	    --build_ab) build_ab=true; shift ;;
	    --config) config=$(readlink -e "$2"); shift 2 ;;
	    --clean) clean=true; shift ;;
	    --) shift; break ;;
	    *) usage ;;
	esac
    done

    # check arguments
    [ -z "${config}" ] && echo "Cannot find board config file" && usage

    # build uboot
    check_env
    build_uboot "${config}" "${clean}" "${build_ab}"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
