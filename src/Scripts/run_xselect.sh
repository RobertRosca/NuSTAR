#!/bin/bash

# set paths in .bashrc
clean=$NU_ARCHIVE_CL
clean_live=$NU_ARCHIVE_CL_LIVE

products=$NU_ARCHIVE_PR
products_live=$NU_ARCHIVE_PR_LIVE

highlight=`tput setaf 6`
reset=`tput sgr0`

echo "${highlight}Running init ${reset}"
source $HEADAS/headas-init.sh
source $CALDB/software/tools/caldbinit.sh

for xco in "$@"
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

	if [ -d "$clean_live$ObsID/pipeline_out/" ]; then
		echo "${highlight}$ObsID already in live $clean_live ${reset}"
		#exit 1
	else
		echo "${highlight}Copying $ObsID to $clean_live ${reset}"
		rsync -a --info=progress2 $clean$ObsID/ $clean_live$ObsID/
	fi

	notify-send "Running xselect on $ObsID" -t 5

	log_file="$products_live$ObsID"/xselect_scripts/$(basename $xco).log""

	if [ ! -d "$products_live$ObsID/products/" ]; then
		mkdir -p $products_live$ObsID/products/
	fi

  xselect $xco | tee -a "$log_file"

	echo "${highlight}Finished xselect ${reset}"

	echo "${highlight}Moving products $ObsID to $products ${reset}"

	rsync -a --info=progress2 --remove-source-files $products_live$ObsID/ $products$ObsID/

	if [[ $(dirname $TMP_DIR) -ef /tmp/ ]]; then
			echo removing $TMP_DIR
			rm -r -f $TMP_DIR
	fi
done
