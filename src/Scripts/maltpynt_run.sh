#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# http://www.bahmanm.com/blogs/command-line-options-how-to-parse-in-bash-using-getopt

# read the options
TEMP=`getopt -o a:c:o: --long clean:,products:,obsids: -n 'run_native_nupipeline.sh' -- "$@"`
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
        o|--obsids)
            case "$2" in
                "") shift 2 ;;
                *) obsids=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

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


if [ -z "$clean" ]; then
    path_1="/home/robert/Scratch/.nustar_archive_cl/"
    path_2="/export/data/robertr/.nustar_archive_cl/"
    if [ -d "$path_1" ]; then
        clean=$path_1
    elif [ -d "$path_2" ]; then
        clean=$path_2
    else
        echo "Clean path not found, enter manually with --clean"
        exit
    fi
fi

if [ -z "$products" ]; then
    path_1="/home/robert/Scratch/.nustar_archive_pr/"
    path_2="/export/data/robertr/.nustar_archive_pr/"
    if [ -d "$path_1" ]; then
        products=$path_1
    elif [ -d "$path_2" ]; then
        products=$path_2
    else
        echo "Clean path not found, enter manually with --products"
        exit
    fi
fi

if [ -z "$obsids" ]; then
    echo "No obsids entered, exiting"
    exit
fi

echo "${highlight}Running for ${obsids[@]} ${reset}"

for ObsID in "${obsids[@]}"
do
	path_pipeline="$clean$ObsID/pipeline_out/"
	path_mp="$products$ObsID/products/MP/"
    echo "${highlight}Saving to $path_mp ${reset}"

    if [ ! -d "$path_mp" ]; then
        mkdir $path_mp
    fi

	path_a="${path_pipeline}nu${ObsID}A01_cl.evt"
	path_b="${path_pipeline}nu${ObsID}B01_cl.evt"

	echo "${highlight}MPreadevents ${reset}"
	MPreadevents $path_a $path_b

	path_a_ev="${path_mp}nu${ObsID}A01_ev.p"
	path_b_ev="${path_mp}nu${ObsID}B01_ev.p"

	mv "${path_pipeline}nu${ObsID}A01_cl_ev.p" $path_a_ev
	mv "${path_pipeline}nu${ObsID}B01_cl_ev.p" $path_b_ev

	echo "${highlight}MPcalibrate ${reset}"
	MPcalibrate $path_a_ev $path_b_ev

	path_a_calib="${path_mp}nu${ObsID}A01_ev_calib.p"
	path_b_calib="${path_mp}nu${ObsID}B01_ev_calib.p"

	echo "${highlight}MPlcurve - 0.002 ${reset}"
	MPlcurve $path_a_calib $path_b_calib -b 0.002 --safe-interval 100 300 --noclobber

	path_a_lc="${path_mp}nu${ObsID}A01_lc.p"
	path_b_lc="${path_mp}nu${ObsID}B01_lc.p"

    for bin in 0.002 0.25 2
        do
            if [ ! -d "$path_mp$bin" ]; then
                mkdir $path_mp/$bin
            fi
            # dynamical includes normal pds

            echo "${highlight}MPfspec - dynamical - $bin ${reset}"
            MPfspec $path_a_lc $path_b_lc -b $bin -k CPDS

        	echo "${highlight}nc2hdf5 - $bin ${reset}"
        	#$SCRIPT_DIR/nc2hdf5 "${path_mp}nu${ObsID}A01_pds.p"
            #$SCRIPT_DIR/nc2hdf5 "${path_mp}nu${ObsID}B01_pds.p"
            $SCRIPT_DIR/nc2hdf5 "${path_mp}nu${ObsID}01_cpds.p"

            #mv "${path_mp}nu${ObsID}A01_pds.p" ${path_mp}/$bin/
            #mv "${path_mp}nu${ObsID}B01_pds.p" ${path_mp}/$bin/
            mv "${path_mp}nu${ObsID}01_cpds.p" ${path_mp}/$bin/
            #mv "${path_mp}nu${ObsID}A01_pds.hdf5" ${path_mp}/$bin/
            #mv "${path_mp}nu${ObsID}B01_pds.hdf5" ${path_mp}/$bin/
            mv "${path_mp}nu${ObsID}01_cpds.hdf5" ${path_mp}/$bin/
    done
done
