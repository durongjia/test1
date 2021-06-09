#!/bin/bash

SRC=$(dirname $(readlink -e "$0"))
source "${SRC}/utils.sh"

ATF="${ROOT}/arm-trusted-firmware"

function clean_fip {
    local MTK_PLAT="$1"
    pushd "${ATF}"
    [ -d "build/${MTK_PLAT}" ] && rm -r "build/${MTK_PLAT}"
    popd
}

function build_fip {
    local MTK_PLAT=$(config_value "$1" plat)
    local MTK_CFLAGS=$(config_value "$1" fip.cflags)
    local LOG_LEVEL=$(config_value "$1" fip.log_level)
    local BL32_BIN="$2"
    local BL33_BIN="$3"
    local FIP_BIN="$4"

    local clean="$5"
    ! [ -d "${OUT}/${MTK_PLAT}" ] && mkdir "${OUT}/${MTK_PLAT}"
    [[ "${clean}" == true ]] && clean_fip "${MTK_PLAT}"

    pushd "${ATF}"
    arm-none_env

    make E=0 CFLAGS="${MTK_CFLAGS}" PLAT="${MTK_PLAT}" BL32="${BL32_BIN}" BL33="${BL33_BIN}" \
	 SPD=opteed LOG_LEVEL=$LOG_LEVEL NEED_BL32=yes NEED_BL33=yes bl31 fip
    cp "build/${MTK_PLAT}/release/fip.bin" "${OUT}/${MTK_PLAT}/${FIP_BIN}"

    clear_vars
    popd
}

# main
function usage {
      cat <<DELIM__
usage: $(basename $0) [options]

$ $(basename $0) --config=pumpkin-i500.yaml --bl32=tee.bin --bl33=u-boot.bin --output=fip-test.bin

Options:
  --config   Mediatek board config file
  --bl32     Path to bl32 binary
  --bl33     Path to bl33 binary
  --output   Output name of fip binary
  --clean    (OPTIONAL) clean before build
DELIM__
    exit 1
}

function main {
    local bl32
    local bl33
    local config
    local clean=false
    local output

    local OPTS=$(getopt -o '' -l bl32:,bl33:,clean,config:,output: -- "$@")
    eval set -- "${OPTS}"

    while true; do
	case "$1" in
	    --bl32) bl32=$(readlink -e "$2"); shift 2 ;;
	    --bl33) bl33=$(readlink -e "$2"); shift 2 ;;
	    --clean) clean=true; shift ;;
	    --config) config=$(readlink -e "$2"); shift 2 ;;
	    --output) output=$2; shift 2 ;;
	    --) shift; break ;;
	    *) usage; break ;;
	esac
    done

    # check arguments
    [ -z "${config}" ] && echo "Cannot find board config file" && usage
    [ -z "${bl32}" ] && echo "Cannot find bl32" && usage
    [ -z "${bl33}" ] && echo "Cannot find bl33" && usage
    [ -z "${output}" ] && echo "Please provide fip output name" && usage

    # build fip
    check_env
    build_fip "${config}" "${bl32}" "${bl33}" "${output}" "${clean}"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi