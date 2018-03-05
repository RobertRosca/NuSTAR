# NuSTAR

## Notes

Known good observation to use for tests: 80002017002

## Workflow

### Numaster(;local_archive="", local_archive_cl="", local_utility="")

NuSTAR.Numaster() to download the newest data base from the numaster url:
`https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz`

Uses directories set in `MiscTools/find_default_path()`

Adds extra columns to the numaster file, all custom columns start with capital
letters, default columns are all lower case. Adds columns for: `Downloaded`,
`Cleaned`, `ValidSci`, `RegSrc`, `RegBkg`

Converts time from Julian to normal readable

Saves CSV file

### Summary(;numaster_path="")

Prints some statistics on what is currently in the `numaster` table

### XMLBatch(;local_archive="default", log_file="", batch_size=100)

Downloading files directly via FTP is a bit slow, can be sped up with simultaneous
downloads, easier to use existing programs to handle that. As such, `XMLBatch()`
takes in the archive paths and a `batch_size` to denote how many new observaions
to queue for download.

It then creates an XML file with can be read into FileZilla's queue to allow for
simultaneous downloading. It does this by calling the `XML(ObsIDs; XML_out_dir="", verbose=false, local_archive="")` function with a queue of multiple `ObsIDs`.

### CalBatch(local_archive="default"; log_file="", batches=4, to_cal=16)

`batches` denotes the number of nupipeline processes to have running simultaneously,
should be equal to or less than the number of CPU cores available.

`to_cal` denotes the **total** number of observations to be calibrated. These are
then split equally (ish) over the number of processes set in `batches`.

Function calls `Calibrate(ObsIDs::Union{Array{String,1}, String})`

### Calibrate(ObsIDs::Union{Array{String,1}, String})

Takes in either a single `ObsID` as a string or an array of strings, calls
the included `run_nupipeline.sh` bash script which then handles the file
transfer to the `/Scratch` folder and the subsequent calibration/file management

### run_nupipeline.sh

Runs nupipeline and sets up temporary directories, scratch folders, notifications
and file movement between scratch and archive directories

Pulls the directory locations from environmental variables set in `.bashrc` or
somewhere else, looks for:'$NU_ARCHIVE', '$NU_ARCHIVE_LIVE', '$NU_ARCHIVE_CL',
and '$NU_ARCHIVE_CL_LIVE'
