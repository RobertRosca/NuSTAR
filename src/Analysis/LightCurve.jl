struct lc_fft
    gti_freqs::Array{Array{Float64,1},1}
    gti_pwers::Array{Array{Float64,1},1}
    gti_freqs_zp::Array{Array{Float64,1},1}
    gti_pwers_zp::Array{Array{Float64,1},1}
    pwers_zp_avg::Array{Float64,1}
    conv::Array{Float64,1}
end

struct lc_periodogram
    gti_freqs::Array{Array{Float64,1},1}
    gti_pwers::Array{Array{Float64,1},1}
    freqs::Array{Float64,1}
    pwers::Array{Float64,1}
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

function evt_fft(binned_evt::NuSTAR.binned_event)
    evt_counts = binned_evt.counts
    evt_time_edges = binned_evt.time_edges
    gtis = binned_evt.gtis

    return lc_fft(evt_fft(evt_counts, evt_time_edges, gtis))
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

    lc_gti_periodogram_pwers = freq.(lc_gti_periodogram)
    lc_gti_periodogram_freqs = power.(lc_gti_periodogram)

    lc_periodogram = periodogram(evt_counts.-mean(evt_counts); fs=1/lc_bins)
    lc_periodogram_freqs = freq(lc_periodogram)
    lc_periodogram_pwers = power(lc_periodogram)

    return lc_gti_periodogram_freqs, lc_gti_periodogram_pwers, lc_periodogram_freqs, lc_periodogram_pwers
end

function evt_periodogram(binned_evt::NuSTAR.binned_event)
    evt_counts = binned_evt.counts
    evt_time_edges = binned_evt.time_edges
    gtis = binned_evt.gtis

    return evt_periodogram(evt_counts, evt_time_edges, gtis)
end
