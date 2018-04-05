#!/bin/bash

# http://www.bahmanm.com/blogs/command-line-options-how-to-parse-in-bash-using-getopt

# read the options
TEMP=`getopt -o c:o: --long clean:,obsids: -n 'run_native_nupipeline.sh' -- "$@"`
eval set -- "$TEMP"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
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

obsids=( $obsids )

highlight=`tput setaf 6`
reset=`tput sgr0`

echo "${highlight}Running for ${obsids[@]} ${reset}"

for ObsID in "${obsids[@]}"
do
	path_pipeline="$clean$ObsID/pipeline_out/"
	path_mp="${path_pipeline}MP0/"

	path_a="${path_pipeline}nu${ObsID}A01_cl.evt"
	path_b="${path_pipeline}nu${ObsID}B01_cl.evt"

	echo "${highlight}MPreadevents${obsids[@]} ${reset}"
	MPreadevents $path_a $path_b

	path_a_ev="${path_mp}nu${ObsID}A01_ev.p"
	path_b_ev="${path_mp}nu${ObsID}B01_ev.p"

    if [ ! -d "$path_mp" ]; then
        mkdir $path_mp
    fi

	mv "${path_pipeline}nu${ObsID}A01_cl_ev.p" $path_a_ev
	mv "${path_pipeline}nu${ObsID}B01_cl_ev.p" $path_b_ev

	echo "${highlight}MPcalibrate${obsids[@]} ${reset}"
	MPcalibrate $path_a_ev $path_b_ev

	path_a_calib="${path_mp}nu${ObsID}A01_ev_calib.p"
	path_b_calib="${path_mp}nu${ObsID}B01_ev_calib.p"

	echo "${highlight}MPlcurve${obsids[@]} ${reset}"
	MPlcurve $path_a_calib $path_b_calib -b 0.0002 -e 3 30 --safe-interval 100 300

	path_a_lc="${path_mp}nu${ObsID}A01_E3-30_lc.p"
	path_b_lc="${path_mp}nu${ObsID}B01_E3-30_lc.p"

	echo "${highlight}MPfspec${obsids[@]} ${reset}"
	MPfspec $path_a_lc $path_b_lc -k CPDS -o leahy --norm leahy

	path_rms_cpds="${path_mp}rms_cpds.p"

	$SCRIPT_DIR/pickle2hdf5 $path_rms_cpds
done