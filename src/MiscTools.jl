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

function check_obs_publicity(ObsID, connection_context)
    obs_uf_list = ftp_command(connection_context, "NLST /nustar/.nustar_archive/$ObsID/event_uf")
    obs_uf_list = String(take!(obs_uf_list.body))
    uf_first    = split(obs_uf_list, "\r")[1]
    uf_first    = basename(uf_first)
    uf_first_ext= split(uf_first, ".")

    Public = -1

    if uf_first_ext != "gpg"
        Public = 1
    else
        Public = 0
    end

    return Public
end

function check_obs_publicity_local(local_archive=ENV["NU_ARCHIVE"]; purge=false)
    file_list_local = readdir(local_archive)[2:end]

    Publicity = zeros(Int, length(file_list_local))

    for (itr, local_obs) in enumerate(file_list_local)
        event_path   = string(local_archive, "/$local_obs/event_uf/")
        uf_first     = readdir(event_path)[1]
        uf_first     = basename(uf_first)
        uf_first_ext = split(uf_first, ".")[end]

        if uf_first_ext == "gpg"
            Publicity[itr] = 0
            if purge
                mv(string(local_archive, "/$local_obs"), string("I:/.nustar_archive_private", "/$local_obs/"))
            end
        elseif uf_first_ext == "gz"
            Publicity[itr] = 1
        else
            Publicity[itr] = -1
        end
    end

    println("Public: $(count(x -> x == 1, Publicity[:])) / $(length(Publicity))")

    return Publicity
end

function read_numaster(numaster_path)
    #name, ra, dec, lii, bii, roll_angle, time, end_time, obsid, exposure_a, exposure_b
    #ontime_a, ontime_b, observation_mode, instrument_mode, spacecraft_mode, slew_mode
    #processing_date, public_date, software_version, prnb, abstract, subject_category
    #category_code, priority, pi_lname, pi_fname, copi_lname, copi_fname, country, cycle
    #obs_type, title, data_gap, nupsdout, solar_activity, coordinated, issue_flag, comments
    #status, caldb_version, Downloaded, Cleaned, ValidSci, RegSrc, RegBkg

    numaster_types = [String, Union{Missings.Missing, Float64}, Union{Missings.Missing, Float64}, Union{Missings.Missing, Float64}, Union{Missings.Missing, Float64},
    Union{Missings.Missing, Float64}, String, String, String, Float64,
    Float64, Float64, Float64, String, String,
    String, String, String, String, String,
    Int, Union{Missings.Missing, String}, String, Int, String,
    String, String, Union{Missings.Missing, String}, Union{Missings.Missing, String}, Union{Missings.Missing, String},
    Int, String, Union{Missings.Missing, String}, Int, Int,
    Union{Missings.Missing, String}, Union{Missings.Missing, String}, Int, Union{Missings.Missing, String}, String,
    String, Int, Int, Int, Int,
    Int, String];

    # This is absurdly stupid looking, but seems to be the only way to get the CSV
    # to be read properly

    CSV.read(numaster_path, types=numaster_types)
end

function load_numaster(local_utility=ENV["NU_ARCHIVE_UTIL"])
    numaster_path = string(local_utility, "/numaster_df.csv")

    return read_numaster(numaster_path)
end

function sgolay(order, frameLen)
    S = (-(frameLen-1)/2:((frameLen-1)/2)) .^ (0:order)'
    (Q, R) = qr(S)
    B = Q*Q'
    G = Q / R'

    return B, G
end

function sgolayfilt(x, order, frameLen)
    B = sgolay(order, frameLen)[1]
    x = x[:]

    @assert ndims(x) == 1

    ybegin = B[end:-1:round(Int, (frameLen-1)/2 + 2), :] * x[frameLen:-1:1, :]
    ycentre = filt(B[round(Int, (frameLen-1)./2 + 1), :], 1, x)
    yend = B[round(Int, (frameLen-1)/2):-1:1, :] * x[end:-1:end-(frameLen-1), :]

    return y = [ybegin; ycentre[frameLen:end, :]; yend]
end

function unzip!(path)
    dir  = dirname(path)

    if Sys.is_windows()
        zip7 = string(Sys.BINDIR, "\\7z.exe")
        run(`$zip7 e $path -o$dir`)
    elseif Sys.is_linux()
        try
            run(`7z e $path -o$dir`) # Assumes `p7zip-full` is installed
        catch error
            warning("Is p7zip-full installed?")
            error(error)
        end
    end

    filename = split(basename(path), ".")[1]

    if isfile(path)
        rm(path)
        mv(string(dir, "/", filename), path)
    end
end
