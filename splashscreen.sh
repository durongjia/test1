#!/bin/bash

set -e
set -u
set -o pipefail

SRC=$(dirname "$(readlink -e "$0")")
source "${SRC}/utils.sh"

function generate_splashscreen_image {
    local image=$(find_path "$1") && shift
    local options="$@"
    local bmp="splash.bmp"

    [ -z "${image}" ] && error_usage_exit "Cannot find image"

    convert "${image}" ${options} -alpha off -colors 256 -compress NONE "BMP3:${bmp}"
    cat "${bmp}" > "splashscreen.img"

    rm "${bmp}"
}

# main
function usage {
    cat <<DELIM__
usage: $(basename "$0") IMAGE_PATH [convert options]

Generate splashscreen.img file from IMAGE_PATH.

For more infos on [convert options]:
$ man convert

DELIM__
}

function main {
    generate_splashscreen_image "$@"
}

if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi
