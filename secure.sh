#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

SECURE_TOOLS="${ROOT}/mtk-secure-boot-tools"
KEYS="${BUILD}/.keys"
SECURE="${BUILD}/config/secure"

# Secure: BL1 to BL2
EFUSE_KEY="efuse.pem"

# Secure: BL2 to fip images
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

function generate_efuse_key {
    ! [ -d "${KEYS}" ] && mkdir -p "${KEYS}"
    openssl genrsa -out "${KEYS}/${EFUSE_KEY}" 2048
}

function check_efuse_key {
    if [ -a "${KEYS}/${EFUSE_KEY}" ]; then
        echo "EFUSE key found: ${KEYS}/${EFUSE_KEY}"
    else
        echo "EFUSE key not found, generate new one ..."
        generate_efuse_key
    fi
}

function secure_boot_supported {
    local board="$1"
    [ -d "${SECURE}/${board}" ]
}

function sign_bl2_image {
    local board="$1"
    local input="$2"
    local output="$3"
    local pbp_py="${SECURE_TOOLS}/sign-image_v2/pbp.py"
    local hdr_tool_py="${SECURE_TOOLS}/secure_chip_tools/dev-info-hdr-tool.py"
    local key_ini="${SECURE}/key.ini"
    local pl_gfh="${SECURE}/${board}/pl_gfh_config_pss.ini"

    pushd "${KEYS}"

    check_efuse_key

    # update key.ini with efuse key
    cp "${key_ini}" key.ini
    sed -i 's|EFUSE_KEY|'${KEYS}/${EFUSE_KEY}'|g' key.ini

    python2.7 "${pbp_py}" -i key.ini -g "${pl_gfh}" -func sign -o "${output}" "${input}"
    python2.7 "${hdr_tool_py}" emmc "${output}" "${output}"
    rm key.ini

    popd
}

function get_efuse_pub_key {
    local -n ref_efuse_pub_key="$1"
    local der_extractor="${SECURE_TOOLS}/sign-image_v2/der_extractor/der_extractor"
    local efuse_pub_key="${EFUSE_KEY}_pub.der"
    local efuse_key_h="efuse_key.h"

    # public efuse key
    openssl rsa -in "${KEYS}/${EFUSE_KEY}" -out "${efuse_pub_key}" -outform DER --pubout

    # header file
    chmod +x "${der_extractor}"
    "${der_extractor}" "${efuse_pub_key}" "${efuse_key_h}" ANDROID_SBC

    # extract public key
    ref_efuse_pub_key=$(cat "${efuse_key_h}" | perl -0777 -ne '$_=$1 if /(?:PUBK\s+)(.*(\\)?\n)+#endif/s; s/([\\\n, ]|0x)//g; print')

    rm "${efuse_pub_key}" "${efuse_key_h}"
}

function update_efuse_xml {
    local board="$1"
    local pub_key_n=""

    cp "${SECURE}/${board}/efuse.xml" efuse.xml

    # fill public key
    get_efuse_pub_key pub_key_n
    sed -i 's/EFUSE_PUB_KEY/'${pub_key_n}'/' efuse.xml
}

function add_secure_boot_files {
    local package="$1"
    local board="$2"

    # add efuse configuration
    update_efuse_xml "${board}"
    zip -ju "${package}" efuse.xml
    rm efuse.xml

    # add efuse private key
    zip -ju "${package}" "${KEYS}/${EFUSE_KEY}"

    # add secure board files
    zip -ju "${package}" "${SECURE}/${board}/${board}_android_scatter.txt"
    zip -ju "${package}" "${SECURE}/${board}/${board}_preloader.bin"
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

    # add Secure Boot files
    if $(secure_boot_supported "${board}"); then
        add_secure_boot_files "${package}" "${board}"
    else
        warning "Secure boot not supported for ${board}"
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
