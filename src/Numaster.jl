"""
    Numaster(;local_archive="", local_archive_clean="", local_utility="")

Updates the numaster_df DataFrame holding observation data

Downloads new version, then works through local archives to set the flags for
what data has been processed so far
"""
function Numaster(;local_archive=ENV["NU_ARCHIVE"], local_archive_clean=ENV["NU_ARCHIVE_CL"], local_utility="", download=true)
    if local_utility == ""
        local_utility = string(local_archive, "/00000000000 - utility")
    end

    if !isdir(local_utility)
        mkpath(local_utility)
    end

    numaster_url  = "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz"
    numaster_path_live = string(local_utility, "/numaster_live.txt")

    if download
        info("Downloading latest NuSTAR master catalog")
        Base.download(numaster_url, numaster_path_live)

        if VERSION >= v"0.7.0" || Sys.is_linux()
            # Windows (used to) unzip .gz during download, unzip now if Linux
            unzip!(numaster_path_live)
        end
    end

    numaster_ascii = readdlm(numaster_path_live, '\n')

    # Find start and end points of data, +/-1 to skip the tags themselves
    data_start = Int(find(numaster_ascii .== "<DATA>")[1] + 1)
    data_end   = Int(find(numaster_ascii .== "<END>")[1] - 1)
    keys_line  = data_start - 2

    # Key names are given on the keys_line, split and make into symbols for use later
    key_names = Symbol.(split(numaster_ascii[keys_line][11:end])) # 11:end to remove 'line[1] = '
    # name ra dec lii bii roll_angle time end_time obsid exposure_a exposure_b ontime_a ontime_b observation_mode instrument_mode spacecraft_mode slew_mode processing_date public_date software_version prnb abstract subject_category category_code priority pi_lname pi_fname copi_lname copi_fname country cycle obs_type title data_gap nupsdout solar_activity coordinated issue_flag comments status caldb_version

    numaster_ascii_data = numaster_ascii[data_start:data_end]

    numaster_df = DataFrame(zeros(1, 41), key_names)

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
                cleaned = replace(obs_values[itr], ",", ".. ") # Remove some punctuation, screw with CSV
                cleaned = replace(cleaned, ";", ".. ")
                df_tmp[key] = cleaned
            end

            numaster_df = [numaster_df; df_tmp] # Concat
        end
    end

    # delete!(numaster_df, :abstract)

    sort!(numaster_df, cols=(:public_date))

    file_list_local       = readdir(local_archive)[2:end]
    file_list_local_clean = readdir(local_archive_clean)[2:end]

    numaster_df_n = size(numaster_df, 1)

    downloaded = zeros(Int, numaster_df_n)
    cleaned    = zeros(Int, numaster_df_n)

    for (itr, obs) in enumerate(numaster_df[:obsid])
        downloaded[itr] = obs in file_list_local ? 1 : 0
        cleaned[itr] = obs in file_list_local_clean ? 1 : 0
    end

    numaster_df[:Downloaded] = downloaded
    numaster_df[:Cleaned]    = cleaned

    valid_sci  = zeros(Int, numaster_df_n)
    reg_src    = zeros(Int, numaster_df_n)
    reg_bkg    = zeros(Int, numaster_df_n)

    for (itr, obs) in enumerate(numaster_df[:obsid])
        if cleaned[itr] == 1
            valid_sci[itr]  = isfile(string(local_archive_clean, "/", obs, "/pipeline_out/", "nu", obs, "A01_cl.evt")) ? 1 : 0

            if isfile(string(local_archive_clean, "/", obs, "/source.reg"))
                reg_src[itr] = 1 # Valid source file
            elseif isfile(string(local_archive_clean, "/", obs, "/source_intersting.reg"))
                reg_src[itr] = 2 # 'Interesting' source file
            elseif isfile(string(local_archive_clean, "/", obs, "/source_bad.reg"))
                reg_src[itr] = -1 # Bad source, ignore during analysis
            elseif isfile(string(local_archive_clean, "/", obs, "/source_unchecked.reg"))
                reg_src[itr] = -2 # Unchecked source, queue for later check
            else
                reg_src[itr] = 0 # No source file yet
            end

            reg_bkg[itr] = isfile(string(local_archive_clean, "/", obs, "/background.reg")) ? 1 : 0
        end
    end

    numaster_df[:ValidSci] = valid_sci
    numaster_df[:RegSrc]   = reg_src
    numaster_df[:RegBkg]   = reg_bkg

    # Convert modified Julian dates to readable dates
    numaster_df[:time] = map(x -> Base.Dates.julian2datetime(parse(Float64, x) + 2400000.5), numaster_df[:time])
    numaster_df[:end_time] = map(x -> Base.Dates.julian2datetime(parse(Float64, x) + 2400000.5), numaster_df[:end_time])
    numaster_df[:processing_date] = map(x -> Base.Dates.julian2datetime(parse(Float64, x) + 2400000.5), numaster_df[:processing_date])
    numaster_df[:public_date] = map(x -> Base.Dates.julian2datetime(parse(Float64, x) + 2400000.5), numaster_df[:public_date])

    info("Creating CSV")
    numaster_path = string(local_utility, "/numaster_df.csv")

    try
        if isfile(numaster_path)
            warn("Catalog file already exists, replacing")
            mv(numaster_path, string(local_utility, "/numaster_df_old.csv"), remove_destination=true)
        end

        CSV.write(numaster_path, numaster_df)
    catch ex
        warn("Could not write to file, is file open?")
        log_file_temp = string(numaster_path[1:end-4], "_", tempname()[end-7:end-4], ".csv")
        info("Saving as temp file - $(log_file_temp)")

        CSV.write(log_file_temp, numaster_df)
        rethrow(ex)
    end

    info("Done")
end

"""
    Summary(;numaster_path="")

Outputs summary of what data can be analysed, and what has been done so far
"""
function Summary(;local_archive=ENV["NU_ARCHIVE"], numaster_path="")
    if numaster_path == ""
        local_utility = string(local_archive, "/00000000000 - utility")
        numaster_path = string(local_utility, "/numaster_df.csv")
    end

    numaster_df = read_numaster(numaster_path)

    total = count(numaster_df[:observation_mode] .== "SCIENCE")
    downloaded = sum(numaster_df[:Downloaded])
    cleaned    = sum(numaster_df[:Cleaned])
    valid_sci  = sum(numaster_df[:ValidSci])
    reg_src    = count(numaster_df[:RegSrc] .== 1)
    bad_reg_src    = count(numaster_df[:RegSrc] .== -1)
    check_reg_src    = count(numaster_df[:RegSrc] .== -2)

    println("$(size(numaster_df, 1)) archived observations")
    println("$total archived observations - SCIENTIFIC")
    println("$downloaded / $total downloaded")
    println("$cleaned / $downloaded cleaned")
    println("$valid_sci / $cleaned valid sci - A01_cl present")
    println("$reg_src / $valid_sci source.reg present out of valid sci")
    println("$bad_reg_src / $valid_sci bad source region out of valid sci")
    println("$check_reg_src / $valid_sci check source region out of valid sci")
end

function Summary_list(col, comp, val; archive="cl", numaster_path="", res=:obsid)
    if local_archive == ""
        dirs = find_default_path()
        local_archive = dirs["dir_archive"]
        local_archive_cl = dirs["dir_archive_cl"]
        local_utility = dirs["dir_utility"]
        numaster_path = string(local_utility, "/numaster_df.csv")
    end

    if archive == "cl"
        ar = local_archive_clean
    else
        ar = local_archive
    end

    numaster_df = read_numaster(numaster_path)

    comp = Symbol(comp)

    col_list = @from i in numaster_df begin
            @where eval(Expr(:call, comp, getfield(i, Symbol(col)), val))
            @select eval(getfield(i, Symbol(res)))
            @collect
    end
end
