#!/bin/bash

# http://www.bahmanm.com/blogs/command-line-options-how-to-parse-in-bash-using-getopt

# read the options
TEMP=`getopt -o a:c:o: --long archive:,clean:,obsids: -n 'run_native_nupipeline.sh' -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        a|--archive)
            case "$2" in
                *) archive=$2 ; shift 2 ;;
            esac ;;
        c|--clean)
            case "$2" in
                "") shift 2 ;;
                *) clean=$2 ; shift 2 ;;
            esac ;;
        o|--obsids)
            case "$2" in
                "") shift 2 ;;
                *) obsids=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

# set paths
# echo "archive = $archive"
# echo "clean = $clean"
# echo "obsids = $obsids"

obsids=( $obsids )

highlight=`tput setaf 6`
reset=`tput sgr0`

echo "${highlight}Running init ${reset}"

HEADAS="/home/SOFTWARE/heasoft-6.16/x86_64-unknown-linux-gnu-libc2.19-0"
CALDB="/home/sw-astro/caldb/software/tools"

export HEADAS
export CALDB

source $HEADAS/headas-init.sh
source $CALDB/caldbinit.sh

echo "${highlight}Running for ${obsids[@]} ${reset}"

for ObsID in "${obsids[@]}"
do
    if [ ! -d "$archive$ObsID" ]; then
        echo "${highlight}Observation not found at $archive$ObsID"
        continue
    fi

	echo "${highlight}Running on $ObsID ${reset}"

    # move to temp dir
    cd $(mktemp -d)
    TMP_DIR=${PWD}

    echo moved to temp dir $TMP_DIR

    echo "${highlight}Running nupipeline with indir=$archive$ObsID steminputs=nu$ObsID outdir=$clean$ObsID/pipeline_out/${reset}"

    log_file="$clean$ObsID"/pipeline.log""

    mkdir $clean$ObsID

    nupipeline indir=$archive$ObsID steminputs=nu$ObsID outdir=$clean$ObsID"/pipeline_out/" | tee -a "$log_file"

    if [[ $(dirname $TMP_DIR) -ef /tmp/ ]]; then
        echo removing $TMP_DIR
        rm -r -f $TMP_DIR
    fi
done
