struct Unbinned_event
    obsid::String
    event::DataFrames.DataFrame
    gtis::Array{Array{Float64,1},1}
    stop::Float64
    start::Float64
end

struct Binned_event
    obsid::String
    typeof::String
    bin::Number
    counts::SparseVector
    time_edges::StepRangeLen
    gtis::Array{UnitRange{Int64},1}
end

function save_evt(evt_data_path; kwargs...)
    if !isdir(dirname(evt_data_path))
        mkpath(dirname(evt_data_path))
    end

    jldopen(evt_data_path, "w") do file
        for kw in kwargs
            file[string(kw[1])] = kw[2]
        end
    end

    return
end

function save_evt!(evt_data_path; kwargs...)
    jldopen(evt_data_path, "a+") do file
        for kw in kwargs
            file[string(kw[1])] = kw[2]
        end
    end

    return
end

function read_evt(evt_data_path, item="")
    jldopen(evt_data_path, "r") do file
        if item == ""
            items = keys(file)
            if length(items) == 1
                return load(evt_data_path, string(items[1]))
            else
                error("$(length(items)) groups in data file, set item to: $items")
            end
        else
            return load(evt_data_path, item)
        end
    end
end

function extract_evts(evt_path; gti_width_min::Number=128)
    evt_file = FITS(evt_path)
    evt_obsid = read_key(evt_file[1], "OBS_ID")[1]
    evt_time_start = read_key(evt_file[1], "TSTART")[1]
    evt_time_stop  = read_key(evt_file[1], "TSTOP")[1]
    evt_time_elapse = read_key(evt_file[1], "TELAPSE")[1]

    evt_events = DataFrame(TIME=read(evt_file[2], "TIME").-evt_time_start, PI=read(evt_file[2], "PI"),
        X=read(evt_file[2], "X"), Y=read(evt_file[2], "Y"))

    evt_gti = DataFrame(START=read(evt_file[3], "START").-evt_time_start, STOP=read(evt_file[3], "STOP").-evt_time_start)
    evt_gti[:WIDTH] = evt_gti[:STOP] .- evt_gti[:START] # GTI interval width in seconds
    evt_gti[:GOOD]  = evt_gti[:WIDTH] .>= gti_width_min;

    # Create tuple of GTI start and stop times, [sec] since evt_time_start
    evt_gtis = @from gti in evt_gti begin
        @where gti.GOOD == 1
        @select [gti.START, gti.STOP]
        @collect
    end

    return Unbinned_event(evt_obsid, evt_events, evt_gtis, evt_time_stop, evt_time_start)
end

function bin_evts_lc(unbinned::Unbinned_event, bin_sec::Real)
    if bin_sec < 2e-6
        error("NuSTAR temportal resolution is 2e-3, cannot bin under that value, binsec $bin_sec is invalid")
    end

    evt_time_edges = 0:bin_sec:(unbinned.stop-unbinned.start) # Construct edges for histogram, finish at stop time (w.r.t. obs start)

    gti_intervals = size(unbinned.gtis, 1)
    evt_gtis = hcat(unbinned.gtis...)' # Convert to matrix

    gtis = map(x->findfirst(evt_time_edges.>=x), evt_gtis) .- [zeros(Int, gti_intervals) ones(Int, gti_intervals)] # Subtract one from the GTI end bins
    if gtis[end] == -1; gtis[end] = length(evt_time_edges); end # Fix for GTI at end of time
    gtis = range.(gtis[:, 1], gtis[:, 2].-gtis[:, 1])

    evt_counts = begin
        hist_binning = fit(Histogram, unbinned.event[:TIME], evt_time_edges, closed=:left)
        sparse(hist_binning.weights) # Perform histogram fit, return sparse vector to save on computation
    end

    return Binned_event(unbinned.obsid, "lc", bin_sec, evt_counts, evt_time_edges, gtis)
end
