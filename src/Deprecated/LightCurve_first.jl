function read_fits_lc(filepath)
    file = FITS(filepath)

    rate = read(file[2], "RATE")
    time = read(file[2], "TIME")
    error = read(file[2], "ERROR")

    lc_data = DataFrame(Rate=rate, Time=time, Error=error)

    return lc_data
end    

function lc_fft_save(fft_data_filepath,
        lc_gti_rate, lc_gti_time, lc_gti_fft_pwers, lc_gti_fft_freqs, lc_gti_fft_pwers_zp, lc_gti_fft_freqs_zp, lc_gti_lomb_pwers, lc_gti_lomb_freqs, lc_gti_fft_pwers_zp_avg, lc_gti_fft_cov)
    jldopen(fft_data_filepath, "w") do file
        file["lc_gti_rate"] = lc_gti_rate
        file["lc_gti_time"] = lc_gti_time
        file["lc_gti_fft_pwers"] = lc_gti_fft_pwers
        file["lc_gti_fft_freqs"] = lc_gti_fft_freqs
        file["lc_gti_fft_pwers_zp"] = lc_gti_fft_pwers_zp
        file["lc_gti_fft_freqs_zp"] = lc_gti_fft_freqs_zp
        file["lc_gti_lomb_pwers"] = lc_gti_lomb_pwers
        file["lc_gti_lomb_freqs"] = lc_gti_lomb_freqs
        file["lc_gti_fft_pwers_zp_avg"] = lc_gti_fft_pwers_zp_avg
        file["lc_gti_fft_cov"] = lc_gti_fft_cov
    end
end

function lc_fft_read(fft_data_filepath)
    lc_gti_rate = load(fft_data_filepath, "lc_gti_rate")
    lc_gti_time = load(fft_data_filepath, "lc_gti_time")
    lc_gti_fft_pwers = load(fft_data_filepath, "lc_gti_fft_pwers")
    lc_gti_fft_freqs = load(fft_data_filepath, "lc_gti_fft_freqs")
    lc_gti_fft_pwers_zp = load(fft_data_filepath, "lc_gti_fft_pwers_zp")
    lc_gti_fft_freqs_zp = load(fft_data_filepath, "lc_gti_fft_freqs_zp")
    lc_gti_lomb_pwers = load(fft_data_filepath, "lc_gti_lomb_pwers")
    lc_gti_lomb_freqs = load(fft_data_filepath, "lc_gti_lomb_freqs")
    lc_gti_fft_pwers_zp_avg = load(fft_data_filepath, "lc_gti_fft_pwers_zp_avg")
    lc_gti_fft_cov = load(fft_data_filepath, "lc_gti_fft_cov")

    return lc_gti_rate, lc_gti_time, lc_gti_fft_pwers, lc_gti_fft_freqs, lc_gti_fft_pwers_zp, lc_gti_fft_freqs_zp, lc_gti_lomb_pwers, lc_gti_lomb_freqs, lc_gti_fft_pwers_zp_avg, lc_gti_fft_cov
end

function find_lightcurve_intervals(lc_data, lc_bins, min_interval_width_s)
    interval_time_end   = find(x->x>lc_bins, lc_data[:Time][2:end] .- lc_data[:Time][1:end-1] .- lc_bins)
    interval_time_end   = [interval_time_end; Int(length(lc_data[:Time]))]

    interval_time_start = find(x->x>lc_bins, lc_data[:Time][2:end] .- lc_data[:Time][1:end-1] .- lc_bins) .+ 1
    interval_time_start = [1; interval_time_start]

    interval_widths     = interval_time_end .- interval_time_start

    min_interval_width  = min_interval_width_s/lc_bins

    interval_time_start = interval_time_start[interval_widths .> min_interval_width]
    interval_time_end   = interval_time_end[interval_widths .> min_interval_width]

    interval_count = count(interval_widths .> min_interval_width)
    interval_count_bad = count(interval_widths .< min_interval_width)

    return interval_time_start, interval_time_end, interval_widths, min_interval_width, interval_count, interval_count_bad
end

function lc_fft_lomb(lc_data_counts, lc_data_times, lc_bins, interval_count, interval_time_start, interval_time_end, interval_widths)
    # Split data into GTIs
    lc_gti_rate = Array{Array{Float64,1},1}(interval_count)
    lc_gti_time = Array{Array{Float64,1},1}(interval_count)
    for gti = 1:interval_count
        lc_gti_rate[gti] = lc_data_counts[interval_time_start[gti]:interval_time_end[gti]]
        lc_gti_time[gti] = lc_data_times[interval_time_start[gti]:interval_time_end[gti]]
    end

    lc_gti_nextpow2 = nextfastfft(maximum(interval_widths)) # Used for zero-padding in padded FFT

    # Perfrom FFT on GTI, also use padding
    lc_gti_fft_pwers = Array{Array{Float64,1},1}(interval_count)
    lc_gti_fft_freqs = Array{Array{Float64,1},1}(interval_count)
    lc_gti_fft_pwers_zp = Array{Array{Float64,1},1}(interval_count)
    lc_gti_fft_freqs_zp = Array{Array{Float64,1},1}(interval_count)
    for gti = 1:interval_count
        zero_padding = zeros(lc_gti_nextpow2 - length(lc_gti_rate[gti])+1)

        lc_gti_fft_pwers[gti] = abs.(rfft(lc_gti_rate[gti] .- mean(lc_gti_rate[gti])))
        lc_gti_fft_freqs[gti] = rfftfreq(length(lc_gti_rate[gti]), 1/lc_bins)

        lc_gti_fft_pwers_zp[gti] = abs.(rfft([lc_gti_rate[gti]; zero_padding] .- mean(lc_gti_rate[gti])))
        lc_gti_fft_freqs_zp[gti] = rfftfreq(length([lc_gti_rate[gti]; zero_padding]), 1/lc_bins)
    end

    # Perfrom Lomb-Scargle
    lc_gti_lomb_pwers = Array{Array{Float64,1},1}(interval_count)
    lc_gti_lomb_freqs = Array{Array{Float64,1},1}(interval_count)
    for gti = 1:interval_count
        lc_gti_lomb_freqs[gti], lc_gti_lomb_pwers[gti] = freqpower(lombscargle(lc_gti_time[gti], lc_gti_rate[gti]))
    end

    # Create FFT summed line from padded data
    lc_gti_fft_pwers_zp_avg = mean(lc_gti_fft_pwers_zp)

    # Create FFT conv from padded data
    lc_gti_fft_conv = ones(length(lc_gti_fft_pwers_zp[1]))
    for gti = 1:interval_count
        lc_gti_fft_conv .*= lc_gti_fft_pwers_zp[gti]
    end

    lc_gti_fft_conv = lc_gti_fft_conv.^(1/interval_count)

    return lc_gti_rate, lc_gti_time, lc_gti_fft_pwers, lc_gti_fft_freqs, lc_gti_fft_pwers_zp, lc_gti_fft_freqs_zp, lc_gti_lomb_pwers, lc_gti_lomb_freqs, lc_gti_fft_pwers_zp_avg, lc_gti_fft_conv
end

function plot_lightcurve(filepath; obsid="", local_archive_pr=ENV["NU_ARCHIVE_PR"], min_interval_width_s=100, overwrite_plot=false, overwrite_fft=false, flag_force_plot=false)
    lc_data = NuSTAR.read_fits_lc(filepath)
    lc_name = replace(basename(filepath), ".fits", "");

    obsid=="" ? obsid=split(abspath(string(dirname(filepath), "/..", "/..")), "/")[end-1] : ""

    plt_lc_main_path = string(local_archive_pr, "/$obsid/images/lc/$lc_name/$lc_name", "_full.png")

    fft_data_filepath = string(dirname(filepath), "/", lc_name, "_fft.jld2")

    if isfile(plt_lc_main_path) && isfile(fft_data_filepath) && !overwrite_plot
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

    if isfile(fft_data_filepath) &! overwrite_fft
        info("Reading saved FFT")
        lc_gti_rate, lc_gti_time, lc_gti_fft_pwers, lc_gti_fft_freqs, lc_gti_fft_pwers_zp, lc_gti_fft_freqs_zp, lc_gti_lomb_pwers, lc_gti_lomb_freqs, lc_gti_fft_pwers_zp_avg, lc_gti_fft_cov = lc_fft_read(fft_data_filepath)
    else
        info("Creating FFT file")
        lc_gti_rate, lc_gti_time, lc_gti_fft_pwers, lc_gti_fft_freqs, lc_gti_fft_pwers_zp, lc_gti_fft_freqs_zp, lc_gti_lomb_pwers, lc_gti_lomb_freqs, lc_gti_fft_pwers_zp_avg, lc_gti_fft_cov = lc_fft_lomb(lc_data, lc_bins, interval_count, interval_time_start, interval_time_end, interval_widths)
        lc_fft_save(fft_data_filepath,
                lc_gti_rate, lc_gti_time, lc_gti_fft_pwers, lc_gti_fft_freqs, lc_gti_fft_pwers_zp, lc_gti_fft_freqs_zp, lc_gti_lomb_pwers, lc_gti_lomb_freqs, lc_gti_fft_pwers_zp_avg, lc_gti_fft_cov)
    end

    if maximum(lc_gti_fft_cov[5:end]) > 0.5
        info("*** Significant FFT peak ***")
        flag_plot_intervals = true
    else
        flag_plot_intervals = false
    end

    pgrm   = DSP.periodogram(lc_data[:Rate].-mean(lc_data[:Rate]); fs=1/lc_bins)
    pwrmax = DSP.freq(pgrm)[findmax(DSP.power(pgrm)[3:end])[2]]
    info("Frequency max at $pwrmax Hz\nRecommend binsize $(round(1/(pwrmax*4), 3))")

    plot(lc_data[:Time], lc_data[:Rate], size=(1920, 1080), lab="", title="$obsid - $lc_name - full lc")
    vline!(lc_data[:Time][interval_time_start], color=:green, lab="Start", alpha=0.25)
    plt_lc = vline!(lc_data[:Time][interval_time_end], color=:red, lab="End", alpha=0.25, xlab="Time [s]")

    plot(lc_gti_fft_freqs, lc_gti_fft_pwers, alpha=0.25, lab="",
        ylims=(0, median(maximum.(lc_gti_fft_pwers))+std(maximum.(lc_gti_fft_pwers))))
    plt_ffts = plot!(lc_gti_fft_freqs_zp[1], lc_gti_fft_pwers_zp_avg, color=:black, lab="Mean FFT", xticks=linspace(0, 0.5*(1/lc_bins), 11))

    plot(lc_gti_fft_freqs_zp[1], normalize(lc_gti_fft_cov), lab="Convoluted FFT [normalized]", color=:red, alpha=0.25)
    annotate!(pwrmax, maximum(normalize(lc_gti_fft_cov)),text("$(round(pwrmax, 3)) Hz", 8, :black, :left))
    plt_ffts_cv = plot!(lc_gti_fft_freqs_zp[1], normalize(lc_gti_fft_cov.*lc_gti_fft_freqs_zp[1]), lab="Convoluted FFT*freq [normalized]", color=:blue, alpha=0.25, xticks=linspace(0, 0.5*(1/lc_bins), 11))

    plot(lc_gti_lomb_freqs, lc_gti_lomb_pwers, alpha=0.5, xlims=(0, 1/(2*lc_bins)), lab="",
        ylims=(0, median(maximum.(lc_gti_lomb_pwers))+std(maximum.(lc_gti_lomb_pwers))))
    plot!(DSP.freq(pgrm), normalize(DSP.power(pgrm)), lab="DSP Periodogram", color=:black)
    plt_lmbs= plot!([-1000], [-1000], lab="Lomb-Scargle of GTIs", color=:white, xticks=linspace(0, 0.5*(1/lc_bins), 11))

    stft = DSP.stft(lc_data[:Rate].-mean(lc_data[:Rate]); fs=1/lc_bins)
    stft_time = linspace(0, interval_time_end[end], size(stft, 2))
    stft_freq = linspace(0, 0.5*(1/lc_bins), size(stft, 1))
    plt_stft = heatmap(stft_freq, stft_time, log.(abs.(stft)'), xlab="Frequency [Hz]", ylab="Time [s]", legend=false, xticks=linspace(0, 0.5*(1/lc_bins), 11))

    lc_combined_plot = plot(plt_lc, plt_ffts, plt_ffts_cv, plt_lmbs, plt_stft, size=(1020, 1080), layout=(5, 1))
    savefig(lc_combined_plot, plt_lc_main_path) # Create "./config/matplotlib/matplotlibrc" with "agg.path.chunksize : 10000" in case of  "Exceeded cell block limit" error


    return

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
            start_idx = round(Int, size(lc_gti_fft_pwers[i],1)*0.005)+1
            plt_intervals_fft[i] = plot(lc_gti_fft_freqs[i], lc_gti_fft_pwers[i], lab="FFT", size=(1280, 720), ylims=(0, maximum(lc_gti_fft_pwers[i][start_idx:end])*1.1))
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

function PlotLCs(;todo=1000, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], min_interval_width_s=100, overwrite_plot=false, overwrite_fft=false, flag_force_plot=false)
    numaster_path = string(local_utility, "/numaster_df.csv")

    numaster_df = read_numaster(numaster_path)

    queue = @from i in numaster_df begin
        @where i.LC != "NA"
        @select [i.obsid, string.("$local_archive_pr/", i.obsid, "/products/lc/", split(i.LC), ".fits")]
        @collect
    end

    i = 1

    for row in queue
        obsid = row[1]
        for path in row[2]
            i += plot_lightcurve(path; obsid=obsid, local_archive_pr=ENV["NU_ARCHIVE_PR"], min_interval_width_s=min_interval_width_s, overwrite_plot=overwrite_plot, overwrite_fft=overwrite_fft, flag_force_plot=flag_force_plot)

            if i > todo
                return
            end
        end
    end
end
