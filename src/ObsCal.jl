function Calibrate(ObsIDs)
    queue = replace(string(ObsIDs)[5:end-1], ", ", " ")

    run(`gnome-terminal -e "/home/robert/pipeline_vm.sh $queue"`)

    info("Calibration started for $queue")
end

function CalBatch(local_archive="default"; log_file="", batches=4, to_cal=16)
    if local_archive == "default"
        local_archive, local_archive_clean, local_utility = find_default_path()
        numaster_path = string(local_utility, "/numaster_df.csv")
    end

    if !is_linux()
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
            Calibrate(queue[l:u])
        else
            println(queue[l:u])
        end
    end
end
