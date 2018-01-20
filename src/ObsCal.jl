function Calibrate(ObsIDs)
    for ObsID in ObsIDs
        run(`gnome-terminal -e "/home/robert/pipeline_vm.sh $ObsID"`)
    end

    info("Calibration started for $ObsIDs")
end

function CalBatch(local_archive="default", log_file="", batch_size=4)
    if local_archive == "default"
        local_archive = NuSTAR.find_default_path()[1]
        log_file = string(local_archive, "/00000000000 - utility/download_log.csv")
    end

    if !is_linux()
        error("Tool only works on Linux with heainit and caldb setup")
    end

    observations = CSV.read(log_file)

    println("Added to queue:")
    obs_count = size(observations)[1]; bs = 0
    for i = 0:obs_count-1 # -1 for the utility folder
        if Int(observations[obs_count-i, :Cleaned]) == 0 # Index from end, backwards
            append!(queue, [observations[obs_count-i, :ObsID]])
            print(string(observations[obs_count-i, :ObsID], ", "))
            bs += 1
        end

        if bs >= batch_size
            println("\n")
            break
        end
    end

    Calibrate(queue)
end
