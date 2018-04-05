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

exit

echo "${highlight}Running for ${obsids[@]} ${reset}"

for ObsID in "${obsids[@]}"
do
	path_pipeline="$clean$ObsID/pipeline_out/"
	path_mp="$products$ObsID/products/MP/"
    echo "${highlight}Saving to $path_mp ${reset}"

	path_a="${path_pipeline}nu${ObsID}A01_cl.evt"
	path_b="${path_pipeline}nu${ObsID}B01_cl.evt"

	echo "${highlight}MPreadevents ${reset}"
	MPreadevents $path_a $path_b

	path_a_ev="${path_mp}nu${ObsID}A01_ev.p"
	path_b_ev="${path_mp}nu${ObsID}B01_ev.p"

    if [ ! -d "$path_mp" ]; then
        mkdir $path_mp
    fi

	mv "${path_pipeline}nu${ObsID}A01_cl_ev.p" $path_a_ev
	mv "${path_pipeline}nu${ObsID}B01_cl_ev.p" $path_b_ev

	echo "${highlight}MPcalibrate ${reset}"
	MPcalibrate $path_a_ev $path_b_ev

	path_a_calib="${path_mp}nu${ObsID}A01_ev_calib.p"
	path_b_calib="${path_mp}nu${ObsID}B01_ev_calib.p"

	echo "${highlight}MPlcurve ${reset}"
	MPlcurve $path_a_calib $path_b_calib -b 0.001 -e 3 30 --safe-interval 100 300

	path_a_lc="${path_mp}nu${ObsID}A01_E3-30_lc.p"
	path_b_lc="${path_mp}nu${ObsID}B01_E3-30_lc.p"

	echo "${highlight}MPfspec ${reset}"
	MPfspec $path_a_lc $path_b_lc -k CPDS -o leahy --norm Leahy

	path_rms_cpds="${path_mp}rms_cpds.p"

	$SCRIPT_DIR/pickle2hdf5 $path_rms_cpds
done
