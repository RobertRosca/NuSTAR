#!/bin/bash

echo "${highlight}Running init ${reset}"
source $HEADAS/headas-init.sh
source $CALDB/software/tools/caldbinit.sh

for fits in "$@"
do
fdump infile=$fits.fits+1 outfile=$fits.csv columns="TIME, RATE, ERROR" rows=- prhead=no fldsep="," clobber=yes showrow=no
done
