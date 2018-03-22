function extract_evts(evt_path; gti_width_min = 128)
    evt_file = FITS(evt_path)
    evt_time_start = read_key(evt_file[1], "TSTART")[1] + 0.5 # These are off by 1/2 sec, for some reason...
    evt_time_stop  = read_key(evt_file[1], "TSTOP")[1] + 0.5
    evt_time_elapse = read_key(evt_file[1], "TELAPSE")[1]

    evt_events = DataFrame(TIME=read(evt_file[2], "TIME").-evt_time_start, PI=read(evt_file[2], "PI"),
        X=read(evt_file[2], "X"), Y=read(evt_file[2], "Y"))

    # Create tuple of GTI start and stop times, [sec] since evt_time_start
    evt_gtis = @from gti in evt_gti begin
        @where gti.GOOD == 1
        @select [gti.START, gti.STOP]
        @collect
    end

    bin_sec = 2e-3 # 2e-3 for unbinned data
    evt_time_edges = 1:bin_sec:(evt_time_stop-evt_time_start); # Construct edges for histogram, start at 0 and finish at stop time (w.r.t. obs start)

    gti_intervals = size(evt_gtis, 1)
    evt_gtis = hcat(evt_gtis...)' # Convert to matrix
    evt_gtis = round.(evt_gtis, 3) # Fix floating point errors

    gtis = map(x->findfirst(evt_time_edges.>=x), evt_gtis) .- [zeros(Int, gti_intervals) ones(Int, gti_intervals)] # Subtract one from the GTI end bins
    gtis = range.(gtis[:, 1], gtis[:, 2].-gtis[:, 1])

    evt_counts = begin
        hist_test = fit(Histogram, evt_events[:TIME], evt_time_edges, closed=:left)
        sparse(hist_test.weights) # Perform histogram fit, return sparse vector to save on computation
    end

    return evt_counts, evt_time_edges, gti_intervals
end
