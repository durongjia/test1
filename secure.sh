#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

KEYS="${BUILD}/.keys"
ROT_KEY="rot_key.pem"

# Android Verified Boot (AVB)
AVB_KEY="avb.pem"
AVB_PUB_KEY="avb_pub.pem"

function generate_rot_key {
    ! [ -d "${KEYS}" ] && mkdir -p "${KEYS}"
    openssl genrsa -out "${KEYS}/${ROT_KEY}" 2048
}

function get_rot_key {
    local rot_key_config=$(config_value "$1" secure.rot_key)
    local -n rot_key_ref="$2"

    if [ -n "${rot_key_config}" ]; then
        if [ -a "${rot_key_config}" ]; then
            rot_key_ref="${rot_key_config}"
        else
            error_exit "ROT key not found: ${rot_key_config}"
        fi
    else
        if ! [ -a "${KEYS}/${ROT_KEY}" ]; then
            echo "No ROT key found, generate new one ..."
            generate_rot_key
        fi
        rot_key_ref="${KEYS}/${ROT_KEY}"
    fi
}

function get_avb_key {
    local avb_key_config=$(config_value "$1" secure.avb_key)
    local -n avb_key_ref="$2"

    if [ -n "${avb_key_config}" ]; then
        if [ -a "${avb_key_config}" ]; then
            avb_key_ref="${avb_key_config}"
        else
            error_exit "AVB key not found: ${avb_key_config}"
        fi
    else
        if [ -a "${KEYS}/${AVB_KEY}" ]; then
            avb_key_ref="${KEYS}/${AVB_KEY}"
        fi
    fi
}

function get_avb_pub_key {
    local avb_pub_key_config=$(config_value "$1" secure.avb_pub_key)
    local -n avb_pub_key_ref="$2"

    if [ -n "${avb_pub_key_config}" ]; then
        if [ -a "${avb_pub_key_config}" ]; then
            avb_pub_key_ref="${avb_pub_key_config}"
        else
            error_exit "AVB public key not found: ${avb_pub_key_config}"
        fi
    else
        if [ -a "${KEYS}/${AVB_PUB_KEY}" ]; then
            avb_pub_key_ref="${KEYS}/${AVB_PUB_KEY}"
        fi
    fi
}

function generate_avb_keys {
    local avb_key="${KEYS}/${AVB_KEY}"
    local avb_pub_key="${KEYS}/${AVB_PUB_KEY}"

    ! [ -d "${KEYS}" ] && mkdir -p "${KEYS}"

    openssl genrsa -out "${avb_key}" 4096
    avbtool extract_public_key --key "${avb_key}" --output "${avb_pub_key}"

    printf "AVB keys generated here:\n%s\n%s\n" "${avb_key}" "${avb_pub_key}"
}

function generate_secure_package {
    local board=$(board_name "$1")
    local out_dir="$2"
    local package="secure_${board}.zip"
    local rot_key=""
    local avb_key=""
    local avb_pub_key=""

    pushd "${KEYS}"
    [ -a "${package}" ] && rm "${package}"

    # add Root Of Trust key
    get_rot_key "$1" rot_key
    zip -ju "${package}" "${rot_key}"

    # add Android Verified Boot keys
    get_avb_key "$1" avb_key
    if [ -n "${avb_key}" ]; then
        zip -ju "${package}" "${avb_key}"
    fi
    get_avb_pub_key "$1" avb_pub_key
    if [ -n "${avb_pub_key}" ]; then
        zip -ju "${package}" "${avb_pub_key}"
    fi

    mv "${package}" "${out_dir}/"

    popd
}

# main
function usage {
    cat <<DELIM__
usage: $(basename "$0") function

Functions supported can be found in "$0"
DELIM__
}

function main {
    if ! [ $# -eq 1 ]; then
        usage
    else
        local command="$1"
        "${command}"
    fi
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
