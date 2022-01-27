#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

KEYS="${BUILD}/.keys"
ROT_KEY="rot_key.pem"

function generate_rot_key_if_unavailable {
    local rot_key="${KEYS}/${ROT_KEY}"
    if [ -a "${rot_key}" ]; then
        echo "ROT key found here: ${rot_key}"
    else
        ! [ -d "${KEYS}" ] && mkdir -p "${KEYS}"
        openssl genrsa -out "${rot_key}" 2048
        echo "ROT key generated here: ${rot_key}"
    fi
}
