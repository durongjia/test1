#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

KEYS="${BUILD}/.keys"
ROT_KEY="rot_key.pem"
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
    local avb_pub_key="${KEYS}/${AVB_PUB_KEY}"
    local avb_priv_key="${KEYS}/avb_priv.pem"

    ! [ -d "${KEYS}" ] && mkdir -p "${KEYS}"

    openssl genrsa -out "${avb_priv_key}" 4096
    avbtool extract_public_key --key "${avb_priv_key}" --output "${avb_pub_key}"

    printf "AVB keys generated here:\n%s\n%s\n" "${avb_priv_key}" "${avb_pub_key}"
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
