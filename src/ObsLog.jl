function Log(local_archive="I:/.nustar_archive", local_archive_clean="I:/.nustar_archive_cl")
    ftp_init()

    options = RequestOptions(hostname="heasarc.gsfc.nasa.gov")

    connection = ftp_connect(options)
    connection_context = connection[1]

    # 0x00000000000000e2 == FTP code 226, Requested file action successful
    if connection[2].code != 0x00000000000000e2
        error("Connection failed")
        println(connection)
    end

    # 229, Entering Extended Passive Mode
    if connection[2].headers[5][1:3] != "229"
        error("Connection not in passive mode")
        println(connection)
    end

    ftp_command(connection_context, "CWD nustar/.nustar_archive")

    if ftp_command(connection_context, "PWD").headers[2] != "257 \"/nustar/.nustar_archive\" is the current directory"
        error("FTP not in nustar directory")
    else
        info("Connection established, in \"/nustar/.nustar_archive\"")
    end

    # Use MLSD FTP command to get standardised directory listing data
    # annoyingly LIST and STAT -L seem to return the modify date in different ways
    # randomly, some folders have "Feb 6 2015", others have "Nov 2 08:45"
    info("Pulling file list via MLSD")
    file_list = ftp_command(connection_context, "MLSD /nustar/.nustar_archive")
    file_list = String(take!(file_list.body))
    file_list = split(file_list, "\n")

    # Third value is the first 'real' folder, after . and ..
    # trailing newline creates empty final value
    file_list = file_list[3:end-1]

    info("Found $(size(file_list, 1)) observations")

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

    if !isdir(local_archive)
        error("Local archive not found at \"$(local_archive)\"")
    end

    # First folder is utility, skip
    info("Comparing to local files")
    file_list_local = readdir(local_archive)[2:end]

    ObsDownl = zeros(length(file_list))
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

    ObsClean = zeros(length(file_list))
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

    info("Closing FTP connection")
    ftp_close_connection(connection_context)

    ftp_cleanup()

    info("Creating CSV")
    log_file = string(local_archive, "/00000000000 - utility/download_log.csv")

    observations_old = CSV.read(log_file)
    downloaded_old   = Int(sum(observations_old[:Downloaded]))

    info("Found $(size(observations, 1) - size(observations_old, 1)) new observations")
    info("Found $(Int(downloaded_old - sum(ObsDownl))) new downloaded observations")

    try
        if isfile(log_file)
            warn("Log file already exists, replacing")
            mv(log_file, string(local_archive, "/00000000000 - utility/download_log.csv.old"), remove_destination=true)
        end

        CSV.write(log_file, observations)
    catch ex
        warn("Could not write to file, is file open?")
        log_file_temp = string(log_file[1:end-4], tempname()[end-7:end-4], ".csv")
        info("Saving as temp file - $(log_file_temp)")

        CSV.write(log_file_temp, observations)
        rethrow(ex)
    end

    println("Done")
end
