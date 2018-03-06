"""
    Calibrate(ObsIDs)

Calls `pipeline_vm.sh` with multiple ObsIDs in a new `gnome-terminal`
"""
function Calibrate(ObsIDs::Union{Array{String,1}, String}; dry=false)
    if typeof(ObsIDs) == Array{String,1}
        queue = replace(string(ObsIDs)[8:end-1], ", ", " ")
        queue_native = join(ObsIDs, " ")
    elseif typeof(ObsIDs) == String
        queue = ObsIDs
    end

    if dry
        info("NU_SCRATCH_FLAG: $(ENV["NU_SCRATCH_FLAG"])")
        
        if ENV["NU_SCRATCH_FLAG"] == "true"
            run_nupipeline = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_nupipeline.sh")
            println("gnome-terminal -e \"$run_nupipeline $queue\"")
        elseif ENV["NU_SCRATCH_FLAG"] == "false"
            run_native_nupipeline = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_native_nupipeline.sh")
            println("gnome-terminal -e \"$run_native_nupipeline --archive=\"$(ENV["NU_ARCHIVE"])/\" --clean=\"$(ENV["NU_ARCHIVE_CL"])/\" --obsids=\"$queue_native\"\"")
        end

        return
    end

    if ENV["NU_SCRATCH_FLAG"] == "true"
        run_nupipeline = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_nupipeline.sh")
        run(`gnome-terminal -e "$run_nupipeline $queue"`)
    elseif ENV["NU_SCRATCH_FLAG"] == "false"
        run_native_nupipeline = string(Pkg.dir(), "/NuSTAR/src/Scripts/run_native_nupipeline.sh")
        run(`gnome-terminal -e "$run_native_nupipeline --archive="$(ENV["NU_ARCHIVE"])/" --clean="$(ENV["NU_ARCHIVE_CL"])/" --obsids="$queue_native""`)
    end

    info("Calibration started for $queue")
end

"""
    CalBatch(local_archive="default"; log_file="", batches=4, to_cal=16)

Generates queue of uncalibrated files, splits the queue unto equal (ish) batches
and calls `Calibrate(ObsIDs)` for each batch
"""
function CalBatch(;local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"],
                   local_utility=ENV["NU_ARCHIVE_UTIL"], log_file="", batches=4, to_cal=16, dry=false)

    numaster_path = string(local_utility, "/numaster_df.csv")

    if !Sys.is_linux()
        warn("Tool only works on Linux with heainit and caldb setup")
    end

    numaster_df = read_numaster(numaster_path)

    queue = []

    queue = @from i in numaster_df begin
        @where i.Downloaded==1 && i.Cleaned==0
        @select i.obsid
        @collect
    end

    queue = queue[end:-1:1]
    queue = queue[1:to_cal]

    info("Added to queue: $(join(queue, ", "))")

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
            Calibrate(string.(queue[l:u]), dry=dry)
        else
            println(string.(queue[l:u]))
        end
    end
end
