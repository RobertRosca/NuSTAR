### TOOLS
function _freq_limits(freqs, data, lims)

    lo = findfirst(freqs .>= lims[1])
    hi = findfirst(freqs .>= lims[2])-1

    hi in [0, -1]? hi = length(freqs) : ""

    return freqs[lo:hi], data[lo:hi]
end

function _log_formatter(axis_number)
    round(axis_number) % 10 == 0 ? round(axis_number) : ""
end


### LIGHTCURVE
function plot_lc(times, counts, obsid, binsize_sec, gtis;
        title="$(obsid) - $(binsize_sec) s lightcurve")
    plot(times, counts, xlab="Time [s]", ylab="Counts [/s]", lab="Count", title=title)
    vline!([minimum(gtis, 2)], color=:green, lab="GTI Start")
    vline!([maximum(gtis, 2)], color=:red, lab="GTI Stop")
    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
end

function plot_lc(binned_lc::Binned_event; title="")
    if title == ""
        plot_lc(binned_lc.times, binned_lc.counts, binned_lc.obsid, binned_lc.binsize_sec, binned_lc.gtis)
    else
        plot_lc(binned_lc.times, binned_lc.counts, binned_lc.obsid, binned_lc.binsize_sec, binned_lc.gtis;
            title=title)
    end
end

function plot_lc(unbinned::Unbinned_event, binsize_sec::Real; title="")
    binned_lc = bin_lc(unbinned, binsize_sec)

    plot_lc(binned_lc; title=title)
end


### FFT
function plot_pds(lc_pds::Lc_pds; title="Full FFT - Leahy norm.", logx=false, logy=true, hz_min=2*2e-3, hz_max=0)
    freqs  = lc_pds.freqs
    powers = lc_pds.mean_powers

    freqs, powers = _freq_limits(freqs, powers, (hz_min, hz_max))

    plot(freqs, powers, title=title, lab="")

    logx ? xaxis!("Freq [Hz - log10]", :log10) : xaxis!("Freq [Hz]")
    logy ? yaxis!("Power [log10]", :log10) : yaxis!("Power")

    hline!([2], color=:cyan, style=:dash, lab="") # Leahy noise

    yticks!(10.^(1:1000))
    plot!(yformatter = yi->_log_formatter(yi))

    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
end


### SPECTROGRAM
function plot_spectrogram(lc_spectrogram::Lc_spectrogram)
    powers_no_zero_freq = lc_spectrogram.stft_powers[1, :] = NaN

    heatmap(lc_spectrogram.stft_freqs[1:end], lc_spectrogram.stft_time, (pow2db.(abs.(lc_spectrogram.stft_powers)').^2), legend=false)
    plot!(size=(900, 400), title="Easy to Read Spectrogram", xlab="Frequency [Hz]", ylab="Time Inside GTI (gapless) [s]")
    hline!(lc_spectrogram.gti_bounds, color=:cyan, style=:dash)
end
