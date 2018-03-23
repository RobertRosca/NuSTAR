function plot_binned_lc(binned_lc::binned_event)
    plot(binned_lc.time_edges, binned_lc.counts, xlab="Time [s]", ylab="Counts [per s]", lab="Count", title="$(binned_lc.obsid) - $(binned_lc.bin)s $(binned_lc.typeof)")
    vline!(minimum.(binned_lc.gtis), color=:green, lab="GTI Start")
    vline!(maximum.(binned_lc.gtis), color=:red, lab="GTI Stop")
end

function plot_binned_fft(lc_fft::lc_fft; title="Full FFT", logx=true, logy=true, nu=false, hz_min=0.001)
    min = findfirst(lc_fft.gti_freqs_zp[1].>=hz_min)
    plot(lc_fft.gti_freqs_zp[1][min:end], lc_fft.conv[min:end], lab="", title=title)
    logx ? xaxis!("Freq [Hz - log10]", :log10) : xaxis!("Freq [Hz - log10]")
    logy ? yaxis!("Power", :log10) : yaxis!("Power [log10]")
end

function plot_binned_fft_tiled(lc_fft::lc_fft)
    a = plot_binned_fft(lc_fft; logx=false, logy=false, hz_min=2e-3)
    b = plot_binned_fft(lc_fft; logx=true, logy=true, hz_min=2e-3, title="FFT log-log")
    c = plot_binned_fft(lc_fft; logx=true, logy=true, hz_min=1e1, title="FFT log-log 10Hz+")

    ly = @layout [ a{1w}; [b{0.5w} c{0.5w}] ]

    plot(layout=ly, a, b, c)
end
