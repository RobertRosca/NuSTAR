using Measures

function plot_lc(binned_lc::Binned_event)
    plot(binned_lc.time_edges, binned_lc.counts, xlab="Time [s]", ylab="Counts [per s]", lab="Count", title="$(binned_lc.obsid) - $(binned_lc.bin)s $(binned_lc.typeof)")
    vline!(binned_lc.time_edges[minimum.(binned_lc.gtis)], color=:green, lab="GTI Start")
    vline!(binned_lc.time_edges[maximum.(binned_lc.gtis)], color=:red, lab="GTI Stop")
end

function plot_fft(lc_fft::Lc_fft; title="Full FFT", logx=true, logy=true, nu=false, denoise=false, hz_min=2*2e-3, hz_max=0)
    min_idx = findfirst(lc_fft.gti_freqs_zp[1].>=hz_min)
    min_idx < 2 ? min_idx=2 : min_idx=min_idx

    max_idx = findfirst(lc_fft.gti_freqs_zp[1].>=hz_max)
    max_idx < 2 ? max_idx=length(lc_fft.conv) : max_idx=max_idx

    if size(lc_fft.conv, 1) > 1e6 && denoise
        warn("Denoise disabled due to large FFT data")
        denoise = false
    end

    if logy
        conv_logged = log10.(lc_fft.conv)
        conv_not_finite = .!isfinite.(conv_logged)
        lc_fft_conv = lc_fft.conv
        lc_fft_conv[conv_not_finite] = NaN
    else
        lc_fft_conv = lc_fft.conv
    end

    plot(lc_fft.gti_freqs_zp[1][min_idx:max_idx], lc_fft_conv[min_idx:max_idx], lab="", title=title)

    if denoise
        np2 = zeros(nextpow2(length(lc_fft.conv))-length(lc_fft.conv))
        denoised = abs.(Wavelets.denoise([lc_fft_conv; np2])[1:length(lc_fft.conv)])
        if logy; denoised[.!isfinite.(log10.(denoised))] = NaN; end
        plot!(lc_fft.gti_freqs_zp[1][min_idx:max_idx], denoised[min_idx:max_idx], lab="", title=title, color=:red, alpha=0.5)
    end

    logx ? xaxis!("Freq [Hz - log10]", :log10) : xaxis!("Freq [Hz]")
    logy ? yaxis!("Power [log10]", :log10) : yaxis!("Power")

    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
end

function plot_fft_tiled(lc_fft::Lc_fft)
    nyquist = 1/(2*lc_fft.bin)

    nyquist > 1e2 ? c_hz_min=1e1 : c_hz_min=1e0
    nyquist > 1e2 ? c_hz_max=1e1 : c_hz_max=0

    a1 = plot_fft(lc_fft; logx=false, logy=false, hz_min=2e-3, hz_max=c_hz_max, denoise=true, title="FFT 0 to $c_hz_max Hz")
    a2 = plot_fft(lc_fft; logx=false, logy=false, hz_min=c_hz_min, hz_max=0, denoise=true, title="FFT $c_hz_max Hz+")
    b = plot_fft(lc_fft; logx=true, logy=true, hz_min=2e-3, hz_max=c_hz_max, denoise=true, title="log-log")
    c = plot_fft(lc_fft; logx=true, logy=true, hz_min=c_hz_min, hz_max=0, denoise=true, title="log-log")
    d = plot_fft(lc_fft; logx=true, logy=false, hz_min=2e-3, hz_max=c_hz_max, denoise=true, title="semi-log")
    e = plot_fft(lc_fft; logx=true, logy=false, hz_min=c_hz_min, hz_max=0, denoise=true, title="semi-log")

    ly = @layout [ [a1{0.5w} a2{0.5w}]; [b{0.5w} c{0.5w}];  [d{0.5w} e{0.5w}] ]

    plot(layout=ly, a1, a2, b, c, d, e)
    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
end

function plot_stft(lc_stft::Lc_stft; hz_min=2*2e-3, norm_type="pow2db2", title="STFT - binned $(lc_stft.bin)s - $norm_type - GTI only")
    min_idx = findfirst(lc_stft.freq.>=hz_min)

    if norm_type=="pow2db"
        pwers_normed = pow2db.(abs.(lc_stft.pwers)')
    elseif norm_type=="nu"
        pwers_normed = abs.(lc_stft.pwers.*lc_stft.freq)'
    elseif norm_type=="harsh_ind"
        pwers_normed = abs.(lc_stft.pwers)'
        min_idx = min_idx*2
    elseif norm_type=="pow2db2"
        pwers_normed = pow2db.(abs.(lc_stft.pwers)').^2
    else
        pwers_normed = abs.(lc_stft.pwers)'
        norm_type = "no scaling"
    end

    heatmap(lc_stft.freq[min_idx:end], lc_stft.time, pwers_normed[:, min_idx:end], xlab="Freq [Hz]", ylab="Time [s]", legend=false, xticks=linspace(0, 0.5*(1/(lc_stft.bin)), 11), title=title)
    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
end

function plot_periodogram(lc_periodogram::Lc_periodogram; hz_min=2e-3, title="Periodogram - binned $(lc_periodogram.bin)s", denoise=false, welch=true, logx=false, logy=false)
    min_idx = findfirst(lc_periodogram.freqs.>=hz_min)
    min_idx_welch = findfirst(lc_periodogram.freqs_welch.>=hz_min)

    if logy
        lc_periodogram.pwers[lc_periodogram.pwers .<= 1] = NaN
    end

    if denoise
        np2 = zeros(nextpow2(length(lc_periodogram.pwers))-length(lc_periodogram.pwers))
        denoised = abs.(Wavelets.denoise([lc_periodogram.pwers; np2])[1:length(lc_periodogram.pwers)])
        plot(lc_periodogram.freqs[min_idx:end], lc_periodogram.pwers[min_idx:end], lab="", title=title)
        plot!(lc_periodogram.freqs[min_idx:end], denoised[min_idx:end], lab="", title=title, alpha=0.5, color=:black)
        #ylims!(2e-3, min_ylim)
    else
        plot(lc_periodogram.freqs[min_idx:end], lc_periodogram.pwers[min_idx:end], lab="", title=title)
        #ylims!(2e-3, min_ylim)
    end

    if welch
        plot!(lc_periodogram.freqs_welch[min_idx_welch:end], lc_periodogram.pwers_welch[min_idx_welch:end], lab="Welch", title=title, color=:black)
    end

    logx ? xaxis!("Freq [Hz - log10]", :log10) : xaxis!("Freq [Hz]")
    logy ? yaxis!("Power [log10]", :log10) : yaxis!("Power")
    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
end

function plot_per_stft_tiled(lc_stft::Lc_stft, lc_periodogram::Lc_periodogram; hz_min=2*2e-3, norm_type="pow2db2", title_stft="STFT - binned $(lc_stft.bin)s - $norm_type - GTI only", title_periodogram="Periodogram - binned $(lc_periodogram.bin)s", denoise=false, welch=true, logx=false, logy=false)

    plt_stft = plot_stft(lc_stft::Lc_stft; hz_min=2*2e-3, norm_type="pow2db2", title="STFT - binned $(lc_stft.bin)s - $norm_type - GTI only")

    plt_periodogram = plot_periodogram(lc_periodogram::Lc_periodogram; hz_min=2e-3, title="Periodogram - binned $(lc_periodogram.bin)s", denoise=false, welch=true, logx=false, logy=false)

    plot(plt_stft, plt_periodogram, layout=(2, 1))
end

function plot_overview(binned_lc_1::Binned_event, lc_ub_fft::Lc_fft, lc_05_stft::Lc_stft, lc_05_periodogram::Lc_periodogram, lc_2_stft::Lc_stft, lc_2_periodogram::Lc_periodogram; plot_width=1200, plot_height=300)
    plt_lc = NuSTAR.plot_lc(binned_lc_1)

    plt_fft_tiled = NuSTAR.plot_fft_tiled(lc_ub_fft)

    plt_per_stft_tiled_05 = plot_per_stft_tiled(lc_05_stft, lc_05_periodogram)

    plt_per_stft_tiled_2 = plot_per_stft_tiled(lc_2_stft, lc_2_periodogram)

    plot(plt_lc, plt_fft_tiled, plt_per_stft_tiled_05, plt_per_stft_tiled_2, layout=grid(4, 1, heights=[1/9, 4/9, 2/9, 2/9]), size=(plot_width, plot_height*(9/2)))
    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
end

function plot_overview(unbinned_evt::Unbinned_event; plot_width=1200, plot_height=300)
    binned_lc_1 = NuSTAR.bin_evts_lc(unbinned_evt, 1)

    lc_ub_fft = NuSTAR.evt_fft(NuSTAR.bin_evts_lc(unbinned_evt, 2e-3))

    lc_1_stft = NuSTAR.evt_stft(binned_lc_01)

    lc_1_periodogram = NuSTAR.evt_periodogram(binned_lc_1)

    plot_overview(binned_lc_1, lc_ub_fft, lc_1_stft, lc_1_periodogram; plot_width=plot_width, plot_height=plot_height)
end

function plot_overview(obsid::String; plot_width=1200, plot_height=300, local_archive_pr=ENV["NU_ARCHIVE_PR"])
    path_lc_dir = string(local_archive_pr, obsid, "/products/lc/")
    path_img_dir = string(local_archive_pr, obsid, "/images/")

    binned_lc_1 = read_evt(string(path_lc_dir, "lc_1.jld2"), "lc")
    lc_ub_fft = read_evt(string(path_lc_dir, "lc_0.jld2"), "fft")
    lc_05_stft = read_evt(string(path_lc_dir, "lc_05.jld2"), "stft")
    lc_05_periodogram = read_evt(string(path_lc_dir, "lc_05.jld2"), "periodogram")
    lc_2_stft = read_evt(string(path_lc_dir, "lc_2.jld2"), "stft")
    lc_2_periodogram = read_evt(string(path_lc_dir, "lc_2.jld2"), "periodogram")

    plt_overview = plot_overview(binned_lc_1, lc_ub_fft, lc_05_stft, lc_05_periodogram, lc_2_stft, lc_2_periodogram; plot_width=plot_width, plot_height=plot_height)

    savefig(plt_overview, string(path_img_dir, "summary.png"))
end

function plot_overview_batch(;batch_size=10000, plot_width=1200, plot_height=300, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
    numaster_df=read_numaster(numaster_path)

    queue = @from i in numaster_df begin
        @where contains(i.LC, "lc_05 lc_0 lc_1 lc_2")
        @select i.obsid
        @collect
    end

    i = 0

    for obsid in queue
        img_path = string(string(local_archive_pr, obsid, "/images/"), "summary.png")
        lc_paths = string.(string(local_archive_pr, obsid, "/products/lc/"), ["lc_05.jld2", "lc_0.jld2", "lc_1.jld2", "lc_2.jld2"])

        newest_lc = maximum(mtime.(lc_paths))
        summary_age = mtime(img_path)

        if summary_age - newest_lc < 0
            println("$obsid - LC newer than image - plotting")
            plot_overview(obsid; plot_width=plot_width, plot_height=plot_height, local_archive_pr=local_archive_pr)
            i += 1
        else
            #println("$obsid - LC older than image - skipping")
            continue
        end

        if i >= batch_size
            return
        end
    end
end

function plt_batch(;batch_size=10000, plot_width=1200, plot_height=300, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
    plot_overview_batch(;batch_size=10000, plot_width=1200, plot_height=300, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
end

function full_workflow(batch_size=10000)
    NuSTAR.Numaster(download=false)

    info("xsel_evt_batch")

    NuSTAR.xsel_evt_batch(batch_size=batch_size)

    info("PRESS ENTER ONCE XSELECT HAS FINISHED")

    readline(STDIN)

    NuSTAR.Numaster(download=false)

    info("generate_standard_lc_files_batch")

    NuSTAR.generate_standard_lc_files_batch(batch_size=batch_size)

    NuSTAR.Numaster(download=false)

    info("plot_overview_batch")

    NuSTAR.plot_overview_batch(batch_size=batch_size)

    NuSTAR.Numaster(download=false)

    info("WebGen")

    NuSTAR.WebGen()
end
