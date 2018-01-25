function Numaster(;local_archive="default", local_archive_clean="")
    if local_archive == "default"
        local_archive, local_archive_clean = find_default_path()
    end

    numaster_url  = "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz"
    numaster_path_live = string(local_archive, "/00000000000 - utility/numaster_live.txt")

    info("Downloading latest NuSTAR master catalog")
    Base.download(numaster_url, numaster_path_live)

    numaster_ascii = readdlm(numaster_path_live, '\n')

    # Find start and end points of data, +/-1 to skip the tags themselves
    data_start = Int(find(numaster_ascii .== "<DATA>")[1] + 1)
    data_end   = Int(find(numaster_ascii .== "<END>")[1] - 1)
    keys_line  = data_start - 2

    # Key names are given on the keys_line, split and make into symbols for use later
    key_names = Symbol.(split(numaster_ascii[keys_line][11:end])) # 11:end to remove 'line[1] = '
    # name ra dec lii bii roll_angle time end_time obsid exposure_a exposure_b ontime_a ontime_b observation_mode instrument_mode spacecraft_mode slew_mode processing_date public_date software_version prnb abstract subject_category category_code priority pi_lname pi_fname copi_lname copi_fname country cycle obs_type title data_gap nupsdout solar_activity coordinated issue_flag comments status caldb_version

    numaster_ascii_data = numaster_ascii[data_start:data_end]

    numaster_df = DataFrame(numaster_ascii[6:46], key_names)

    deleterows!(numaster_df, 1) # Remove row, only made to get column names

    for (row_i, row) in enumerate(numaster_ascii_data)
        obs_values = split(row, "|")[1:end-1] # Split row by | delims

        if length(obs_values) != 41 # Some rows don't have the proper no. of columns, skip them
            warn("Skipped row $row_i due to malformed columns, ObsID: $(obs_values[9])")
            continue
        end

        if obs_values[40] == "archived" # If the observation is not in the archive, skip it
            df_tmp = DataFrame()

            for (itr, key) in enumerate(key_names) # Create DataFrame of key and val for row
                df_tmp[key] = replace(obs_values[itr], ",", "; ") # Remove commas, screw with CSV
            end

            numaster_df = [numaster_df; df_tmp] # Concat
        end
    end

    sort!(numaster_df, cols=(:public_date))

    file_list_local       = readdir(local_archive)[2:end]
    file_list_local_clean = readdir(local_archive_clean)[2:end]

    downloaded = zeros(Int, size(numaster_df, 1))
    cleaned    = zeros(Int, size(numaster_df, 1))

    for (itr, obs) in enumerate(numaster_df[:obsid])
        downloaded[itr] = obs in file_list_local ? 1 : 0
        cleaned[itr] = obs in file_list_local_clean ? 1 : 0
    end

    numaster_df[:Downloaded] = downloaded
    numaster_df[:Cleaned]    = cleaned

    # Convert modified Julian dates to readable dates
    numaster_df[:time] = map(x -> Base.Dates.julian2datetime(parse(Float64, x) + 2400000.5), numaster_df[:time])
    numaster_df[:end_time] = map(x -> Base.Dates.julian2datetime(parse(Float64, x) + 2400000.5), numaster_df[:end_time])
    numaster_df[:processing_date] = map(x -> Base.Dates.julian2datetime(parse(Float64, x) + 2400000.5), numaster_df[:processing_date])
    numaster_df[:public_date] = map(x -> Base.Dates.julian2datetime(parse(Float64, x) + 2400000.5), numaster_df[:public_date])

    CSV.write("D:\\Users\\Robert\\Desktop\\numaster.csv", numaster_df)

    info("Creating CSV")
    numaster_path = string(local_archive, "/00000000000 - utility/numaster_df.csv")

    try
        if isfile(numaster_path)
            warn("Catalog file already exists, replacing")
            mv(numaster_path, string(local_archive, "/00000000000 - utility/numaster_df_old.csv"), remove_destination=true)
        end

        CSV.write(numaster_path, numaster_df)
    catch ex
        warn("Could not write to file, is file open?")
        log_file_temp = string(numaster_path[1:end-4], "_", tempname()[end-7:end-4], ".csv")
        info("Saving as temp file - $(log_file_temp)")

        CSV.write(log_file_temp, numaster_df)
        rethrow(ex)
    end

    Info("Done")

    #CSV.read("D:\\Users\\Robert\\Desktop\\numaster.csv", rows_for_type_detect=3000, nullable=true)
end

function NumasterSummary(;numaster_path="")
    if numaster_path == ""
        local_archive, local_archive_clean = find_default_path()
        numaster_path = string(local_archive, "/00000000000 - utility/numaster_df.csv")
    end

    numaster_df = read_numaster(numaster_path)

    total = size(numaster_df, 1)
    downloaded = sum(numaster_df[:Downloaded])
    cleaned = sum(numaster_df[:Cleaned])

    println("$total archived observations")
    println("$downloaded / $total downloaded")
    println("$cleaned / $total cleaned")
end
