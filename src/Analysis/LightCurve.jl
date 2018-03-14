function read_fits_lc(filepath)
    file = FITS(filepath)

    rate = read(file[2], "RATE")
    time = read(file[2], "TIME")
    error = read(file[2], "ERROR")

    lc_data = DataFrame(Rate=rate, Time=time, Error=error)

    return lc_data
end

function plot_lightcurve(filepath, obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"])
    lc_data = NuSTAR.read_fits_lc(filepath)
    lc_name = replace(basename(filepath), ".fits", "");

    plt_lc_main = string(local_archive_pr, "/$obsid/images/lc/$lc_name/$lc_name", "_full.png")

    if isfile(plt_lc_main)
        plt_lc_main_maketime = stat(plt_lc_main).mtime
        lc_data_maketime = stat(filepath).mtime

        if plt_lc_main_maketime - lc_data_maketime > 0 # Image newer than source lc data
            info("Skipped $obsid - $lc_name image newer than data"); print("\n")
            return
        end
    else
        info("Making $obsid lc for $lc_name")
    end

    if !isdir(dirname(plt_lc_main))
        mkpath(dirname(plt_lc_main))
    end

    lc_bins = parse(Float64, replace(lc_name, "lc_", ""))

    interval_time_end   = find(x->x!=lc_bins, diff(lc_data[:Time]))
    interval_time_start = find(x->x!=lc_bins, diff(lc_data[:Time])) .+ 1
    interval_time_start = [1; interval_time_start];

    plot(lc_data[:Time], lc_data[:Rate], size=(1920, 1080), lab="", title="$obsid - $lc_name - full lc")
    vline!(lc_data[:Time][interval_time_start], color=:green, lab="Start", alpha=0.25)
    lc_plot = vline!(lc_data[:Time][interval_time_end], color=:red, lab="End", alpha=0.25)

    interval_count = size(interval_time_end, 1)

    plt_intervals = Array{Plots.Plot{Plots.PyPlotBackend},1}(interval_count)

    print("Found $interval_count intervals - plotting ")

    for i = 1:interval_count
        if interval_time_end[i] - interval_time_start[i] < 100
            continue
        end

        plt_intervals[i] = plot(lc_data[:Time][interval_time_start[i]:interval_time_end[i]], lc_data[:Rate][interval_time_start[i]:interval_time_end[i]], lab="", title="$obsid - $lc_name - interval $i", size=(1920, 1080))
    end

    savefig(lc_plot, plt_lc_main)

    for (i, lc_individual) in enumerate(plt_intervals)
        if interval_time_end[i] - interval_time_start[i] < 100
            print("($i)")
            continue
        end

        print("$i ")
        savefig(lc_individual, string(local_archive_pr, "/$obsid/images/lc/$lc_name/$lc_name", "_interval_$i.png"))
    end

    print("\n\n")
end

function PlotLCs(;todo=1000, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"])
    numaster_path = string(local_utility, "/numaster_df.csv")

    numaster_df = read_numaster(numaster_path)

    queue = @from i in numaster_df begin
        @where i.LCData != "none"
        @select [i.obsid, string.("$local_archive_pr/", i.obsid, "/products/lc/", split(i.LCData), ".fits")]
        @collect
    end

    if size(queue, 1) > todo
        queue = queue[1:todo]
    end

    for row in queue
        obsid = row[1]
        for path in row[2]
            plot_lightcurve(path, obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"])
        end
    end
end
