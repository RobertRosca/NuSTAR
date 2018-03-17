function read_fits_lc(filepath)
    file = FITS(filepath)

    rate = read(file[2], "RATE")
    time = read(file[2], "TIME")
    error = read(file[2], "ERROR")

    lc_data = DataFrame(Rate=rate, Time=time, Error=error)

    return lc_data
end

function find_lightcurve_intervals(lc_data, lc_bins, min_interval_width_s)
    interval_time_end   = find(x->x!=lc_bins, diff(lc_data[:Time]))
    interval_time_end   = [interval_time_end; Int(length(lc_data[:Time]))]

    interval_time_start = find(x->x!=lc_bins, diff(lc_data[:Time])) .+ 1
    interval_time_start = [1; interval_time_start]

    interval_widths     = interval_time_end .- interval_time_start

    min_interval_width  = min_interval_width_s/lc_bins

    interval_time_start = interval_time_start[interval_widths .> min_interval_width]
    interval_time_end   = interval_time_end[interval_widths .> min_interval_width]

    interval_count = count(interval_widths .> min_interval_width)
    interval_count_bad = count(interval_widths .< min_interval_width)

    return interval_time_start, interval_time_end, interval_widths, min_interval_width, interval_count, interval_count_bad
end

function find_lightcurve_fft(lc_gti, interval_count)
    lc_gti_fft = Dict()

    largest_gti_dim = 0

    for gti in 1:interval_count
        gti_size = size(lc_gti[gti][:Rate], 1)

        if gti_size > largest_gti_dim
            largest_gti_dim = gti_size
        end
    end

    largest_fft_dim = 0

    for gti in 1:interval_count
        lc_gti_rate = lc_gti[gti][:Rate] .- mean(lc_gti[gti][:Rate]) # Signal detrending
        gti_size = size(lc_gti_rate, 1)

        if gti_size < largest_gti_dim
            diff = largest_gti_dim - gti_size
            padding = zeros(diff)
            lc_gti_rate = [lc_gti_rate; padding]
        end

        lc_gti_fft[gti] = abs.(rfft(lc_gti_rate))

        if size(lc_gti_fft[gti], 1) > largest_fft_dim
            largest_fft_dim = size(lc_gti_fft[gti], 1)
        end
    end

    largest_fft_amp = 0

    sum_fft = zeros(largest_fft_dim)

    conv_fft = ones(largest_fft_dim)

    for gti in 1:interval_count
        sum_fft  += lc_gti_fft[gti]
        conv_fft  = conv_fft.*lc_gti_fft[gti]
        start_idx = round(Int, size(lc_gti_fft[gti],1)*0.005)+1
        if maximum(lc_gti_fft[gti][start_idx:end])>largest_fft_amp
            largest_fft_amp = maximum(lc_gti_fft[gti][start_idx:end])
        end
    end

    sum_fft = sum_fft ./ interval_count

    conv_fft = conv_fft ./ sum(conv_fft)

    lc_gti_fft_matrix = zeros(largest_fft_dim, interval_count)

    for gti in 1:interval_count
        lc_gti_fft_matrix[:, gti] = lc_gti_fft[gti]
    end

    conv_fft_significance =  maximum(conv_fft[5:end])

    return lc_gti_fft_matrix, sum_fft, largest_fft_amp, conv_fft, conv_fft_significance
end

function save_fft(fft_filepath, lc_gti_fft, sum_fft, largest_fft_amp, conv_fft, conv_fft_significance)
    HDF5.h5open(fft_filepath, "w") do file
        write(file, "lc_gti_fft", lc_gti_fft)
        write(file, "sum_fft", sum_fft)
        write(file, "largest_fft_amp", largest_fft_amp)
        write(file, "conv_fft", conv_fft)
        write(file, "conv_fft_significance", conv_fft_significance)
    end
end

function read_fft(fft_filepath)
    lc_gti_fft = Array{Float64,2}
    sum_fft = Array{Float64,1}
    largest_fft_amp = Float32
    conv_fft = Array{Float64,1}

    HDF5.h5open(fft_filepath, "r") do file
        lc_gti_fft = read(file, "lc_gti_fft")
        sum_fft = read(file, "sum_fft")
        largest_fft_amp = read(file, "largest_fft_amp")
        conv_fft = read(file, "conv_fft")
        conv_fft_significance = read(file, "conv_fft_significance")
    end

    return lc_gti_fft, sum_fft, largest_fft_amp, conv_fft, conv_fft_significance
end

function plot_lightcurve(filepath; obsid="", local_archive_pr=ENV["NU_ARCHIVE_PR"], min_interval_width_s=100, overwrite=false, flag_plot_intervals=true, flag_force_plot=false)
    lc_data = NuSTAR.read_fits_lc(filepath)
    lc_name = replace(basename(filepath), ".fits", "");

    obsid=="" ? obsid=split(abspath(string(dirname(filepath), "/..", "/..")), "/")[end-1] : ""

    plt_lc_main_path = string(local_archive_pr, "/$obsid/images/lc/$lc_name/$lc_name", "_full.png")

    fft_filepath = string(dirname(filepath), "/", lc_name, "_fft.hdf5")

    if isfile(plt_lc_main_path) && isfile(fft_filepath) && !overwrite
        plt_lc_main_path_maketime = stat(plt_lc_main_path).mtime
        lc_data_maketime = stat(filepath).mtime

        if plt_lc_main_path_maketime - lc_data_maketime > 0 # Image newer than source lc data
            return 0
        end
    else
        info("Making $obsid lc for $lc_name")
    end

    if !isdir(dirname(plt_lc_main_path))
        mkpath(dirname(plt_lc_main_path))
    end

    lc_bins = parse(Float64, replace(lc_name, "lc_", ""))

    interval_time_start, interval_time_end, interval_widths, min_interval_width, interval_count, interval_count_bad = find_lightcurve_intervals(lc_data, lc_bins, min_interval_width_s)

    lc_gti = Dict()

    for gti in 1:interval_count
        lc_gti[gti] = lc_data[interval_time_start[gti]:interval_time_end[gti], :]
    end

    if isfile(fft_filepath)
        info("Reading saved FFT")
        lc_gti_fft, sum_fft, largest_fft_amp, conv_fft, conv_fft_significance = read_fft(fft_filepath)
    else
        info("Creating FFT file")
        lc_gti_fft, sum_fft, largest_fft_amp, conv_fft, conv_fft_significance = find_lightcurve_fft(lc_gti, interval_count)
        save_fft(fft_filepath, lc_gti_fft, sum_fft, largest_fft_amp, conv_fft, conv_fft_significance)
    end

    if conv_fft_significance > 0.5
        info("*** Significant FFT peak: $(findmax(conv_fft)) ***")
    else
        flag_plot_intervals = false
    end

    plot(lc_data[:Time], lc_data[:Rate], size=(1920, 1080), lab="", title="$obsid - $lc_name - full lc")
    vline!(lc_data[:Time][interval_time_start], color=:green, lab="Start", alpha=0.25)
    lc_plot = vline!(lc_data[:Time][interval_time_end], color=:red, lab="End", alpha=0.25)

    lc_plot_fft = plot()

    for i = 1:interval_count
        plot!(lc_gti_fft[:, i], lab="", alpha=0.25)
    end

    plot!(sum_fft, lab="Sum", linecolor=:black, title="fft")
    lc_plot_fft = ylims!(0, largest_fft_amp*1.1)

    lc_fft_conv = plot(conv_fft, ylims=(1.0e-15, 1), lab="", title="fft conv", linecolor=:black)

    lc_combined_plot = plot(lc_plot, lc_plot_fft, lc_fft_conv, size=(1920, 1080), layout=(3, 1))
    savefig(lc_combined_plot, plt_lc_main_path)

    if flag_plot_intervals || flag_force_plot
        if interval_count_bad > 0
            warn("Excluded $interval_count_bad bad intervals under $min_interval_width [width]")
        end

        print("Found $interval_count intervals - plotting ")

        plt_intervals = Array{Plots.Plot{Plots.PyPlotBackend},1}(interval_count)
        for i = 1:interval_count
            plt_intervals[i] = plot(lc_gti[i][:Time], lc_gti[i][:Rate], lab="", title="$obsid - $lc_name - interval $i", size=(1280, 720))
        end

        plt_intervals_fft = Array{Plots.Plot{Plots.PyPlotBackend},1}(interval_count)
        for i = 1:interval_count
            start_idx = round(Int, size(lc_gti_fft[:, i],1)*0.005)+1
            plt_intervals_fft[i] = plot(lc_gti_fft[:, i], lab="", title="fft", size=(1280, 720), ylims=(0, maximum(lc_gti_fft[:, i][start_idx:end])*1.1))
        end

        for i = 1:interval_count
            print("$i ")
            plt_intervals_combined = plot(plt_intervals[i], plt_intervals_fft[i], layout=(2, 1), size=(1280, 720))
            savefig(plt_intervals_combined, string(local_archive_pr, "/$obsid/images/lc/$lc_name/$lc_name", "_interval_$i.png"))
        end

        print("\n\n")
    else
        warn("Intervals not plotted, seem useless")
    end

    return 1
end

function PlotLCs(;todo=1000, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], overwrite=false)
    numaster_path = string(local_utility, "/numaster_df.csv")

    numaster_df = read_numaster(numaster_path)

    queue = @from i in numaster_df begin
        @where i.LCData != "none"
        @select [i.obsid, string.("$local_archive_pr/", i.obsid, "/products/lc/", split(i.LCData), ".fits")]
        @collect
    end

    i = 1

    for row in queue
        obsid = row[1]
        for path in row[2]
            i += plot_lightcurve(path; obsid=obsid, local_archive_pr=ENV["NU_ARCHIVE_PR"], overwrite=overwrite)

            if i > todo
                return
            end
        end
    end
end
