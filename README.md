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

$ build_bl2.sh --config=pumpkin-i500.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
```

## Build libdram
``` {.sh}
usage: build_libdram.sh [options]

$ build_libdram.sh --config=pumpkin-i500.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
```

## Build little kernel
``` {.sh}
usage: build_lk.sh [options]

$ build_lk.sh --config=pumpkin-i500.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
```

## Build uboot
``` {.sh}
usage: build_uboot.sh [options]

$ build_uboot.sh --config=pumpkin-i500.yaml --build_ab

Options:
  --config   Mediatek board config file
  --build_ab (OPTIONAL) use ab defconfig
  --clean    (OPTIONAL) clean before build
```

## Build optee
``` {.sh}
usage: build_optee.sh [options]

$ build_optee.sh --config=pumpkin-i500.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
```

## Build fip
``` {.sh}
usage: build_fip.sh [options]

$ build_fip.sh --config=pumpkin-i500.yaml --bl32=tee.bin --bl33=u-boot.bin --output=fip-test.bin

Options:
  --config   Mediatek board config file
  --bl32     Path to bl32 binary
  --bl33     Path to bl33 binary
  --output   Output name of fip binary
  --clean    (OPTIONAL) clean before build
```

## Build ALL
``` {.sh}
usage: build_all.sh [options]

$ build_all.sh --config=pumpkin-i500.yaml

Options:
  --config   Mediatek board config file
  --clean    (OPTIONAL) clean before build
```

## Release Android
``` {.sh}
usage: release_android.sh [options]

$ release_android.sh --aosp=/home/julien/Documents/mediatek/android

Options:
  --aosp     Android Root path
  --clean    (OPTIONAL) clean before build
```
