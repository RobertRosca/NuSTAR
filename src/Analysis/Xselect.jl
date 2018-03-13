function create_xco_lc(ObsID, bins;
        local_archive_cl=ENV["NU_ARCHIVE_CL"], local_archive_pr=ENV["NU_ARCHIVE_PR"], src_file="/source.reg")

    xsel_name = split(tempname(), "/")[3]

    ObsPath = string(local_archive_cl, ObsID)
    xsel_pip = string(ObsPath, "/pipeline_out/")
    xsel_src = string(ObsPath, src_file)
    xsel_bin = bins
    xsel_out = string(local_archive_pr, ObsID, "/products/lc_$xsel_bin.fits")

    xsel_file_path = string(local_archive_pr, ObsID, "/xselect_scripts/lc_$xsel_bin", ".xco")

    xsel_file_session = "$xsel_name"
    xsel_file_read = "read event\n$xsel_pip\n$(string("nu", ObsID, "A01_cl.evt"))"
    xsel_file_filter = "filter region $xsel_src"
    xsel_file_extract = "extract CURVE bins=$xsel_bin"
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
        @where i.RegSrc == 1
        @select i.obsid
        @collect
    end

    queue_paths = []

    for (i, obsid) in enumerate(queue)
        fits_file_path = string(local_archive_pr, obsid, "/products/lc_$bins", ".fits")
        xco_file_path  = string(local_archive_pr, obsid, "/xselect_scripts/lc_$bins", ".xco")

        if !isfile(fits_file_path)
            if !isfile(xco_file_path)
                info("Generating xco for $obsid with bins of $bins [s]")
                xco_file_path = create_xco_lc(obsid, bins;
                    local_archive_cl=local_archive_cl, local_archive_pr=local_archive_pr,
                    src_file=src_file)
            end

            append!(queue_paths, [xco_file_path])
        end
    end

    if size(queue_paths, 1) > todo
        queue_paths = queue_paths[1:todo]
    end

    queue_string = join(queue_paths, " ")

    println(size(queue_paths, 1))

    if length(queue_string) == 0
        warn("No files in queue")

        return
    end

    if dry
        println("gnome-terminal -e \"$run_xselect_command --clean=\"$local_archive_cl/\" --products=\"$local_archive_pr/\" --xselect_scripts=\"$queue_string\"\"")
    else
        run(`gnome-terminal -e "$run_xselect_command --clean="$local_archive_cl/" --products="$local_archive_pr/" --xselect_scripts=\"$queue_string\""`)
    end
end
