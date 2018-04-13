### TOOLS
function _freq_limits(freqs, data, lims)

    lo = findfirst(freqs .>= lims[1])
    hi = findfirst(freqs .>= lims[2])

    hi in [1, 0, -1]? hi = length(freqs) : ""

    return freqs[lo:hi], data[lo:hi, :]
end

function _log_formatter!(y_values; minimum=0)
    pow10_max = ceil(Int, log10(maximum(y_values)))

    yticks!(logspace(0, pow10_max, pow10_max+1))
    ylims!(minimum, 10^(pow10_max))
    plot!(yformatter = yi-> Int(yi))
end

function _universal_plot_format(u_plot)
    if u_plot == 1
        return plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
    else
        return plot!()
    end
end


### LIGHTCURVE
function plot_lc(times, counts, obsid, binsize_sec, gtis;
        title="$(obsid) - $(binsize_sec) s lightcurve", u_plot=1)
    plot(times, counts, xlab="Time [s]", ylab="Counts [/s]", lab="Count", title=title)
    vline!([minimum(gtis, 2)], color=:green, lab="GTI Start")
    vline!([maximum(gtis, 2)], color=:red, lab="GTI Stop")
    _universal_plot_format(u_plot)
end

function plot_lc(binned_lc::Binned_event; title="", u_plot=1)
    if title == ""
        plot_lc(binned_lc.times, binned_lc.counts, binned_lc.obsid, binned_lc.binsize_sec, binned_lc.gtis)
    else
        plot_lc(binned_lc.times, binned_lc.counts, binned_lc.obsid, binned_lc.binsize_sec, binned_lc.gtis;
            title=title)
    end
end

function plot_lc(unbinned, binsize_sec::Real; title="", u_plot=1)
    binned_lc = bin_lc(unbinned, binsize_sec)

    plot_lc(binned_lc; title=title)
end


### FFT
function plot_pds(lc_pds::Lc_pds;
        title="Full FFT - Leahy norm.", logx=false, logy=true, laby=true, hz_min=2*2e-3, hz_max=0, u_plot=1)

    freqs, powers = _freq_limits(lc_pds.freqs, lc_pds.mean_powers, (hz_min, hz_max))

    plot(freqs, powers, title=title, lab="")

    hline!([2], color=:cyan, style=:dash, lab="") # Leahy noise

    logx ? xaxis!("Freq [Hz - log10]", :log10) : xaxis!("Freq [Hz]")
    logy ? yaxis!("Power [log10]", :log10) : yaxis!("Power")
    laby ? "" : ylabel!("")
    logy ? _log_formatter!(powers; minimum=1) : ""
    hz_max == 2 ? xticks!((0:20)./5) : ""

    _universal_plot_format(u_plot)
end


### PULSATION CHECK
function plt_pulses(lc_pds::Lc_pds; title="FFT Pulses", logx=false, logy=true, laby=true, nu=false, hz_min=1e-3, hz_max=0.5/lc_pds.binsize_sec, u_plot=1)
    #min_idx = findfirst(lc_pds.freqs .>= hz_min)
    #max_idx = findfirst(lc_pds.freqs .>= hz_max)

    #max_idx in [1, 0, -1] ? max_idx = length(lc_pds.freqs) : ""

    freqs, interval_powers = _freq_limits(lc_pds.freqs, lc_pds.interval_powers, (hz_min, hz_max))

    plot(title=title)

    power_ranges = [30, 30, 40, 60, Inf]
    opcty_ranges = [0, 0.2, 0.4, 0.8]
    colours      = [:white, :yellow, :blue, :green, :red]
    markers      = [:circle, :dtriangle, :diamond, :star6]

    for i = 1:size(interval_powers, 2)
        for r = 1:length(power_ranges)-1
            a = interval_powers[:, i]
            a[a .<= power_ranges[r]] = NaN
            a[a .> power_ranges[r+1]] = NaN

            scatter!(freqs, a, alpha=opcty_ranges[r], lab="", marker=markers[r], color=:black)
        end
    end

    hline!([2], lab="")

    logx ? xaxis!("Freq [Hz - log10]", :log10) : xaxis!("Freq [Hz]")
    logy ? yaxis!("Power [log10]", :log10) : yaxis!("Power")
    laby ? "" : ylabel!("")
    logy ? _log_formatter!(interval_powers; minimum=30) : ""
    hz_max == 2 ? xticks!((0:20)./5) : ""

    xlims!(hz_min, hz_max)

    _universal_plot_format(u_plot)
end


### TILED FFT AND PULSATION
function plot_fft_pulse_tiled(lc_pds::Lc_pds; u_plot=1)
    nyquist = 0.5/(0.002)

    c_hz_max = 10
    c_hz_min = 10

    a1 = plot_pds(lc_pds; logy=false, hz_max=c_hz_max, title="FFT 0 to $c_hz_max Hz")
    a2 = plot_pds(lc_pds; logy=false, laby=false, hz_min=c_hz_min, hz_max=nyquist, title="FFT $c_hz_max Hz+")
    b1 = plot_pds(lc_pds; logy=true, hz_max=c_hz_max, title="semi-log")
    b2 = plot_pds(lc_pds; logy=true, laby=false, hz_min=2, hz_max=nyquist, title="semi-log")
    c1 = plt_pulses(lc_pds; logy=true, hz_max=c_hz_max, title="semi-log pulses")
    c2 = plt_pulses(lc_pds; logy=true, laby=false, hz_min=2, hz_max=nyquist, title="semi-log pulses")

    ly = @layout [ [a1{0.5w} a2{0.5w}]; [b1{0.5w} b2{0.5w}]; [c1{0.5w} c2{0.5w}]]

    plot(layout=ly, a1, a2, b1, b2, c1, c2)
    _universal_plot_format(u_plot)
end


### SPECTROGRAM
function plot_spectrogram(lc_spectrogram::Lc_spectrogram;
        title="STFT - binned $(lc_spectrogram.binsize_sec) s - pow2db2 - GTI only - $(lc_spectrogram.stft_intervals) s intervals", u_plot=1)
    powers_no_zero_freq = lc_spectrogram.stft_powers[1, :] = NaN

    heatmap(lc_spectrogram.stft_freqs[1:end], lc_spectrogram.stft_time, (pow2db.(abs.(lc_spectrogram.stft_powers)').^2), legend=false)
    plot!(size=(900, 400), title=title, xlab="Frequency [Hz]", ylab="Time Inside GTI (gapless) [s]")
    hline!(lc_spectrogram.gti_bounds, color=:cyan, style=:dash)

    _universal_plot_format(u_plot)
end


### PERIODOGRAM
function plot_periodogram(lc_periodogram::Lc_periodogram;
        title="Periodogram - binned $(lc_periodogram.binsize_sec) s", u_plot=1)

    lc_periodogram.powers[1] = NaN


    sg_filtered  = sgolayfilt(lc_periodogram.powers, 2, floor(Int, length(lc_periodogram.powers)/200))
    mean_powers  = mean(lc_periodogram.powers[.!isnan.(lc_periodogram.powers)])
    mean_filterd = mean(sg_filtered[.!isnan.(sg_filtered)])
    scaling      = mean_powers/mean_filterd
    sg_filtered  = sg_filtered.*scaling

    plot(lc_periodogram.freqs, lc_periodogram.powers, title=title, lab="")

    plot!(lc_periodogram.freqs, abs.(sg_filtered), title=title, lab="Smoothed")

    _universal_plot_format(u_plot)
end


function plot_overview(plt_lc::Plots.Plot{Plots.PyPlotBackend}, plt_fft_pulse_tiled::Plots.Plot{Plots.PyPlotBackend}, plt_stft_05::Plots.Plot{Plots.PyPlotBackend}, plt_periodogram_05::Plots.Plot{Plots.PyPlotBackend}, plt_stft_2::Plots.Plot{Plots.PyPlotBackend}, plt_periodogram_2::Plots.Plot{Plots.PyPlotBackend}; section_size=(1200, 150))

    # lc->1, fft_pulse_tiled->4, spectrograms->2, periodograms->1
    plot(plt_lc, plt_fft_pulse_tiled, plt_stft_05, plt_periodogram_05, plt_stft_2, plt_periodogram_2, layout=grid(6, 1, heights=[1/11, 4/11, 2/11, 1/11, 2/11, 1/11]), size=(section_size[1], section_size[2]*11))
end



# function plot_overview(binned_lc_1::Binned_event, lc_ub_fft::Lc_fft, lc_05_stft::Lc_stft, lc_05_periodogram::Lc_periodogram, lc_2_stft::Lc_stft, lc_2_periodogram::Lc_periodogram; plot_width=1200, plot_height=300)
#     plt_lc = NuSTAR.plot_lc(binned_lc_1)
#
#     plt_fft_tiled = Plots.Plot{Plots.PyPlotBackend}; try
#         plt_fft_tiled = NuSTAR.plot_fft_tiled(lc_ub_fft)
#     catch plot_error
#         warn("Error plotting plt_fft_tiled - $plot_error")
#         plt_fft_tiled = plot([1], [1], title="Plot error")
#     end
#
#     plt_per_stft_tiled_05 = Plots.Plot{Plots.PyPlotBackend}; try
#         plt_per_stft_tiled_05 = plot_per_stft_tiled(lc_05_stft, lc_05_periodogram)
#     catch plot_error
#         warn("Error plotting plt_per_stft_tiled_05 - $plot_error")
#         plt_per_stft_tiled_05 = plot([1], [1], title="Plot error")
#     end
#
#     plt_per_stft_tiled_2 = Plots.Plot{Plots.PyPlotBackend}; try
#         plt_per_stft_tiled_2 = plot_per_stft_tiled(lc_2_stft, lc_2_periodogram)
#     catch plot_error
#         warn("Error plotting plt_per_stft_tiled_2 - $plot_error")
#         plt_per_stft_tiled_2 = plot([1], [1], title="Plot error")
#     end
#
#     plot(plt_lc, plt_fft_tiled, plt_per_stft_tiled_05, plt_per_stft_tiled_2, layout=grid(4, 1, heights=[1/9, 4/9, 2/9, 2/9]), size=(plot_width, plot_height*(9/2)))
#     plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
# end
