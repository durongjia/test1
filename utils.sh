#!/bin/bash

BUILD=$(dirname "$(readlink -e "$0")")
ROOT=$(readlink -e "${BUILD}/../")
OUT="${ROOT}/out"
TOOLCHAINS="${ROOT}/toolchains"

INIT_PATH=$PATH

function pushd {
    command pushd "$@" > /dev/null
}

function popd {
    command popd > /dev/null
}

function aarch64_env {
    export PATH="${TOOLCHAINS}/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu/bin:$PATH"
    export CROSS_COMPILE=aarch64-linux-gnu-
}

function check_aarch64 {
    if ! [ -d "${TOOLCHAINS}/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu" ]; then
        pushd "${TOOLCHAINS}"
        wget https://releases.linaro.org/components/toolchain/binaries/latest-7/aarch64-linux-gnu/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu.tar.xz
        tar -xvf gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu.tar.xz
        popd
    fi
}

function arm-none_env {
    export PATH="${TOOLCHAINS}/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin:$PATH"
    export CROSS_COMPILE=aarch64-none-linux-gnu-
}

function check_arm-none {
    if ! [ -d "${TOOLCHAINS}/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu" ]; then
        pushd "${TOOLCHAINS}"
        wget https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
        tar -xvf gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
        popd
    fi
}

function clear_vars {
    export PATH=$INIT_PATH
    unset ARCH
    unset CROSS_COMPILE
}

function check_env {
    # out directory
    ! [ -d "${OUT}" ] && mkdir "${OUT}"

    # toolchains
    ! [ -d "${TOOLCHAINS}" ] && mkdir "${TOOLCHAINS}"
    check_aarch64
    check_arm-none
}

function config_value {
    cat "$1" | shyaml --quiet get-value "$2"
}

function out_dir {
    local yaml_config=$(basename "$1")
    local mode="${2:-release}"

    echo "${OUT}/${yaml_config%.yaml}/${mode}"
}

function usage {
    cat <<DELIM__
usage: $(basename "$0") [options]

$ $(basename "$0") --config=i500-pumpkin.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
  --debug    (OPTIONAL) build bootloader in debug mode
DELIM__
    exit 1
}

function main {
    local script=$(basename "$0")
    local build="${script%.*}"
    local clean=false
    local config=""
    local mode="release"

    local opts=$(getopt -o '' -l clean,config:,debug -- "$@")
    eval set -- "${opts}"

    while true; do
        case "$1" in
            --config) config=$(readlink -e "$2"); shift 2 ;;
            --clean) clean=true; shift ;;
            --debug) mode=debug; shift ;;
            --) shift; break ;;
            *) usage ;;
        esac
    done

    # check arguments
    [ -z "${config}" ] && echo "Cannot find board config file" && usage

    # build
    check_env
    ${build} "${config}" "${clean}" "${mode}"
}
