#!/bin/bash

# set paths in .bashrc
archive=$NU_ARCHIVE
archive_live=$NU_ARCHIVE_LIVE

clean=$NU_ARCHIVE_CL
clean_live=$NU_ARCHIVE_CL_LIVE

notify-send "Running nupipeline on $# observations" -t 5

highlight=`tput setaf 6`
reset=`tput sgr0`

echo "${highlight}Running for $@ ${reset}"

for ObsID in "$@"
do
	# move to temp dir
	cd $(mktemp -d)
	TMP_DIR=${PWD}

	echo moved to temp dir $TMP_DIR

	echo "${highlight}Running on $ObsID ${reset}"
	mkdir $clean_live$ObsID

	echo "${highlight}Running init ${reset}"
	source $HEADAS/headas-init.sh
	source $CALDB/software/tools/caldbinit.sh

	if [ ! -d "$archive$ObsID" ]; then
		echo "${highlight}Observation not found at $archive$ObsID"
		exit 1
	fi

	if [ -d "$archive_live$ObsID" ]; then
		echo "${highlight}$ObsID already in live $archive_live ${reset}"
		#exit 1
	else
		echo "${highlight}Copying $ObsID to $archive_live ${reset}"
		rsync -a --info=progress2 $archive$ObsID/ $archive_live$ObsID/
	fi

	echo "${highlight}Running nupipeline with indir=$archive_live$ObsID steminputs=nu$ObsID outdir=$clean_live$ObsID/pipeline_out/${reset}"

	notify-send "Running nupipeline on $ObsID" -t 5

	log_file="$clean_live$ObsID"/pipeline_vm.log""

	nupipeline indir=$archive_live$ObsID steminputs=nu$ObsID outdir=$clean_live$ObsID"/pipeline_out/" | tee -a "$log_file"

	echo "${highlight}Finished nupipeline ${reset}"

	rsync -a --info=progress2 --remove-source-files $clean_live$ObsID/ $clean$ObsID/

	echo "${highlight}Removing $archive_live$ObsID ${reset}"

	rm -r -f $archive_live$ObsID

	rm -r -f $clean_live$ObsID

	echo "${highlight}DONE ${reset}"

	notify-send "Completed $ObsID nupipeline" -t 5

	echo removing $TMP_DIR
	rm -r -f $TMP_DIR
done

#read -p "Press enter to continue
