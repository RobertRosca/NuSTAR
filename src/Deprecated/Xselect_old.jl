
function XselEVT(todo;
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

    queue_inst = Dict()

    queue_inst["A"] = @from i in numaster_df begin
        @where i.RegSrc==1 && i.EVT!="A" && i.EVT!="AB"
        @select i.obsid
        @collect
    end

    queue_inst["B"] = @from i in numaster_df begin
        @where i.RegSrc==1 && i.EVT!="B" && i.EVT!="AB"
        @select i.obsid
        @collect
    end

    todo_count = 0

    queue_paths = []

    for instrument in ["A", "B"]
        queue = queue_inst[instrument]
        for (i, obsid) in enumerate(queue)
            xsel_out = string(local_archive_pr, obsid, "/products/event/evt_$instrument.fits")
            xsel_file_path  = string(local_archive_pr, obsid, "/xselect_scripts/evt_$instrument", ".xco")

            if !isfile(xsel_out) # If the .fits file doesn't exist
                if !isfile(xsel_file_path) # If the .xco file, which creates the fits, doesn't exist
                    info("Generating xco for $obsid - $instrument")
                    create_xco_evt(obsid, instrument; ObsPath=string(local_archive_cl, obsid),
                        xsel_out=xsel_out, xsel_file_path=xsel_file_path, src_file="/source.reg")
                end

                todo_count += 1
                append!(queue_paths, [xsel_file_path])

                if todo_count >= todo
                    break
                end
            end
        end

        if todo_count >= todo-1
            break
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
