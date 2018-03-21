function create_xco_lc(obsid, bins; ObsPath="", xsel_out="", xsel_file_path="", src_file="/source.reg",
        local_archive_cl=ENV["NU_ARCHIVE_CL"], local_archive_pr=ENV["NU_ARCHIVE_PR"])

    xsel_name = split(tempname(), "/")[3]

    if ObsPath==""; ObsPath = string(local_archive_cl, obsid); end

    if xsel_out==""; xsel_out = string(local_archive_pr, obsid, "/products/lc/lc_$bins.fits"); end

    if xsel_file_path==""; xsel_file_path = string(local_archive_pr, obsid, "/xselect_scripts/lc_$bins", ".xco"); end

    xsel_pip = string(ObsPath, "/pipeline_out/")
    xsel_src = string(ObsPath, src_file)
    xsel_bin = bins

    xsel_file_session = "$xsel_name"
    xsel_file_read = "read event\n$xsel_pip\n$(string("nu", obsid, "A01_cl.evt")) $(string("nu", obsid, "B01_cl.evt"))"
    xsel_file_filter = "filter region $xsel_src"
    xsel_file_extract = "extract CURVE binsize=$xsel_bin"
    xsel_file_save = "save curve $xsel_out clobber=yes"
    xsel_file_exit = "exit"
    xsel_file_exit_no = "no"

    xsel_file = [xsel_file_session, xsel_file_read, xsel_file_filter,
        xsel_file_extract, xsel_file_save, xsel_file_exit, xsel_file_exit_no]

    if !isfile(xsel_src)
        error("Source file $xsel_src not found")
    end

    if !isdir(dirname(xsel_file_path))
        mkpath(dirname(xsel_file_path))
    end

    if !isdir(dirname(xsel_out))
        mkpath(dirname(xsel_out))
    end

    open(xsel_file_path, "w") do f
        for line in xsel_file
            write(f, "$line \n")
        end
    end

    return xsel_file_path
end

function XselLC(todo, bins;
        local_archive_cl=ENV["NU_ARCHIVE_CL"], local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], scratch=ENV["NU_SCRATCH_FLAG"],
        src_file="/source.reg", dry=false)

    numaster_path = string(local_utility, "/numaster_df.csv")

    numaster_df = read_numaster(numaster_path)

    xsel_file_path = []

    if scratch == "true"
        local_archive_cl=ENV["NU_ARCHIVE_CL_LIVE"]
        local_archive_pr=ENV["NU_ARCHIVE_PR_LIVE"]

        run_xselect_command =  string(Pkg.dir(), "/NuSTAR/src/Scripts/run_xselect.sh")
    else
        run_xselect_command = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_native_xselect.sh")
    end

    queue = @from i in numaster_df begin
        @where i.RegSrc == 1 && i.LC == "NA"
        @select i.obsid
        @collect
    end

    if size(queue, 1) > todo
        queue = queue[1:todo]
    end

    queue_paths = []

    for (i, obsid) in enumerate(queue)
        xsel_out = string(local_archive_pr, obsid, "/products/lc/lc_$bins.fits")
        xsel_file_path  = string(local_archive_pr, obsid, "/xselect_scripts/lc_$bins", ".xco")

        if !isfile(xsel_out) # If the .fits file doesn't exist
            if !isfile(xsel_file_path) # If the .xco file, which creates the fits, doesn't exist
                info("Generating xco for $obsid with bins of $bins [s]")
                create_xco_lc(obsid, bins; ObsPath=string(local_archive_cl, obsid),
                    xsel_out=xsel_out, xsel_file_path=xsel_file_path, src_file="/source.reg")
            end

            append!(queue_paths, [xsel_file_path])
        end
    end

    queue_string = join(queue_paths, " ")

    if length(queue_string) == 0
        warn("No files in queue")
        return
    end

    if dry
        println("gnome-terminal -e \"$run_xselect_command --clean=\"$local_archive_cl/\" --products=\"$local_archive_pr/\" --xselect_scripts=\"$queue_string\"\"")
    else
        info("Running for:$(size(queue_paths, 1))")
        info("On: $queue_string")
        run(`gnome-terminal -e "$run_xselect_command --clean="$local_archive_cl/" --products="$local_archive_pr/" --xselect_scripts=\"$queue_string\""`)
    end
end
