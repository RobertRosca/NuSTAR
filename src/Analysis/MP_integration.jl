function MP_batch(;local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"],
                   local_utility=ENV["NU_ARCHIVE_UTIL"], log_file="", batches=4, to_cal=16, dry=false)

   numaster_path = string(local_utility, "/numaster_df.csv")

   numaster_df = read_numaster(numaster_path)

   queue = @from i in numaster_df begin
       @where i.RegSrc==1 && i.MP==0
       @select i.obsid
       @collect
   end

   if length(queue) > to_cal
       queue = queue[1:to_cal]
   else
       to_cal = length(queue)
   end

   batch_remainder = to_cal % batches
   no_rem_cal = to_cal - batch_remainder
   no_rem_batch = Int(no_rem_cal / batches)

   batch_sizes = []

   for batch in 1:batches
       append!(batch_sizes, no_rem_batch)
   end

   for remainder in 1:batch_remainder # Add remainder by one to each batch
       batch_sizes[remainder] += 1
   end

   maltpynt_run = string(Pkg.dir(), "/NuSTAR/src/Scripts/maltpynt_run.sh")

   for i = 1:batches
       l = sum(batch_sizes[1:i]) - (batch_sizes[i] - 1)
       u = sum(batch_sizes[1:i])

       current_queue = queue[l:u]

       if typeof(current_queue) == Array{String,1}
           queue_native = join(current_queue, " ")
       elseif typeof(current_queue) == String
           queue_native = current_queue
       end

       if !dry
           run(`gnome-terminal -e "$maltpynt_run --clean="$(ENV["NU_ARCHIVE_CL"])/" --products="$(ENV["NU_ARCHIVE_PR"])/" --obsids=\"$queue_native\""`)
           info("Calibration started for $queue_native")
       else
           println("gnome-terminal -e \"$maltpynt_run --clean=\"$(ENV["NU_ARCHIVE_CL"])/\" --products=\"$(ENV["NU_ARCHIVE_PR"])/\" --obsids=\"$queue_native\"\"")
       end
   end
end

type MP_pds
    dynpds::Array{Float64,2}
    edynpds::Array{Float64,2}
    epds::Array{Float64,1}
    freq::Array{Float64,1}
    pds::Array{Float64,1}
end

type MP_cpds
    cpds::Array{Complex,1}
    ecpds::Array{Float64,1}
    freq::Array{Float64,1}
end


function MP_parse_cpds_compound(cpds_compound)
    cpds = zeros(Complex, size(cpds_compound, 1))

    for i = 1:size(cpds_compound, 1)
        compound_vals = cpds_compound[i].data
        im_value = compound_vals[1] + compound_vals[2]im
        cpds[i] = im_value
    end

    return cpds
end


function MP_parse_pds_hdf5(path)
    file = h5open(path, "r")

    dynpds = read(file, "dynpds")
    edynpds = read(file, "edynpds")
    epds = read(file, "epds")
    freq = read(file, "freq")
    pds = read(file, "pds")

    return MP_pds(dynpds, edynpds, epds, freq, pds)
end

function MP_parse_cpds_hdf5(path)
    file = h5open(path, "r")

    cpds = read(file, "cpds")
    ecpds = read(file, "ecpds")
    freq = read(file, "freq")

    cpds = MP_parse_cpds_compound(cpds)

    return MP_cpds(cpds, ecpds, freq)
end


function MP_plot_cpds(mp_cpds::MP_cpds; title="Full FFT - CPDS", logy=true, logx=false, lehey_lim=true, errors=false, hz_min=1e-2, hz_max=250)
    cpds = abs.(mp_cpds.cpds)
    freq = mp_cpds.freq
    ecpds = mp_cpds.ecpds

    # NaN first point
    cpds[1] = NaN
    freq[1] = NaN
    ecpds[1] = NaN

    idx_min = findfirst(freq .>= hz_min)
    idx_max = findlast(freq .<= hz_max)

    cpds = cpds[idx_min:idx_max]
    freq = freq[idx_min:idx_max]
    ecpds = ecpds[idx_min:idx_max]

    plot()

    if errors
        errors_pos = abs.(cpds) .+ ecpds
        errors_neg = abs.(cpds) .- ecpds

        plot!(freq, errors_neg, alpha=0.2)
    end

    plot!(freq, cpds, title=title, lab="")

    logx ? xaxis!("Freq [Hz - log10]", :log10) : xaxis!("Freq [Hz]")
    logy ? yaxis!("Power [log10]", :log10) : yaxis!("Power")
    lehey_lim && logy ? ylims!(1e-1, maximum(cpds)*10) : ""
    lehey_lim && !logy ? ylims!(1e-1, maximum(cpds)*1.1) : ""

    return plot!()
end


function MP_plot_fft_tiled(mp_cpds::MP_cpds)
    nyquist = 1/(2*0.002)

    c_hz_max = 2
    c_hz_min = 2

    a1 = MP_plot_cpds(mp_cpds; logx=false, logy=false, hz_min=2e-2, hz_max=c_hz_max, title="FFT 0 to $c_hz_max Hz")
    a2 = MP_plot_cpds(mp_cpds; logx=false, logy=false, hz_min=c_hz_min, hz_max=nyquist, title="FFT $c_hz_max Hz+")
    b1 = MP_plot_cpds(mp_cpds; logx=false, logy=true, hz_min=2e-2, hz_max=c_hz_max, title="semi-log")
    b2 = MP_plot_cpds(mp_cpds; logx=false, logy=true, hz_min=c_hz_min, hz_max=nyquist, title="semi-log")

    ly = @layout [ [a1{0.5w} a2{0.5w}]; [b1{0.5w} b2{0.5w}]]

    plot(layout=ly, a1, a2, b1, b2)
    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10, size=(1000, 1000))
end


function MP_plot_overview(binned_lc_1::Binned_event, mp_ub_cpds::MP_cpds, lc_05_stft::Lc_stft, lc_05_periodogram::Lc_periodogram, lc_2_stft::Lc_stft, lc_2_periodogram::Lc_periodogram; plot_width=1200, plot_height=300)
    plt_lc = NuSTAR.plot_lc(binned_lc_1)

    plt_fft_tiled = Plots.Plot{Plots.PyPlotBackend}; try
        plt_fft_tiled = NuSTAR.MP_plot_fft_tiled(mp_ub_cpds)
    catch plot_error
        warn("Error plotting plt_fft_tiled - $plot_error")
        plt_fft_tiled = plot([1], [1], title="Plot error")
    end

    plt_per_stft_tiled_05 = Plots.Plot{Plots.PyPlotBackend}; try
        plt_per_stft_tiled_05 = plot_per_stft_tiled(lc_05_stft, lc_05_periodogram)
    catch plot_error
        warn("Error plotting plt_per_stft_tiled_05 - $plot_error")
        plt_per_stft_tiled_05 = plot([1], [1], title="Plot error")
    end

    plt_per_stft_tiled_2 = Plots.Plot{Plots.PyPlotBackend}; try
        plt_per_stft_tiled_2 = plot_per_stft_tiled(lc_2_stft, lc_2_periodogram)
    catch plot_error
        warn("Error plotting plt_per_stft_tiled_2 - $plot_error")
        plt_per_stft_tiled_2 = plot([1], [1], title="Plot error")
    end

    plot(plt_lc, plt_fft_tiled, plt_per_stft_tiled_05, plt_per_stft_tiled_2, layout=grid(4, 1, heights=[1/9, 4/9, 2/9, 2/9]), size=(plot_width, plot_height*(9/2)))
    plot!(title_location=:left, titlefontsize=10, margin=2mm, xguidefontsize=10, yguidefontsize=10)
end

function MP_plot_overview(obsid::String; plot_width=1200, plot_height=300, local_archive_pr=ENV["NU_ARCHIVE_PR"])
    path_lc_dir = string(local_archive_pr, obsid, "/products/lc/")
    path_img_dir = string(local_archive_pr, obsid, "/images/")
    path_mp_dir = string(local_archive_pr, obsid, "/products/MP/")

    binned_lc_1 = read_evt(string(path_lc_dir, "lc_1.jld2"), "lc")
    mp_ub_cpds = MP_parse_cpds_hdf5(string(path_mp_dir, "0.002/nu$(obsid)01_cpds.hdf5"))
    lc_05_stft = read_evt(string(path_lc_dir, "lc_05.jld2"), "stft")
    lc_05_periodogram = read_evt(string(path_lc_dir, "lc_05.jld2"), "periodogram")
    lc_2_stft = read_evt(string(path_lc_dir, "lc_2.jld2"), "stft")
    lc_2_periodogram = read_evt(string(path_lc_dir, "lc_2.jld2"), "periodogram")

    plt_overview = MP_plot_overview(binned_lc_1, mp_ub_cpds, lc_05_stft, lc_05_periodogram, lc_2_stft, lc_2_periodogram; plot_width=plot_width, plot_height=plot_height)

    savefig(plt_overview, string(path_img_dir, "summary_MP.png"))
end
