function LogGenerate(local_archive="default", local_archive_clean="")
    if local_archive == "default"
        local_archive, local_archive_clean = find_default_path()
    end

    file_list = pull_file_list("heasarc.gsfc.nasa.gov"; path="/nustar/.nustar_archive")

    # Third value is the first 'real' folder, after . and ..
    # trailing newline creates empty final value
    file_list = file_list[3:end]

    info("Found $(size(file_list, 1)) observations")

    # Dates are contained in [8:21], ObsID from [end-11:end-1]
    info("Making readable")
    ObsIDs   = Array{String}(length(file_list))
    ObsDates = Array{String}(length(file_list))
    for (itr, obs) in enumerate(file_list)
        ObsIDs[itr]   = string(obs[end-11:end-1])
        # Formats raw datettime, 20180102050930 to 2018-01-02T05:09:30
        ObsDates[itr] = string(DateTime(obs[8:21], "yyyymmddHHMMSS"))
    end

    observations = DataFrame(ObsID=ObsIDs, Date=ObsDates)

    Public = -1 .* ones(Int, length(file_list)) # -1 means no data yet
    observations[:Public] = Public

    if !isdir(local_archive)
        error("Local archive not found at \"$(local_archive)\"")
    end

    # First folder is utility, skip
    info("Comparing to local files")
    file_list_local = readdir(local_archive)[2:end]

    ObsDownl = zeros(Int, length(file_list))
    for (itr, obs) in enumerate(file_list)
        if observations[:ObsID][itr] in file_list_local
            ObsDownl[itr] = 1
        else
            ObsDownl[itr] = 0
        end
    end

    observations[:Downloaded] = ObsDownl

    info("Finding calibrated files")
    file_list_local = readdir(local_archive_clean)

    ObsClean = zeros(Int, length(file_list))
    for (itr, obs) in enumerate(file_list)
        if observations[:ObsID][itr] in file_list_local
            ObsClean[itr] = 1
        else
            ObsClean[itr] = 0
        end
    end

    observations[:Cleaned] = ObsClean

    # Finally, sort by date:
    sort!(observations, cols=(:Date))

    info("Creating CSV")
    log_file = string(local_archive, "/00000000000 - utility/download_log.csv")

    try
        observations_old = CSV.read(log_file)
        downloaded_old   = Int(sum(observations_old[:Downloaded]))

        info("Found $(size(observations, 1) - size(observations_old, 1)) new observations")
        info("Found $(Int(downloaded_old - sum(ObsDownl))) new downloaded observations")
    end

    try
        if isfile(log_file)
            warn("Log file already exists, replacing")
            mv(log_file, string(local_archive, "/00000000000 - utility/download_log.csv.old"), remove_destination=true)
        end

        CSV.write(log_file, observations)
    catch ex
        warn("Could not write to file, is file open?")
        log_file_temp = string(log_file[1:end-4], "_", tempname()[end-7:end-4], ".csv")
        info("Saving as temp file - $(log_file_temp)")

        CSV.write(log_file_temp, observations)
        rethrow(ex)
    end

    println("Done")
end

function LogUpdate(local_archive="default", local_archive_clean="")
    if local_archive == "default"
        local_archive, local_archive_clean = find_default_path()
        log_file = string(local_archive, "/00000000000 - utility/download_log.csv")
    end

    file_list = pull_file_list("heasarc.gsfc.nasa.gov"; path="/nustar/.nustar_archive")

    # Third value is the first 'real' folder, after . and ..
    # trailing newline creates empty final value
    file_list = file_list[3:end]

    info("Found $(size(file_list, 1)) NuSTAR observations")

    observations_local = CSV.read(log_file, types=[String, String, Int, Int, Int])

    info("Found $(size(observations_local, 1)) local observations logged")

    # Dates are contained in [8:21], ObsID from [end-11:end-1]
    info("Making readable")
    ObsIDs   = Array{String}(length(file_list))
    ObsDates = Array{String}(length(file_list))
    for (itr, obs) in enumerate(file_list)
        ObsIDs[itr]   = obs[end-11:end-1]
        # Formats raw datettime, 20180102050930 to 2018-01-02T05:09:30
        ObsDates[itr] = string(DateTime(obs[8:21], "yyyymmddHHMMSS"))
    end

    observations = DataFrame(ObsID=ObsIDs, Date=ObsDates)

    new_obsid = setdiff(observations[:ObsID], observations_local[:ObsID])

    info("Found $(length(new_obsid)) new observations")

    observations_new = DataFrame(ObsID=String[], Date=String[])
    for obs in new_obsid
        append!(observations_new, observations[observations[:ObsID] .== obs, :])
    end

    Public = -1 .* ones(Int, length(new_obsid)) # -1 means no data yet
    observations_new[:Public] = Public

    # First folder is utility, skip
    info("Comparing to local files")
    file_list_local = readdir(local_archive)[2:end]

    ObsDownl = zeros(Int, length(new_obsid))
    for (itr, obs) in enumerate(new_obsid)
        if observations_new[:ObsID][itr] in file_list_local
            ObsDownl[itr] = 1
        else
            ObsDownl[itr] = 0
        end
    end
    observations_new[:Downloaded] = ObsDownl

    info("Finding calibrated files")
    file_list_local = readdir(local_archive_clean)

    ObsClean = zeros(Int, length(new_obsid))
    for (itr, obs) in enumerate(new_obsid)
        if observations_new[:ObsID][itr] in file_list_local
            ObsClean[itr] = 1
        else
            ObsClean[itr] = 0
        end
    end

    observations_new[:Cleaned] = ObsClean

    observations_updated = [observations_local; observations_new]

    sort!(observations_updated, cols=(:Date))

    info("Creating CSV")
    log_file = string(local_archive, "/00000000000 - utility/download_log.csv")

    try
        observations_old = CSV.read(log_file)
        downloaded_old   = Int(sum(observations_old[:Downloaded]))

        info("Found $(size(observations, 1) - size(observations_old, 1)) new observation(s)")
        info("Found $(Int(downloaded_old - sum(observations_updated[:Downloaded]))) new downloaded observation(s)")
    end

    try
        if isfile(log_file)
            warn("Log file already exists, replacing")
            mv(log_file, string(local_archive, "/00000000000 - utility/download_log.csv.old"), remove_destination=true)
        end

        CSV.write(log_file, observations_updated)
    catch ex
        warn("Could not write to file, is file open?")
        log_file_temp = string(log_file[1:end-4], "_", tempname()[end-7:end-4], ".csv")
        info("Saving as temp file - $(log_file_temp)")

        CSV.write(log_file_temp, observations_updated)
        rethrow(ex)
    end

    println("Done")
end
