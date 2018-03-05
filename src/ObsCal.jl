"""
    Calibrate(ObsIDs)

Calls `pipeline_vm.sh` with multiple ObsIDs in a new `gnome-terminal`
"""
function Calibrate(ObsIDs::Union{Array{String,1}, String}; dry=false)
    if typeof(ObsIDs) == Array{String,1}
        queue = replace(string(ObsIDs)[8:end-1], ", ", " ")
    elseif typeof(ObsIDs) == String
        queue = ObsIDs
    end

    if dry
        run_nupipeline = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_nupipeline.sh")
        run_native_nupipeline = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_native_nupipeline.sh")

        info("NU_SCRATCH_FLAG: $(ENV["NU_SCRATCH_FLAG"])")

        println("gnome-terminal -e \"$run_nupipeline $queue\"")
        println("\n")
        println("gnome-terminal -e \"$run_native_nupipeline --archive=\"$(ENV[\"NU_ARCHIVE\"])\" --clean=\"$(ENV[\"NU_ARCHIVE_CL\"])\" --obsids=\"$queue\"\"")

        return
    end

    if ENV["NU_SCRATCH_FLAG"] == "true"
        run_nupipeline = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_nupipeline.sh")
        run(`gnome-terminal -e "$run_nupipeline $queue"`)
    elseif ENV["NU_SCRATCH_FLAG"] == "false"
        run_native_nupipeline = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_native_nupipeline.sh")
        run(`gnome-terminal -e "$run_native_nupipeline --archive="$(ENV["NU_ARCHIVE"])" --clean="$(ENV["NU_ARCHIVE_CL"])" --obsids="$queue""`)
    end

    info("Calibration started for $queue")
end

"""
    CalBatch(local_archive="default"; log_file="", batches=4, to_cal=16)

Generates queue of uncalibrated files, splits the queue unto equal (ish) batches
and calls `Calibrate(ObsIDs)` for each batch
"""
function CalBatch(local_archive="default"; log_file="", batches=4, to_cal=16)
    if local_archive == ""
        dirs = find_default_path()
        local_archive = dirs["dir_archive"]
        local_archive_cl = dirs["dir_archive_cl"]
        local_utility = dirs["dir_utility"]
        numaster_path = string(local_utility, "/numaster_df.csv")
    end

    if !Sys.is_linux()
        warn("Tool only works on Linux with heainit and caldb setup")
    end

    numaster_df = read_numaster(numaster_path)

    queue = []

    println("Added to queue:")
    obs_count = size(numaster_df)[1]; bs = 0
    for i = 0:obs_count-1 # -1 for the utility folder
        if Int(numaster_df[obs_count-i, :Downloaded]) == 1
            if Int(numaster_df[obs_count-i, :Cleaned]) == 0 # Index from end, backwards
                append!(queue, [numaster_df[obs_count-i, :obsid]])
                print(string(numaster_df[obs_count-i, :obsid], ", "))
                bs += 1
            end
        end

        if bs >= to_cal
            println("\n")
            break
        end
    end

    # To split the observations evenly between each process:

    batch_remainder = to_cal % batches
    no_rem_cal = to_cal - batch_remainder
    no_rem_batch = Int(no_rem_cal / batches)

    batch_sizes = []

    for batch in 1:batches
        append!(batch_sizes, no_rem_batch)
    end

    for remainder in 1:batch_remainder # Add remainder by one to each batch
        batch_sizes[remainder] += 1
    end

    for i = 1:batches
        l = sum(batch_sizes[1:i]) - (batch_sizes[i] - 1)
        u = sum(batch_sizes[1:i])

        if is_linux()
            Calibrate(string.(queue[l:u]))
        else
            println(string.(queue[l:u]))
        end
    end
end
