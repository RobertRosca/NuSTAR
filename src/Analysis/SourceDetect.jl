"""
    FITS_Coords(path)

Reads fits file at `path` using the `FITSIO` module, pulls out the second table
and reads the `X` and `Y` variables into a `DataFrame`

Removes rows with values of `-1`, assumed to be nulled
"""
function FITS_Coords(path)
    fits_file = FITS(path)
    fits_coords = DataFrame(X = read(fits_file[2], "X"), Y = read(fits_file[2], "Y"))
    deleterows!(fits_coords, find(fits_coords[:, :X] .== -1)) # Remove nulled points

    close(fits_file)

    return fits_coords
end

"""
    FWXM_Single_Source(path; prcnt=0.5, filt_flag=true, verbose=true)

Takes in path, passes to FITS_Coords(path), finds Full Width at prcnt-Max for,
returns bounds for FWXM, centre pixel, centre FK5 coordinates, and a flag
indicating the reliability of the source position based on the width
"""
function FWXM_Single_Source(path; prcnt=0.75, filt_flag=false, verbose=true)
    evt_coords = FITS_Coords(path)

    bnds_out = DataFrame(item = ["min_pix", "max_pix", "min_val", "max_val"])

    binedge = linspace(1, 1000, 1000)

    widths  = []
    heights = []

    for coord in names(evt_coords)
        hist_y = StatsBase.fit(StatsBase.Histogram, evt_coords[coord], binedge, closed=:right).weights
        hist_x = StatsBase.fit(StatsBase.Histogram, evt_coords[coord], binedge, closed=:right).edges[1]

        if filt_flag
            hist_y_old = copy(hist_y)
            hist_y = sgolayfilt(hist_y, 2, 21)
        end

        max_y_val, max_y_ind = findmax(hist_y)

        max_ind = Int(max_y_ind + findfirst(hist_y[max_y_ind:end] .<= max_y_val*prcnt))
        min_ind = Int(max_y_ind - findfirst(hist_y[max_y_ind:-1:1] .<= max_y_val*prcnt))

        if verbose
        println("Selected region for $(coord): $(hist_x[min_ind]) ($(@sprintf("%.3f", hist_y[min_ind]))) ",
                                           "to $(hist_x[max_ind]) ($(@sprintf("%.3f", hist_y[max_ind])))")
        end

        bnds_out[coord] = [hist_x[min_ind], hist_x[max_ind], hist_y[min_ind], hist_y[max_ind]]

        append!(heights, [hist_y])
    end

    X_mean = mean([bnds_out[1, :X], bnds_out[2, :X]])
    Y_mean = mean([bnds_out[1, :Y], bnds_out[2, :Y]])

    source_centre_pix = [X_mean, Y_mean]

    source_centre_fk5 = FITSWCS(path, source_centre_pix)

    bound_width = FITSWCS_Delta(path=path, flag_pix=true,
                                [bnds_out[:X][1], bnds_out[:Y][1]],
                                [bnds_out[:X][2], bnds_out[:Y][2]])

    println("Width: $bound_width")

    covariance = cov(heights[1], heights[2])[1]

    println("Covariance: $covariance")

    in_x = bnds_out[1, :X] .< evt_coords[:X] .< bnds_out[2, :X]
    in_y = bnds_out[1, :Y] .< evt_coords[:Y] .< bnds_out[2, :Y]

    in_both = in_x .& in_y

    counts = count(x->x==true, in_both)

    println("Source counts: $counts")

    source_statistics = Dict("bound_width"=>bound_width, "covariance"=>covariance, "counts"=>counts)

    # Auto bad-path for width > 300, cov < 1000 ?

    println("Source centre pixel coords: $source_centre_pix -- α: $(@sprintf("%.9f", source_centre_fk5[1])), δ: $(@sprintf("%.9f", source_centre_fk5[2]))")

    return bnds_out, source_centre_pix, source_centre_fk5, source_statistics
end

"""
    MakeSourceReg(path)

Takes in path, passes it to FWXM_Single_Source(path)

Uses the returned α and δ coordinates as well as the flag_manual_check value
to create a `.reg` file. Asks for user input it flag_manual_check is true
"""
function MakeSourceReg(path; skip_bad=false)
    _, _, (ra, dec), source_statistics = FWXM_Single_Source(path)

    header = "\# Region file format: SourceDetect.jl - Source auotgenerate for $path"
    coord_type = "fk5"
    shape = "circle($ra,$dec,30\")"

    lines_source = [header, coord_type, shape]

    obs_path = replace(splitdir(path)[1], "pipeline_out", "") # Get the path to the root obs folder

    source_reg_file_unchecked = string(obs_path, "source_unchecked.reg")

    open(source_reg_file_unchecked, "w") do f
        for line in lines_source
            write(f, "$line \n")
        end
    end

    print("\n")

    # For stats, assume rough pattern of: Auto bad-path for width > 300, cov < 1000 ?
    #  Uncertain   - bound_width > 60  || covariance < 5000
    #  Certain bad - bound_width > 300 || covariance < 1000

    stats_flag = 1 # 1 Auto-accepts

    if source_statistics["counts"] < 100
        stats_flag = -1
    elseif source_statistics["covariance"] < 500
        stats_flag = -1 # Auto bad
    elseif source_statistics["bound_width"] > 300 && source_statistics["covariance"] < 1000
        stats_flag = -1 # Auto bad
    elseif source_statistics["bound_width"] > 60 || source_statistics["covariance"] < 5000
        stats_flag = -2 # Need to check
    end

    if stats_flag == 1 # Auto-good
        info("Stats appear good - continuing")

        save_ds9_img = `ds9 $path -regions $source_reg_file_unchecked -saveimage $(string(obs_path, "source_region_", splitdir(path)[2][1:end-4], ".jpeg")) -exit`
        run(save_ds9_img)

        mv(source_reg_file_unchecked, string(obs_path, "source.reg"), remove_destination=true)
    elseif stats_flag == -1 # Auto-bad
        warn("Stats appear bad, excluded from scientific data product")
        mv(source_reg_file_unchecked, string(obs_path, "source_bad.reg"))
    elseif stats_flag == -2 # Manual
        info("Stats are uncertain, manual check")

        if skip_bad
            info("Auto skipping manual checks, check later")
            return
        end

        cd(string(dirname(path), "/.."))

        command = `ds9 $path -regions $source_reg_file_unchecked`

        run(command)

        info("Correct region y/n/b/i?")
        response = readline(STDIN)

        if response == "y"
            #save_ds9_img = `ds9 $path -regions $source_reg_file_unchecked -saveimage $(string(obs_path, "source_region_", splitdir(path)[2][1:end-4], ".jpeg")) -exit`
            #run(save_ds9_img)

            mv(source_reg_file_unchecked, string(obs_path, "source.reg"))
        elseif response == "n"
            info("Fix later")
        elseif response == "b"
            info("Bad source, excluded from scientific data product")
            mv(source_reg_file_unchecked, string(obs_path, "source_bad.reg"))
        elseif response[1][1] == 'i'
            info("Interesting source, excluded, notes added")

            note_path = string(obs_path, "note.txt")
            info("Included note at $note_path")
            mv(source_reg_file_unchecked, string(obs_path, "source_interesting.reg"), remove_destination=true)

            open(note_path, "w") do f
                write(f, response[3:end])
            end
        end
    end

    return
end

function FindBackgroundReg(path_src)
    path_obs = string(dirname(path_src), "/pipeline_out/nu", split(dirname(path_src), "/")[end], "A01_cl.evt")

    offset_sec = 80
    offset_deg = offset_sec/60/60

    f = open(path_src)

    file_src = readlines(f)

    close(f)

    splt = split(file_src[end], ",")

    if contains(splt[2], ":")
        # Assume sexagesimal coordinates
        ra, dec = (replace(splt[1], "circle(", ""), splt[2])

        ra_splt = split(ra, ":")
        dec_splt = split(dec, ":")

        ra_bkg = string(ra_splt[1], ":", ra_splt[2], ":", ra_splt[3])
        dec_bkg = string(dec_splt[1], ":", dec_splt[2], ":", parse(Float64, dec_splt[3]) + offset_sec)
    else
        # Assumes degree coordinates
        ra = parse(Float64, replace(splt[1], "circle(", ""))
        dec = parse(Float64, splt[2])

        ra_bkg = ra
        dec_bkg = dec + offset_deg
    end

    return ra_bkg, dec_bkg
end


"""
    MakeBackgroundReg(path_src)

Takes in path_src, passes it to FWXM_Single_Source(path_src)

Uses the returned α and δ coordinates as well as the flag_manual_check value
to create a `.reg` file. Asks for user input it flag_manual_check is true
"""
function MakeBackgroundReg(path_src)
    ra, dec = FindBackgroundReg(path_src)

    header = "\# Region file format: SourceDetect.jl - Background auotgenerate for $path_src"
    coord_type = "fk5"
    shape = "circle($ra,$dec,30\")"

    lines_source = [header, coord_type, shape]

    obs_path = replace(splitdir(path_src)[1], "pipeline_out", "") # Get the path to the root obs folder

    background_reg_file = string(obs_path, "/background.reg")

    open(background_reg_file, "w") do f
        for line in lines_source
            write(f, "$line \n")
        end
    end

    path_obs = string(dirname(path_src), "/pipeline_out/nu", split(dirname(path_src), "/")[end], "A01_cl.evt")

    image_file = string(dirname(path_src), "/regions_", splitdir(path_obs)[2][1:end-4], ".jpeg")

    if isfile(image_file)
        rm(image_file)
    end

    save_ds9_img = `ds9 $path_obs -region $path_src -region $background_reg_file -saveimage $image_file -exit`
    run(save_ds9_img)

    return
end

function RegBatch(;local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"],
                   local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path="",
                   batch_size=100, skip_bad=true, src_type="both", bad_only=false)
    if numaster_path == ""
        numaster_path = string(local_utility, "/numaster_df.csv")
    end

    if bad_only
        #skip_bad = false
        src_include_val = -2 # Change checked value to -2 for @where below
    else
        src_include_val = 0
    end

    if src_type=="both" || src_type=="src"
        Numaster(download=false)
        numaster_df = read_numaster(numaster_path)

        # Source region creation
        queue_src = @from i in numaster_df begin
                @where  i.RegSrc==src_include_val && i.ValidSci==1 # Doesn't already have a source AND is valid science
                @select string(local_archive_cl, "/$(i.obsid)/pipeline_out/nu$(i.obsid)", "A01_cl.evt")
                @collect
        end

        queue_src = queue_src[end:-1:1] # Reverse order

        if length(queue_src) > batch_size
            queue_src = queue_src[1:batch_size]
        end

        for obs_evt in queue_src
            info("Getting region for $obs_evt")
            MakeSourceReg(obs_evt; skip_bad=skip_bad)
        end

        info("Updating Numaster table")
    end

    if src_type=="both" || src_type=="bkg"
        Numaster(download=false)
        numaster_df = read_numaster(numaster_path)

        # Background region creation
        queue_bkg = @from i in numaster_df begin
                @where  i.RegSrc==1 && i.RegBkg==0 # Valid source exists
                @select string(local_archive_cl, "/$(i.obsid)/source.reg")
                @collect
        end

        queue_bkg = queue_bkg[end:-1:1] # Reverse order

        if length(queue_bkg) > batch_size
            queue_bkg = queue_bkg[1:batch_size]
        end

        for path_src in queue_bkg
            info("Creating background for $path_src")
            MakeBackgroundReg(path_src)
        end

        info("Updating Numaster table")
    end
end
