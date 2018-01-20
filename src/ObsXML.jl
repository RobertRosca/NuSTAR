function XML(ObsIDs, XML_out_dir="I:/FileZilla.xml", verbose=false)
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
    else
        info("Connection established, passive mode")
    end

    function get_list_for_folder(ObsID, folder)
        list = ftp_command(connection_context, "NLST /nustar/.nustar_archive/$(ObsID)/$(folder)/")
        list = takebuf_string(list.body)
        #list = string(take!(list.body))
        list = split(list, "\n")[1:end-1]
        list = replace.(list, "\r", "")

        return list
    end

    info("Generating XML for FileZilla3")
    # Create XML Queue file for FileZilla
    # Header
    filezilla_xml = XMLDocument()

    fz_root = create_root(filezilla_xml, "FileZilla3")
    set_attribute(fz_root, "version", "3.29.0")
    set_attribute(fz_root, "platform", "windows")

    fz_queue = new_child(fz_root, "Queue")

    fz_server = new_child(fz_queue, "Server")

    fz_server_Host = new_child(fz_server, "Host")
        add_text(fz_server_Host, "heasarc.gsfc.nasa.gov")

    fz_server_Port = new_child(fz_server, "Port")
        add_text(fz_server_Port, "21")

    fz_server_Protocol = new_child(fz_server, "Protocol")
        add_text(fz_server_Protocol, "0")

    fz_server_Type = new_child(fz_server, "Type")
        add_text(fz_server_Type, "0")

    fz_server_Logontype = new_child(fz_server, "Logontype")
        add_text(fz_server_Logontype, "0")

    fz_server_TimezoneOffset = new_child(fz_server, "TimezoneOffset")
        add_text(fz_server_TimezoneOffset, "0")

    fz_server_PasvMode = new_child(fz_server, "PasvMode")
        add_text(fz_server_PasvMode, "MODE_DEFAULT")

    fz_server_MaximumMultipleConnections = new_child(fz_server, "MaximumMultipleConnections")
        add_text(fz_server_MaximumMultipleConnections, "0")

    fz_server_EncodingType = new_child(fz_server, "EncodingType")
        add_text(fz_server_EncodingType, "Auto")

    fz_server_BypassProxy = new_child(fz_server, "BypassProxy")
        add_text(fz_server_BypassProxy, "0")

    info("Header done")

    local_archive = NuSTAR.find_default_path()
    if !isdir(local_archive)
        error("Local archive not found at \"$(local_archive)\"")
    end

    files_done = 1
    for ObsID in ObsIDs
        list_auxil    = get_list_for_folder(ObsID, "auxil")
        list_hk       = get_list_for_folder(ObsID, "hk")
        list_event_uf = get_list_for_folder(ObsID, "event_uf")

        #list_pipelog = "/nustar/.nustar_archive/$(ObsID)/pipe.log"

        download_list = [list_auxil; list_hk; list_event_uf]
        info("Generating file list for $(ObsID) $(files_done)/$(length(ObsIDs)). Found $(length(download_list)) files")

        for (itr, file) in enumerate(download_list)
            fz_server_file = new_child(fz_server, "File")

            dir_name = dirname(file)
            dir_folder = split(dir_name, "/")[end]
            dir_folder_length = length(dir_folder)
            file_name = basename(file)

            fz_server_file_local = new_child(fz_server_file, "LocalFile")
            add_text(fz_server_file_local, replace(string(local_archive, file[24:end]), "/", "\\"))

            fz_server_file_remote = new_child(fz_server_file, "RemoteFile")
            add_text(fz_server_file_remote, file_name)

            fz_server_remote_path = new_child(fz_server_file, "RemotePath")
            remote_path_string = string("1 0 6 nustar 15 .nustar_archive 11 $(ObsID) $(dir_folder_length) $(dir_folder)")
            add_text(fz_server_remote_path, remote_path_string)

            fz_server_download_flag = new_child(fz_server_file, "Download")
            add_text(fz_server_download_flag, "1")

            fz_server_data_type = new_child(fz_server_file, "DataType")
            add_text(fz_server_data_type, "1")

            if verbose; info("Added $(file)"); end
        end

        files_done += 1
    end

    ftp_close_connection(connection_context)
    ftp_cleanup()

    info("Done, saving to $(XML_out_dir)")

    save_file(filezilla_xml, XML_out_dir)
end

function XMLBatch(local_archive="default", log_file="", batch_size=100)
    if local_archive == "default"
        local_archive = NuSTAR.find_default_path()[1]
        log_file = string(local_archive, "/00000000000 - utility/download_log.csv")
    end

    observations = CSV.read(log_file)

    queue = []

    println("Added to queue:")
    obs_count = size(observations)[1]; bs = 0
    for i = 0:obs_count-1 # -1 for the utility folder
        if Int(observations[obs_count-i, :Downloaded]) == 0 # Index from end, backwards
            append!(queue, [observations[obs_count-i, :ObsID]])
            print(string(observations[obs_count-i, :ObsID], ", "))
            bs += 1
        end

        if bs >= batch_size
            println("\n")
            break
        end
    end

    XML(queue)
end
