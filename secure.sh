#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

KEYS="${BUILD}/.keys"
ROT_KEY="rot_key.pem"

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
            echo "ROT key not found: ${rot_key_config}"
            exit 1
        fi
    else
        if ! [ -a "${KEYS}/${ROT_KEY}" ]; then
            echo "No ROT key found, generate new one ..."
            generate_rot_key
        fi
        rot_key_ref="${KEYS}/${ROT_KEY}"
    fi
}
