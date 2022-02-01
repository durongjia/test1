#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/build_bl2.sh"
source "${SRC}/build_fip.sh"
source "${SRC}/build_lk.sh"
source "${SRC}/build_optee.sh"
source "${SRC}/build_uboot.sh"
source "${SRC}/utils.sh"

function build_all {
    local clean="${2:-false}"
    local mode="${3:-release}"
    local secure="$4"
    local out_dir=$(out_dir "$1" "${mode}")

    if [[ "${clean}" == true ]] && [ -d "${out_dir}" ]; then
        rm -rf "${out_dir}"
    fi

    # bl2
    build_bl2 "$@"

    # lk
    build_lk "$@"

    # uboot
    build_uboot "$1" "$2" false "$3" "$4"

    # uboot build ab
    build_uboot "$1" "$2" true "$3" "$4"

    # optee
    build_optee "$@"

    # fip
    build_fip "$1" "${out_dir}/tee-${mode}.bin" "${out_dir}/u-boot-${mode}.bin" \
              "fip_${mode}_noab.bin" "${clean}" "${mode}" "${secure}"

    # fip ab
    build_fip "$1" "${out_dir}/tee-${mode}.bin" "${out_dir}/u-boot-${mode}-ab.bin" \
              "fip_${mode}_ab.bin" "${clean}" "${mode}" "${secure}"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
