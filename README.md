# Bootloaders build tools

Scripts to build various bootloaders (A-TF, U-Boot, OP-TEE) for MediaTek AIoT

Dependencies:
``` {.sh}
$ sudo apt install bc bison build-essential curl flex git libssl-dev python3 python3-pip meson wget -y
$ pip3 install pycryptodome pyelftools shyaml --user
```

## Build bl2
``` {.sh}
usage: build_bl2.sh [options]

$ build_bl2.sh --config=i500-pumpkin.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
  --mode     (OPTIONAL) [release|debug|factory] mode (default: release)
  --help     (OPTIONAL) display usage
```

## Build libdram
``` {.sh}
usage: build_libdram.sh [options]

$ build_libdram.sh --config=i500-pumpkin.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
  --mode     (OPTIONAL) [release|debug|factory] mode (default: release)
  --help     (OPTIONAL) display usage
```

## Build little kernel
``` {.sh}
usage: build_lk.sh [options]

$ build_lk.sh --config=i500-pumpkin.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
  --mode     (OPTIONAL) [release|debug|factory] mode (default: release)
  --help     (OPTIONAL) display usage
```

## Build uboot
``` {.sh}
usage: build_uboot.sh [options]

$ build_uboot.sh --config=i500-pumpkin.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
  --mode     (OPTIONAL) [release|debug|factory] mode (default: release)
  --help     (OPTIONAL) display usage
```

## Build optee
``` {.sh}
usage: build_optee.sh [options]

$ build_optee.sh --config=i500-pumpkin.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
  --mode     (OPTIONAL) [release|debug|factory] mode (default: release)
  --help     (OPTIONAL) display usage
```

## Build fip
``` {.sh}
usage: build_fip.sh [options]

$ build_fip.sh --config=i500-pumpkin.yaml --bl32=tee.bin --bl33=u-boot.bin --output=fip-test.bin

Options:
  --config   Mediatek board config file
  --bl32     Path to bl32 binary
  --bl33     Path to bl33 binary
  --output   (OPTIONAL) Output name of fip binary
  --clean    (OPTIONAL) clean before build
  --mode     (OPTIONAL) [release|debug|factory] mode (default: release)
  --help     (OPTIONAL) display usage
```

## Build ALL
``` {.sh}
usage: build_all.sh [options]

$ build_all.sh --config=i500-pumpkin.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
  --mode     (OPTIONAL) [release|debug|factory] mode (default: release)
  --help     (OPTIONAL) display usage
```

## Setup Android
``` {.sh}
usage: setup_android.sh [options]

$ setup_android.sh --aosp=/home/julien/Documents/mediatek/android --branch=jmasson/update-binaries

Options:
  --aosp     Android Root path
  --branch   Branch name
  --clean    (OPTIONAL) clean up AOSP projects
  --help     (OPTIONAL) display usage
```

## Release Android
``` {.sh}
usage: release_android.sh [options]

$ release_android.sh --aosp=/home/julien/Documents/mediatek/android

Options:
  --aosp     Android Root path
  --commit   (OPTIONAL) commit binaries in AOSP
  --config   (OPTIONAL) release ONLY for this board config file
  --help     (OPTIONAL) display usage
  --mode     (OPTIONAL) [release|debug|factory] build only one mode
  --no-build (OPTIONAL) don't rebuild the images
  --silent   (OPTIONAL) silent build commands
  --skip-ta  (OPTIONAL) skip build Trusted Applications

By default release and debug modes are built.
```

## Secure
``` {.sh}
usage: secure.sh function

Functions supported can be found in secure.sh
```
