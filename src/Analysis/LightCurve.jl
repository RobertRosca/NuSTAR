struct Lc_fft
    obsid::String
    gti_freqs::Array{Array{Float64,1},1}
    gti_pwers::Array{Array{Float64,1},1}
    gti_freqs_zp::Array{Array{Float64,1},1}
    gti_pwers_zp::Array{Array{Float64,1},1}
    pwers_zp_avg::Array{Float64,1}
    conv::Array{Float64,1}
    bin::Number
end

struct Lc_periodogram
    obsid::String
    gti_freqs::Array{Array{Float64,1},1}
    gti_pwers::Array{Array{Float64,1},1}
    freqs::Array{Float64,1}
    pwers::Array{Float64,1}
    bin::Number
end

struct Lc_stft
    obsid::String
    pwers::Array{Float64,2}
    time::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    freq::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    bin::Number
end

function evt_fft(evt_counts, evt_time_edges, gtis)
    interval_count = size(gtis, 1)
    lc_bins = evt_time_edges[2] - evt_time_edges[1]

    lc_gti_rate = Array{Array{Float64,1},1}(interval_count)
    lc_gti_time = Array{Array{Float64,1},1}(interval_count)
    for (i, gti) = enumerate(gtis)
        lc_gti_rate[i] = evt_counts[gti]
        lc_gti_time[i] = evt_time_edges[gti]
    end

    lc_gti_nextpow2 = nextfastfft(maximum(length.(gtis))) # Used for zero-padding in padded FFT

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

    # Create FFT summed line from padded data
    lc_fft_pwers_zp_avg = mean(lc_gti_fft_pwers_zp)

    # Create FFT conv from padded data
    lc_fft_conv = ones(length(lc_gti_fft_pwers_zp[1]))
    for gti = 1:interval_count
        lc_fft_conv .*= lc_gti_fft_pwers_zp[gti]
    end

    lc_fft_conv = lc_fft_conv.^(1/interval_count)

    return lc_gti_fft_freqs, lc_gti_fft_pwers, lc_gti_fft_freqs_zp, lc_gti_fft_pwers_zp, lc_fft_pwers_zp_avg, lc_fft_conv
end

function evt_fft(binned_evt::NuSTAR.Binned_event)
    evt_counts = binned_evt.counts
    evt_time_edges = binned_evt.time_edges
    gtis = binned_evt.gtis

    lc_gti_fft_freqs, lc_gti_fft_pwers, lc_gti_fft_freqs_zp, lc_gti_fft_pwers_zp, lc_fft_pwers_zp_avg, lc_fft_conv = evt_fft(evt_counts, evt_time_edges, gtis)

    return Lc_fft(binned_evt.obsid, lc_gti_fft_freqs, lc_gti_fft_pwers, lc_gti_fft_freqs_zp, lc_gti_fft_pwers_zp, lc_fft_pwers_zp_avg, lc_fft_conv, binned_evt.bin)
end

function evt_periodogram(evt_counts, evt_time_edges, gtis)
    interval_count = size(gtis, 1)
    lc_bins = evt_time_edges[2] - evt_time_edges[1]

    if lc_bins < 0.5
        warn("Periodogram works best at low frequencies, recommend lc_bins <= 0.5")
    end

    # Perfrom Lomb-Scargle
    lc_gti_periodogram = Array{DSP.Periodograms.Periodogram{Float64,DSP.Util.Frequencies},1}(interval_count)
    for (i, gti) in enumerate(gtis)
        lc_gti_periodogram[i] = periodogram(evt_counts[gti].-mean(evt_counts[gti]); fs=1/lc_bins)
    end

    lc_gti_periodogram_freqs = DSP.freq.(lc_gti_periodogram)
    lc_gti_periodogram_pwers = DSP.power.(lc_gti_periodogram)

    lc_periodogram = periodogram(evt_counts.-mean(evt_counts); fs=1/lc_bins)
    lc_periodogram_freqs = DSP.freq(lc_periodogram)
    lc_periodogram_pwers = DSP.power(lc_periodogram)

    return lc_gti_periodogram_freqs, lc_gti_periodogram_pwers, lc_periodogram_freqs, lc_periodogram_pwers
end

function evt_periodogram(binned_evt::NuSTAR.Binned_event)
    evt_counts = binned_evt.counts
    evt_time_edges = binned_evt.time_edges
    gtis = binned_evt.gtis

    lc_gti_periodogram_freqs, lc_gti_periodogram_pwers, lc_periodogram_freqs, lc_periodogram_pwers = evt_periodogram(evt_counts, evt_time_edges, gtis)

    return Lc_periodogram(binned_evt.obsid, lc_gti_periodogram_freqs, lc_gti_periodogram_pwers, lc_periodogram_freqs, lc_periodogram_pwers, binned_evt.bin)
end

function evt_stft(evt_counts, lc_bins, interval_time_end, stft_bins=512)
    stft_pwers  = abs.(DSP.stft(evt_counts.-mean(evt_counts), stft_bins; fs=1/lc_bins)).^2
    stft_time = linspace(0, interval_time_end, size(stft_pwers, 2))
    stft_freq = linspace(0, 0.5*(1/lc_bins), size(stft_pwers, 1))

    return stft_pwers, stft_time, stft_freq
end

function evt_stft(binned_evt::NuSTAR.Binned_event, stft_bins=512)
    evt_counts = binned_evt.counts
    lc_bins = binned_evt.bin
    interval_time_end = maximum(binned_evt.time_edges)

    stft_pwers, stft_time, stft_freq = evt_stft(evt_counts, lc_bins, interval_time_end, stft_bins)

    return Lc_stft(binned_evt.obsid, stft_pwers, stft_time, stft_freq, binned_evt.bin)
end

function generate_standard_lc_files(path_fits_lc, path_evt_unbinned, path_lc_dir; overwrite=false)
    if isfile(path_evt_unbinned) && !overwrite
        unbinned_evt = read_evt(path_evt_unbinned)
    else
        unbinned_evt = extract_evts(path_fits_lc; gti_width_min=128)
        save_evt(path_evt_unbinned, unbinned_evt=unbinned_evt)
    end

    if isfile(string(path_lc_dir, "lc_0.jld2")) && !overwrite
        info("lc_0 file exists, skipping generation")
    else
        lc_ub = NuSTAR.bin_evts_lc(2e-3, unbinned_evt)
        lc_ub_fft = NuSTAR.evt_fft(lc_ub)
        save_evt(string(path_lc_dir, "lc_0.jld2"), lc=lc_ub, fft=lc_ub_fft)
    end

    if isfile(string(path_lc_dir, "lc_01.jld2")) && !overwrite
        info("lc_01 file exists, skipping generation")
    else
        lc_01 = NuSTAR.bin_evts_lc(0.1, unbinned_evt)
        lc_01_stft = NuSTAR.evt_stft(lc_01)
        save_evt(string(path_lc_dir, "lc_01.jld2"), lc=lc_01, stft=lc_01_stft)
    end

    if isfile(string(path_lc_dir, "lc_1.jld2")) && !overwrite
        info("lc_1 file exists, skipping generation")
    else
        lc_1 = NuSTAR.bin_evts_lc(1, unbinned_evt)
        lc_1_periodogram = NuSTAR.evt_periodogram(lc_1)
        save_evt(string(path_lc_dir, "lc_1.jld2"), lc=lc_1, periodogram=lc_1_periodogram)
    end

    if isfile(string(path_lc_dir, "lc_2.jld2")) && !overwrite
        info("lc_2 file exists, skipping generation")
    else
        lc_2 = NuSTAR.bin_evts_lc(2, unbinned_evt)
        lc_2_periodogram = NuSTAR.evt_periodogram(lc_2)
        save_evt(string(path_lc_dir, "lc_2.jld2"), lc=lc_2, periodogram=lc_2_periodogram)
    end
end

function generate_standard_lc_files(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"], instrument="A", overwrite=false)
    path_fits_lc = string(local_archive_pr, obsid, "/products/event/evt_$instrument.fits")

    if !isfile(path_fits_lc); error("$path_fits_lc not found"); end

    path_evt_unbinned = string(local_archive_pr, obsid, "/products/event/evt_$instrument.jld2")

    path_lc_dir = string(local_archive_pr, obsid, "/products/lc/")

    generate_standard_lc_files(path_fits_lc, path_evt_unbinned, path_lc_dir; overwrite=overwrite)
end
