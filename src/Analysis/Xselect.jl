function XselLC(ObsID, bins; local_archive="default", local_archive_clean="")
    if local_archive == "default"
        local_archive = ENV["NU_ARCHIVE_LIVE"]
        local_archive_clean = ENV["NU_ARCHIVE_CL_LIVE"]
    end

    xsel_name = split(tempname(), "/")[3]

    ObsPath = string(local_archive_clean, ObsID)
    xsel_pip = string(ObsPath, "/pipeline_out/")
    xsel_src = string(ObsPath, "/source.reg")
    xsel_bin = bins
    xsel_out = string(ObsPath, "/products/lc_$xsel_bin.fits")

    xsel_file_path = string(ObsPath, "/xselect_scripts/lc_$xsel_bin", ".xco")

    xsel_file_session = "$xsel_name"
    xsel_file_read = "read event\n$xsel_pip\n$(string("nu", ObsID, "A01_cl.evt"))"
    xsel_file_filter = "filter region $xsel_src"
    xsel_file_extract = "extract CURVE bins=$xsel_bin"
    xsel_file_save = "save curve $xsel_out clobber=yes"
    xsel_file_exit = "exit"
    xsel_file_exit_no = "no"

    xsel_file = [xsel_file_session, xsel_file_read, xsel_file_filter,
        xsel_file_extract, xsel_file_save, xsel_file_exit, xsel_file_exit_no]

    if !isdir(dirname(xsel_file_path))
        mkdir(dirname(xsel_file_path))
    end

    if !isdir(dirname(xsel_out))
        mkdir(dirname(xsel_out))
    end

    open(xsel_file_path, "w") do f
        for line in xsel_file
            write(f, "$line \n")
        end
    end

    run_xselect = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_xselect.sh")

    run(`gnome-terminal -e "$run_xselect @$xsel_file_path"`)
end
