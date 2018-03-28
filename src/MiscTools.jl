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
    numaster_types = [String, Union{Missings.Missing, Float64}, Union{Missings.Missing, Float64}, Union{Missings.Missing, Float64}, Union{Missings.Missing, Float64}, # :name, :ra, :dec, :lii, :bii
    Union{Missings.Missing, Float64}, String, String, String, Float64, # :roll_angle, :time, :end_time, :obsid, :exposure_a
    Float64, Float64, Float64, String, String, # :exposure_b, :ontime_a, :ontime_b, :observation_mode, :instrument_mode
    String, String, String, String, String, # :spacecraft_mode, :slew_mode, :processing_date, :public_date, :software_version
    Int, Union{Missings.Missing, String}, String, Int, String, # :prnb, :abstract, :subject_category, :category_code, :priority
    String, String, Union{Missings.Missing, String}, Union{Missings.Missing, String}, Union{Missings.Missing, String}, # :pi_lname, :pi_fname, :copi_lname, :copi_fname, :country
    Int, String, Union{Missings.Missing, String}, Int, Int, # :cycle, :obs_type, :title, :data_gap, :nupsdout
    Union{Missings.Missing, String}, Union{Missings.Missing, String}, Int, Union{Missings.Missing, String}, String, #:solar_activity, :coordinated, :issue_flag, :comments, :status
    String, Int, Int, Int, Int, # :caldb_version, :Downloaded, :Cleaned, :ValidSci, :RegSrc
    Int, String, String, String]; # :RegBkg, :LC, :Interesting, :EVT

    # This is absurdly stupid looking, but seems to be the best way to get the CSV
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

# Natural sorting algorithm ripped out of https://github.com/simonster/NaturalSort.jl
# Thanks to Simon Kornblith

function natural(x::AbstractString, y::AbstractString)
    statex = start(x)
    statey = start(y)
    donex = false
    doney = false
    while !(donex = done(x, statex)) & !(doney = done(y, statey))
        cx, statex = next(x, statex)
        cy, statey = next(y, statey)
        if isnumber(cx) && isnumber(cy)
            # Skip leading zeros
            while cx == '0' && !(donex = done(x, statex))
                cx, statex = next(x, statex)
            end
            while cy == '0' && !(doney = done(y, statey))
                cy, statey = next(y, statey)
            end

            # Begin comparing numbers
            diff = false
            lt = false
            while true
                isnumx = isnumber(cx)
                isnumy = isnumber(cy)
                if isnumx && isnumy
                    if !diff && cx != cy
                        # Keep track of how numbers differ, in case the lengths match
                        diff = true
                        lt = cx < cy
                    end

                    donex = done(x, statex)
                    doney = done(y, statey)
                    if donex || doney
                        if donex && !doney && isnumber(next(y, statey)[1])
                            # Number in y is longer than number in x
                            return true
                        elseif !donex && doney && isnumber(next(x, statex)[1])
                            # Number in x is longer than number in y
                            return false
                        end
                        # Both numbers ended and same length
                        return diff ? lt : donex && !doney
                    end

                    cx, statex = next(x, statex)
                    cy, statey = next(y, statey)
                elseif isnumx
                    # Number in x is longer than number in y
                    return false
                elseif isnumy
                    # Number in y is longer than number in x
                    return true
                elseif diff
                    # Numbers were same length but different
                    return lt
                else
                    # Numbers were the same
                    break
                end
            end
        end
        if cx != cy
            return cx < cy
        end
    end

    return donex && !doney
end

function interesting(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"])
    path_obs = string(local_archive_pr, obsid)
    path_obs_comment = string(path_obs, "/comments.txt")

    if !isdir(path_obs)
        error("$path_obs not found!")
    end

    print("Enter flag name: ")
    flag_name = readline(STDIN)

    flag_name == "" ? flag_name="No" : ""

    comment = []
    comment = append!(comment, [flag_name])

    if flag_name == "No"
        open(path_obs_comment, "w") do f
            write(f, comment)
        end
        println("Saved to: $path_obs_comment")

        return
    end

    print("Enter other comments (empty line to finish): ")

    while true
        comment_line = readline(STDIN)
        comment_line == "" ? break : append!(comment, [string("\n$comment_line")])
    end

    comment = replace.(comment, ",", ";") # Commas screw with CSV

    open(path_obs_comment, "w") do f
        write(f, comment)
    end

    println("Saved to: $path_obs_comment")
end

function interesting(; local_archive_pr=ENV["NU_ARCHIVE_PR"])
    clipboard_contents = clipboard()

    if length(clipboard_contents) == 11
        print("Obsid ($clipboard_contents): ")
        readline(STDIN) == "" ? obsid = clipboard_contents : obsid = readline(STDIN)
    else
        print("Obsid: ")
        obsid = readline(STDIN)
    end

    interesting(obsid; local_archive_pr=local_archive_pr)
end
