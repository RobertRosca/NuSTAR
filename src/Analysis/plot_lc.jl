function plot_binned_lc(binned_lc::Binned_event)
    plot(binned_lc.time_edges, binned_lc.counts, xlab="Time [s]", ylab="Counts [per s]", lab="Count", title="$(binned_lc.obsid) - $(binned_lc.bin)s $(binned_lc.typeof)")
    vline!(minimum.(binned_lc.gtis), color=:green, lab="GTI Start")
    vline!(maximum.(binned_lc.gtis), color=:red, lab="GTI Stop")
end

function plot_binned_fft(lc_fft::Lc_fft; title="Full FFT", logx=true, logy=true, nu=false, denoise=false, hz_min=0.001, hz_max=0)
    min_idx = findfirst(lc_fft.gti_freqs_zp[1].>=hz_min)
    min_idx < 2 ? min_idx=2 : min_idx=min_idx

    max_idx = findfirst(lc_fft.gti_freqs_zp[1].>=hz_max)
    max_idx < 2 ? max_idx=length(lc_fft.conv) : max_idx=max_idx

    if denoise
        np2 = zeros(nextpow2(length(lc_fft.conv))-length(lc_fft.conv))
        denoised = abs.(Wavelets.denoise([lc_fft.conv; np2])[1:length(lc_fft.conv)])
        plot(lc_fft.gti_freqs_zp[1][min_idx:max_idx], lc_fft.conv[min_idx:max_idx], lab="", title=title)
        plot!(lc_fft.gti_freqs_zp[1][min_idx:max_idx], denoised[min_idx:max_idx], lab="", title=title, alpha=0.5)
    else
        plot(lc_fft.gti_freqs_zp[1][min_idx:max_idx], lc_fft.conv[min_idx:max_idx], lab="", title=title)
    end

    logx ? xaxis!("Freq [Hz - log10]", :log10) : xaxis!("Freq [Hz]")
    logy ? yaxis!("Power [log10]", :log10) : yaxis!("Power")
end

function plot_binned_fft_tiled(lc_fft::Lc_fft)
    nyquist = 1/(2*lc_fft.bin)

    nyquist > 1e2 ? c_hz_min=1e1 : c_hz_min=1e0
    nyquist > 1e2 ? c_hz_max=1e1 : c_hz_max=0

    a1 = plot_binned_fft(lc_fft; logx=false, logy=false, hz_min=2e-3, hz_max=c_hz_max, title="FFT 0 to $c_hz_max Hz")
    a2 = plot_binned_fft(lc_fft; logx=false, logy=false, hz_min=c_hz_min, hz_max=0, title="FFT $c_hz_max Hz+")
    b = plot_binned_fft(lc_fft; logx=true, logy=true, hz_min=2e-3, hz_max=c_hz_max, denoise=true, title="log-log")
    c = plot_binned_fft(lc_fft; logx=true, logy=true, hz_min=c_hz_min, hz_max=0, denoise=true, title="log-log")
    d = plot_binned_fft(lc_fft; logx=true, logy=false, hz_min=2e-3, hz_max=c_hz_max, denoise=true, title="semi-log")
    e = plot_binned_fft(lc_fft; logx=true, logy=false, hz_min=c_hz_min, hz_max=0, denoise=true, title="semi-log")

    ly = @layout [ [a1{0.5w} a2{0.5w}]; [b{0.5w} c{0.5w}];  [d{0.5w} e{0.5w}] ]

    plot(layout=ly, a1, a2, b, c, d, e)
end

function plot_binned_stft(lc_stft::Lc_stft; hz_min=2e-3, norm_type="pow2db")
    min_idx = findfirst(lc_stft.freq.>=hz_min)

    if norm_type=="pow2db"
        pwers_normed = pow2db.(abs.(lc_stft.pwers)'.^2)
    elseif norm_type=="nu"
        pwers_normed = abs.(lc_stft.pwers.*lc_stft.freq)'.^2
    elseif norm_type=="harsh_ind"
        pwers_normed = abs.(lc_stft.pwers)'.^2
        min_idx = min_idx*2
    else
        pwers_normed = abs.(lc_stft.pwers)'.^2
        norm_type = "no scaling"
    end

    heatmap(lc_stft.freq[min_idx:end], lc_stft.time, pwers_normed[:, min_idx:end], xlab="Frequency [Hz]", ylab="Time [s]", legend=false, xticks=linspace(0, 0.5*(1/(lc_stft.bin)), 11), title="STFT - binned $(lc_stft.bin)s - $norm_type")
end

function plot_binned_periodogram(lc_periodogram::Lc_periodogram; hz_min=2e-3, title="Periodogram - binned $(lc_periodogram.bin)s", denoise=true)
    min_idx = findfirst(lc_periodogram.freqs.>=hz_min)
    min_idx_ylim = findfirst(lc_periodogram.freqs.>=0.1)

    min_ylim = maximum(lc_periodogram.pwers[min_idx_ylim:end]) + std(lc_periodogram.pwers[min_idx:end])

    if denoise
        np2 = zeros(nextpow2(length(lc_periodogram.pwers))-length(lc_periodogram.pwers))
        denoised = abs.(Wavelets.denoise([lc_periodogram.pwers; np2])[1:length(lc_periodogram.pwers)])
        plot(lc_periodogram.freqs[min_idx:end], lc_periodogram.pwers[min_idx:end], xlab="Frequency [Hz]", ylab="Power", lab="", title=title)
        plot!(lc_periodogram.freqs[min_idx:end], denoised[min_idx:end], xlab="Frequency [Hz]", ylab="Power", lab="", title=title, alpha=0.5, color=:red)
        ylims!(0, min_ylim)
    else
        plot(lc_periodogram.freqs[min_idx:end], lc_periodogram.pwers[min_idx:end], xlab="Frequency [Hz]", ylab="Power", lab="", title=title)
        ylims!(0, min_ylim)
    end
end

function plot_overview(binned_lc_1::Binned_event, lc_ub_fft::Lc_fft, lc_01_stft::Lc_stft, lc_1_periodogram::Lc_periodogram, lc_2_periodogram::Lc_periodogram; plot_width=1200, plot_height=300)
    plt_binned_lc = NuSTAR.plot_binned_lc(binned_lc_1)

    plt_binned_fft_tiled = NuSTAR.plot_binned_fft_tiled(lc_ub_fft)

    plt_binned_stft = NuSTAR.plot_binned_stft(lc_01_stft)

    plt_binned_periodogram = NuSTAR.plot_binned_periodogram(lc_1_periodogram)

    plt_binned_periodogram2 = NuSTAR.plot_binned_periodogram(lc_2_periodogram)

    plot(plt_binned_lc, plt_binned_fft_tiled, plt_binned_stft, plt_binned_periodogram, plt_binned_periodogram2, layout=grid(5, 1, heights=[1/9, 4/9, 2/9, 1/9, 1/9]), size=(plot_width, plot_height*5))
end

function plot_overview(unbinned_evt::Unbinned_event; plot_width=1200, plot_height=300)
    binned_lc_1 = NuSTAR.bin_evts_lc(1, unbinned_evt)

    lc_ub_fft = NuSTAR.evt_fft(NuSTAR.bin_evts_lc(2e-3, unbinned_evt))

    lc_01_stft = NuSTAR.evt_stft(binned_lc_01)

    lc_1_periodogram = NuSTAR.evt_periodogram(binned_lc_1)

    plot_overview(binned_lc_1, lc_ub_fft, lc_01_stft, lc_1_periodogram; plot_width=plot_width, plot_height=plot_height)
end

function plot_overview(obsid::String; plot_width=1200, plot_height=300, local_archive_pr=ENV["NU_ARCHIVE_PR"])

    path_lc_dir = string(local_archive_pr, obsid, "/products/lc/")

    binned_lc_1 = read_evt(string(path_lc_dir, "lc_1.jld2"), "lc")
    lc_ub_fft = read_evt(string(path_lc_dir, "lc_0.jld2"), "fft")
    lc_01_stft = read_evt(string(path_lc_dir, "lc_01.jld2"), "stft")
    lc_1_periodogram = read_evt(string(path_lc_dir, "lc_1.jld2"), "periodogram")
    lc_2_periodogram = read_evt(string(path_lc_dir, "lc_2.jld2"), "periodogram")

    plt_overview = plot_overview(binned_lc_1, lc_ub_fft, lc_01_stft, lc_1_periodogram, lc_2_periodogram; plot_width=1200, plot_height=300)

    savefig(plt_overview, string(path_lc_dir, "overview.png"))
end
