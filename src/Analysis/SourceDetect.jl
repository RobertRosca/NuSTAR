"""
    FITS_Coords(fits_path)

Reads fits file at `fits_path` using the `FITSIO` module, pulls out the second table
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
    FWXM_Single_Source(evt_coords; prcnt=0.5, filt_flag=true, verbose=true)

Takes in `X, Y` coordinates,
"""
function FWXM_Single_Source(path; prcnt=0.5, filt_flag=true, verbose=true)
    evt_coords = FITS_Coords(path)

    data_out = similar(evt_coords, 0)
    bnds_out = DataFrame(item = ["min_pix", "max_pix", "min_val", "max_val"])

    widths = []

    for coord in names(evt_coords)
        hist_y = StatsBase.fit(StatsBase.Histogram, evt_coords[coord], nbins=1024, closed=:right).weights
        hist_x = StatsBase.fit(StatsBase.Histogram, evt_coords[coord], nbins=1024, closed=:right).edges[1]

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

        data_out = evt_coords[Int(hist_x[min_ind]) .< evt_coords[coord] .< Int(hist_x[max_ind]), :]
        bnds_out[coord] = [hist_x[min_ind], hist_x[max_ind], hist_y[min_ind], hist_y[max_ind]]
    end

    X_mean = mean([bnds_out[1, :X], bnds_out[2, :X]])
    Y_mean = mean([bnds_out[1, :Y], bnds_out[2, :Y]])

    source_centre_pix = [X_mean, Y_mean]

    source_centre_fk5 = FITSWCS(path, source_centre_pix)

    bound_width = FITSWCS_Delta(path, [bnds_out[:X][1], bnds_out[:Y][1]],
                                      [bnds_out[:X][2], bnds_out[:Y][2]])

    info("Width: α - $(bound_width[1]), δ - $(bound_width[2])")

    flag_manual_check = false

    if bound_width[1] > 50 || bound_width[2] > 50
        flag_manual_check = true
        warn("Manual check, large width")
    end

    println("Source centre pixle coords: $source_centre_pix -- α: $(@sprintf("%.9f", source_centre_fk5[1])), δ: $(@sprintf("%.9f", source_centre_fk5[2]))")

    return data_out, bnds_out, source_centre_pix, source_centre_fk5, flag_manual_check
end

#=
path = "/mnt/hgfs/.nustar_archive_cl/80102101004/pipeline_out/nu80102101004A01_cl.evt"
path = "/mnt/hgfs/.nustar_archive_cl/30460021002/pipeline_out/nu30460021002A01_cl.evt"

evt_coords = FITS_Coords(path)

(a, b) = FWXM_Single_Source(path; prcnt=0.75, filt_flag=true, verbose=true)
=#


#=
# Region file format: DS9 version 4.1
global color=green dashlist=8 3 width=1 font="helvetica 10 normal roman" select=1 highlite=1 dash=0 fixed=0 edit=1 move=1 delete=1 include=1 source=1
fk5
circle(6:32:59.243,+5:48:04.08,20")
=#

function MakeSourceReg(path)
    _, _, _, (ra, dec), flag_manual_check = FWXM_Single_Source(path)

    header = "\# Region file format: SourceDetect.jl auotgenerate for $path"
    coord_type = "fk5"
    shape = "circle($ra,$dec,20\")"

    lines_source = [header, coord_type, shape]

    obs_path = replace(splitdir(path)[1], "pipeline_out", "") # Get the path to the root obs folder

    source_reg_file_unchecked = string(obs_path, "source_unchecked.reg")

    open(source_reg_file_unchecked, "w") do f
        for line in lines_source
            write(f, "$line \n")
        end
    end

    if flag_manual_check
        command = `ds9 $path -regions $source_reg_file_unchecked`

        run(command)

        info("Correct region y/n?")
        response = readline(STDIN)

        if response == "y"
            mv(source_reg_file_unchecked, string(obs_path, "source.reg"))
        elseif response == "n"
            info("Fix later")
        elseif response == "b"
            info("Bad source, excluded from scientific data product")
            mv(source_reg_file_unchecked, string(obs_path, "source_bad.reg"))
        end
    else
        info("No manual flag - continuing")

        command = `ds9 $path -regions $source_reg_file_unchecked -saveimage $(string(obs_path, "source_region_", splitdir(path)[2][1:end-4], ".jpeg"))`

        mv(source_reg_file_unchecked, string(obs_path, "source.reg"))
    end
end

#=
MakeSourceReg("/mnt/hgfs/.nustar_archive_cl/30202004008/pipeline_out/nu30202004008A01_cl.evt")

using FITSIO, WCS, DataFrames
=#

function RegBatch(;local_archive="", log_file="", batch_size=100)
    if local_archive == ""
        local_archive, local_archive_clean, local_utility = find_default_path()
        numaster_path = string(local_utility, "/numaster_df.csv")
    end

    numaster_df = CSV.read(numaster_path, rows_for_type_detect=3000, nullable=true)

    queue = []

    println("Added to queue:")
    obs_count = size(numaster_df, 1)[1]; bs = 0
    for i = 0:obs_count-1 # -1 for the utility folder
        ObsID  = string(numaster_df[obs_count-i, :obsid])
        ObsSci = numaster_df[obs_count-i, :ValidSci] == Nullable(1) # Exclude slew/other non-scientific observations
        ObsSrc = numaster_df[obs_count-i, :RegSrc] == Nullable(1)

        if ObsSci && !ObsSrc # Is valid science, doesn't already have source file
            append!(queue, [string(local_archive_cl, "/$ObsID/pipeline_out/nu$ObsID", "A01_cl.evt")])

            print(string(ObsID, ", "))

            bs += 1

            if bs >= batch_size
                println("\n")
                break
            end
        end
    end

    for obs_evt in queue
        info("Getting region for $obs_evt")
        MakeSourceReg(obs_evt)
    end
end
