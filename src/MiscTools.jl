function find_default_path()
    if is_windows()
        return "I:/.nustar_archive", "I:/.nustar_archive_cl"
    elseif is_linux()
        return "/mnt/hgfs/.nustar_archive", "/mnt/hgfs/.nustar_archive_cl"
    else
        error("Unknwon path")
    end
end

function pull_file_list(hostname="heasarc.gsfc.nasa.gov"; path="/nustar/.nustar_archive")
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

    ftp_command(connection_context, "CWD $path")

    if ftp_command(connection_context, "PWD").headers[2] != "257 \"$path\" is the current directory"
        error("FTP not in $path")
    else
        info("Connection established, in \"$path\"")
    end

    # Use MLSD FTP command to get standardised directory listing data
    # annoyingly LIST and STAT -L seem to return the modify date in different ways
    # randomly, some folders have "Feb 6 2015", others have "Nov 2 08:45"
    info("Pulling file list via MLSD")
    file_list = ftp_command(connection_context, "MLSD $path")
    file_list = String(take!(file_list.body));
    file_list = split(file_list, "\n");
    file_list = file_list[1:end-1] # Remove final value, empty string from strip

    # STAT -L mean (4): 3.1s
    # MLSD    mean (4): 2.4s
    # LIST    mean (4): 3.2s

    info("Closing FTP connection")
    ftp_close_connection(connection_context)

    ftp_cleanup()

    return file_list
end
