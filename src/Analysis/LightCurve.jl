struct Lc_fft
    obsid::String
    gti_freqs::Array{Array{Float64,1},1}
    gti_pwers::Array{Array{Float64,1},1}
    gti_freqs_zp::Array{Array{Float64,1},1}
    gti_pwers_zp::Array{Array{Float64,1},1}
    pwers_zp_avg::Array{Float64,1}
    conv::Array{Float64,1}
    bin::Number
    interesting_flag_auto::Bool
end

struct Lc_periodogram
    obsid::String
    gti_freqs::Array{Array{Float64,1},1}
    gti_pwers::Array{Array{Float64,1},1}
    freqs::Array{Float64,1}
    pwers::Array{Float64,1}
    freqs_welch::Array{Float64,1}
    pwers_welch::Array{Float64,1}
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

    min_freq_idx = findfirst(lc_gti_fft_freqs_zp[1] .> 2e-3)
    fft_conv_std = std(lc_fft_conv[min_freq_idx:end])

    interesting_flag_auto = false
    if maximum(lc_fft_conv[min_freq_idx:end]) > mean(lc_fft_conv[min_freq_idx:end])+(fft_conv_std*2)
        interesting_flag_auto = true
    end

    return lc_gti_fft_freqs, lc_gti_fft_pwers, lc_gti_fft_freqs_zp, lc_gti_fft_pwers_zp, lc_fft_pwers_zp_avg, lc_fft_conv, interesting_flag_auto
end

function evt_fft(binned_evt::NuSTAR.Binned_event)
    evt_counts = binned_evt.counts
    evt_time_edges = binned_evt.time_edges
    gtis = binned_evt.gtis

    lc_gti_fft_freqs, lc_gti_fft_pwers, lc_gti_fft_freqs_zp, lc_gti_fft_pwers_zp, lc_fft_pwers_zp_avg, lc_fft_conv, interesting_flag_auto = evt_fft(evt_counts, evt_time_edges, gtis)

    return Lc_fft(binned_evt.obsid, lc_gti_fft_freqs, lc_gti_fft_pwers, lc_gti_fft_freqs_zp, lc_gti_fft_pwers_zp, lc_fft_pwers_zp_avg, lc_fft_conv, binned_evt.bin, interesting_flag_auto)
end

function evt_periodogram(evt_counts, evt_time_edges, gtis)
    interval_count = size(gtis, 1)
    lc_bins = evt_time_edges[2] - evt_time_edges[1]

    if lc_bins < 0.5
        warn("Periodogram works best at low frequencies, recommend lc_bins <= 0.5")
    end

    lc_gti_nextpow2 = nextfastfft(maximum(length.(gtis)))

    # Perfrom Lomb-Scargle
    lc_gti_periodogram = Array{DSP.Periodograms.Periodogram{Float64,DSP.Util.Frequencies},1}(interval_count)
    lc_gti_periodogram_zp = Array{DSP.Periodograms.Periodogram{Float64,DSP.Util.Frequencies},1}(interval_count)
    for (i, gti) in enumerate(gtis)
        zero_padding = zeros(lc_gti_nextpow2 - length(gti)+1)

        lc_gti_periodogram[i] = periodogram(evt_counts[gti].-mean(evt_counts[gti]); fs=1/lc_bins)
        lc_gti_periodogram_zp[i] = periodogram(evt_counts[gti].-mean(evt_counts[gti]); fs=1/lc_bins)
    end

    lc_gti_periodogram_freqs = DSP.freq.(lc_gti_periodogram)
    lc_gti_periodogram_pwers = DSP.power.(lc_gti_periodogram)

    lc_periodogram = periodogram(evt_counts[evt_counts.!=0].-mean(evt_counts[evt_counts.!=0]); fs=1/lc_bins)
    lc_periodogram_pwers = DSP.power(lc_periodogram)
    lc_periodogram_freqs = DSP.freq(lc_periodogram)

    lc_periodogram_welch = welch_pgram(evt_counts[evt_counts.!=0].-mean(evt_counts[evt_counts.!=0]); fs=1/lc_bins)
    lc_periodogram_pwers_welch = DSP.power(lc_periodogram_welch)
    lc_periodogram_freqs_welch = DSP.freq(lc_periodogram_welch)

    return lc_gti_periodogram_freqs, lc_gti_periodogram_pwers, lc_periodogram_freqs, lc_periodogram_pwers, lc_periodogram_freqs_welch, lc_periodogram_pwers_welch
end

function evt_periodogram(binned_evt::NuSTAR.Binned_event)
    evt_counts = binned_evt.counts
    evt_time_edges = binned_evt.time_edges
    gtis = binned_evt.gtis

    lc_gti_periodogram_freqs, lc_gti_periodogram_pwers, lc_periodogram_freqs, lc_periodogram_pwers, lc_periodogram_freqs_welch, lc_periodogram_pwers_welch = evt_periodogram(evt_counts, evt_time_edges, gtis)

    return Lc_periodogram(binned_evt.obsid, lc_gti_periodogram_freqs, lc_gti_periodogram_pwers, lc_periodogram_freqs, lc_periodogram_pwers, lc_periodogram_freqs_welch, lc_periodogram_pwers_welch, binned_evt.bin)
end

function evt_stft(evt_counts, lc_bins, interval_time_end, stft_bins=512)
    stft_bins > size(evt_counts, 1) ? stft_bins = prevpow2(size(evt_counts, 1)) : ""
    stft_pwers  = abs.(DSP.stft(evt_counts.-mean(evt_counts), stft_bins; fs=1/lc_bins)).^2
    stft_time = linspace(0, interval_time_end, size(stft_pwers, 2))
    stft_freq = linspace(0, 0.5*(1/lc_bins), size(stft_pwers, 1))

    return stft_pwers, stft_time, stft_freq
end

function evt_stft(binned_evt::NuSTAR.Binned_event, stft_bins=1024, gti_counts_only=true)
    if gti_counts_only
        evt_counts = binned_evt.counts[binned_evt.counts.!=0]
        interval_time_end = sum(length.(binned_evt.gtis))
    else
        evt_counts = binned_evt.counts
        interval_time_end = maximum(binned_evt.time_edges)
    end
    lc_bins = binned_evt.bin

    stft_pwers, stft_time, stft_freq = evt_stft(evt_counts, lc_bins, interval_time_end, stft_bins)

    return Lc_stft(binned_evt.obsid, stft_pwers, stft_time, stft_freq, binned_evt.bin)
end

function generate_all_binned(unbinned_evt::Unbinned_event, bin::Number)
    lc = NuSTAR.bin_evts_lc(unbinned_evt, bin); print(".")
    lc_fft = NuSTAR.evt_fft(lc); print(".")
    lc_stft = NuSTAR.evt_stft(lc); print(".")
    lc_periodogram = NuSTAR.evt_periodogram(lc); print(".")

    return lc, lc_fft, lc_stft, lc_periodogram
end

function generate_standard_lc_files(path_fits_lc, path_evt_unbinned, path_lc_dir; overwrite=false)
    if !isfile(path_evt_unbinned) || overwrite
        unbinned_evt = extract_evts(path_fits_lc; gti_width_min=128)
        save_evt(path_evt_unbinned, unbinned_evt=unbinned_evt)
    else
        unbinned_evt = read_evt(path_evt_unbinned)
    end

    if !isfile(string(path_lc_dir, "lc_0.jld2")) || overwrite
        print("lc_0")
        lc_ub = NuSTAR.bin_evts_lc(unbinned_evt, 2e-3); print(".")
        lc_ub_fft = NuSTAR.evt_fft(lc_ub); print(".")
        save_evt(string(path_lc_dir, "lc_0.jld2"), lc=lc_ub, fft=lc_ub_fft); print(". ")
    end

    if !isfile(string(path_lc_dir, "lc_05.jld2")) || overwrite
        print("lc_05")
        lc_05, lc_05_fft, lc_05_stft, lc_05_periodogram = generate_all_binned(unbinned_evt, 0.5)
        save_evt(string(path_lc_dir, "lc_05.jld2"), lc=lc_05, periodogram=lc_05_periodogram, stft=lc_05_stft, fft=lc_05_fft); print(". ")
    end

    if !isfile(string(path_lc_dir, "lc_1.jld2")) || overwrite
        print("lc_1")
        lc_1, lc_1_fft, lc_1_stft, lc_1_periodogram = generate_all_binned(unbinned_evt, 1)
        save_evt(string(path_lc_dir, "lc_1.jld2"), lc=lc_1, periodogram=lc_1_periodogram, stft=lc_1_stft, fft=lc_1_fft); print(". ")
    end

    if !isfile(string(path_lc_dir, "lc_2.jld2")) || overwrite
        print("lc_2")
        lc_2, lc_2_fft, lc_2_stft, lc_2_periodogram = generate_all_binned(unbinned_evt, 2)
        save_evt(string(path_lc_dir, "lc_2.jld2"), lc=lc_2, periodogram=lc_2_periodogram, stft=lc_2_stft, fft=lc_2_fft); print(". ")
    end

    print("\n")
end

function generate_standard_lc_files(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"], instrument="auto", overwrite=false)
    if instrument=="auto"
        instrument_list = ["AB"; "A"; "B"]
        instrument_path = string.(local_archive_pr, obsid, "/products/event/evt_", instrument_list, ".fits")
        instrument_idx = findfirst(isfile.(instrument_path))

        if instrument_idx == 0
            error("Event file not found automatically, ensure one of $(join(basename.(instrument_path), ", ")) is present in $(dirname(instrument_path[1]))")
        end

        instrument = instrument_list[instrument_idx]
    end

    path_fits_lc = string(local_archive_pr, obsid, "/products/event/evt_$instrument.fits")

    if !isfile(path_fits_lc)
        error("Event file not found at $path_fits_lc")
    end

    info("$path_fits_lc loaded")

    path_evt_unbinned = string(local_archive_pr, obsid, "/products/event/evt_$instrument.jld2")

    path_lc_dir = string(local_archive_pr, obsid, "/products/lc/")

    generate_standard_lc_files(path_fits_lc, path_evt_unbinned, path_lc_dir; overwrite=overwrite)
end

function std_lc_files(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"], instrument="auto", overwrite=false)
    generate_standard_lc_files(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"], instrument="auto", overwrite=false)
end

function generate_standard_lc_files_batch(;batch_size=10000, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
    numaster_df=read_numaster(numaster_path)

    queue = @from i in numaster_df begin
        @where i.EVT != "NA"
        @select i.obsid
        @collect
    end

    i = 0

    for obsid in queue
        generate_standard_lc_files(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"], instrument="auto", overwrite=overwrite)
    end
end

function std_lc_files_batch(;batch_size=10000, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
    generate_standard_lc_files_batch(;batch_size=10000, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
end
