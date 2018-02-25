function XselLC(ObsID, bins)
    if local_archive == "default"
        local_archive, local_archive_clean, local_utility = find_default_path()
    end

    bins = 1

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

    run(`gnome-terminal -e "/home/robert/pipeline_vm.sh $queue"`)
end
