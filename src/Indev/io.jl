struct Unbinned_event
    obsid::String
    event::DataFrames.DataFrame
    gtis::Array{Array{Float64,1},1}
    stop::Float64
    start::Float64
end

function save_evt(evt_data_path, file_mode="w"; kwargs...)
    if !isdir(dirname(evt_data_path))
        mkpath(dirname(evt_data_path))
    end

    jldopen(evt_data_path, file_mode) do file
        for kw in kwargs
            file[string(kw[1])] = kw[2]
        end
    end

    return
end

function save_evt!(evt_data_path; kwargs...)
    save_evt(evt_data_path, file_mode="a+"; kwargs...)

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

function extract_evts(evt_path::String; gti_width_min::Number=128)
    evt_file = FITS(evt_path)
    evt_obsid = read_key(evt_file[1], "OBS_ID")[1]
    evt_time_start = read_key(evt_file[1], "TSTART")[1]
    evt_time_stop  = read_key(evt_file[1], "TSTOP")[1]
    evt_time_elapse = read_key(evt_file[1], "TELAPSE")[1]

    evt_events = DataFrame(TIME=read(evt_file[2], "TIME").-evt_time_start, PI=read(evt_file[2], "PI"),
        X=read(evt_file[2], "X"), Y=read(evt_file[2], "Y"))

    evt_gti = DataFrame(START=read(evt_file[3], "START").-evt_time_start, STOP=read(evt_file[3], "STOP").-evt_time_start)
    evt_gti[:WIDTH] = evt_gti[:STOP] .- evt_gti[:START] # GTI interval width in seconds
    evt_gti[:GOOD]  = evt_gti[:WIDTH] .>= gti_width_min

    warn("$(count(evt_gti[:GOOD].==0)) GTIs under $gti_width_min s excluded")

    # Create tuple of GTI start and stop times, [sec] since evt_time_start
    evt_gtis = @from gti in evt_gti begin
        @where gti.GOOD == 1
        @select [gti.START, gti.STOP]
        @collect
    end

    return Unbinned_event(evt_obsid, evt_events, evt_gtis, evt_time_stop, evt_time_start)
end
