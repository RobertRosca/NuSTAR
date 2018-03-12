#!/bin/bash

# http://www.bahmanm.com/blogs/command-line-options-how-to-parse-in-bash-using-getopt

# read the options
TEMP=`getopt -o a:c:o: --long clean:,products:,xselect_scripts: -n 'run_native_nupipeline.sh' -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        a|--clean)
            case "$2" in
                *) clean=$2 ; shift 2 ;;
            esac ;;
        c|--products)
            case "$2" in
                "") shift 2 ;;
                *) products=$2 ; shift 2 ;;
            esac ;;
        o|--xselect_scripts)
            case "$2" in
                "") shift 2 ;;
                *) xselect_scripts=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

# set paths
# echo "clean = $clean"
# echo "products = $products"
# echo "xselect_scripts = $xselect_scripts"

xselect_scripts=( $xselect_scripts )

highlight=`tput setaf 6`
reset=`tput sgr0`

echo "${highlight}Running init ${reset}"

HEADAS="/home/SOFTWARE/heasoft-6.16/x86_64-unknown-linux-gnu-libc2.19-0"
CALDB="/home/sw-astro/caldb/software/tools"

export HEADAS
export CALDB

source $HEADAS/headas-init.sh
source $CALDB/caldbinit.sh

echo "${highlight}Running for ${xselect_scripts[@]} ${reset}"

for xco in ${xselect_scripts[@]}
do
    # move to temp dir
    cd $(mktemp -d)
    TMP_DIR=${PWD}

    ObsID=$(basename $(dirname $(dirname $xco)))

    echo moved to temp dir $TMP_DIR

    if [ ! -d "$clean$ObsID" ]; then
        echo "${highlight}Observation not found at $clean$ObsID"
        exit 1
    fi

    log_file="$products$ObsID"/xselect_scripts/$(basename $xco).log""

    if [ ! -d "$products$ObsID/products/" ]; then
        mkdir -p $products$ObsID/products/
    fi

    xselect @$xco | tee -a "$log_file"

    echo "${highlight}Finished xselect ${reset}"

    if [[ $(dirname $TMP_DIR) -ef /tmp/ ]]; then
        echo removing $TMP_DIR
        rm -r -f $TMP_DIR
    fi
done
