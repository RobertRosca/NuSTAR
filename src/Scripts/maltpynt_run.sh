#!/bin/bash

nu_archive_cl="/home/robert/Scratch/.nustar_archive_cl/"
obsid="90302319006"
path_pipeline="$nu_archive_cl$obsid/pipeline_out/"
path_mp="${path_pipeline}MP/"

path_a="${path_pipeline}nu${obsid}A01_cl.evt"
path_b="${path_pipeline}nu${obsid}B01_cl.evt"

MPreadevents $path_a $path_b

path_a_ev="${path_mp}nu${obsid}A01_ev.p"
path_b_ev="${path_mp}nu${obsid}B01_ev.p"

mkdir $path_mp

mv "${path_pipeline}nu${obsid}A01_cl_ev.p" $path_a_ev
mv "${path_pipeline}nu${obsid}B01_cl_ev.p" $path_b_ev

MPcalibrate $path_a_ev $path_b_ev

path_a_calib="${path_mp}nu${obsid}A01_ev_calib.p"
path_b_calib="${path_mp}nu${obsid}B01_ev_calib.p"

MPlcurve $path_a_calib $path_b_calib -b 0.002 -e 3 30 --safe-interval 100 300

path_a_lc="${path_mp}nu${obsid}A01_E3-30_lc.p"
path_b_lc="${path_mp}nu${obsid}B01_E3-30_lc.p"

MPfspec $path_a_lc $path_b_lc -k CPDS -o rms --norm rms

path_rms_cpds="${path_mp}rms_cpds.p"

MP2xspec $path_rms_cpds