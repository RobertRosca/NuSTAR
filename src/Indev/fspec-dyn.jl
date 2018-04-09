struct Lc_dyn
    obsid::String
    freqs::Array{Float64,1}
    interval_pwers::Array{Float64,2}
    mean::Array{Float64,1}
    fft_length_sec::Number
    bin::Number
end

function evt_fft(unbinned_evt; fft_length_sec::Number=128, binsize_sec::Float64=2e-3)
    if binsize_sec < 2e-6
        warn("NuSTAR temportal resolution is 2e-3, cannot bin under that value, binsec $bin_sec is invalid\nSet to 2e-3")
        binsize_sec = 2e-3
    end

    times = unbinned_evt.event[:TIME]
    gtis  = unbinned_evt.gtis

    times_in_gti = []

    for gti in gtis
        start = findfirst(times .>= gti[1])
        stop  = findfirst(times .>= gti[2]) -1
        append!(times_in_gti, [times[start:stop]])
    end

    times_in_gti = [ts .- ts[1] for ts in times_in_gti] # All start at t = 0

    fft_interval_count = [floor(t[end]/fft_length_sec) for t in times_in_gti]

    fft_intervals = []

    for (i, time) in enumerate(times_in_gti)
        current_gti = time

        for i in 1:fft_interval_count[i]
            first_end    = findfirst(current_gti .>= fft_length_sec) - 1
            fft_interval = current_gti[1:first_end]

            append!(fft_intervals, [fft_interval])

            current_gti = current_gti[first_end:end]
            current_gti = current_gti .- current_gti[1] # Set next GTI to start at t = 0
        end
    end

    counts = [sparse(fit(Histogram, x, 0:binsize_sec:fft_length_sec, closed=:right).weights) for x in fft_intervals]
    counts = hcat(counts...)

    FFTW.set_num_threads(4)

    rffts  = rfft(counts)
    rffts  = abs.(rffts)
    rffts[1, :] = 0 # Zero the 0-freq power

    freqs  = rfftfreq(length(0:binsize_sec:fft_length_sec), 1/binsize_sec)

    return Lc_dyn(unbinned_evt.obsid, freqs, rffts, mean(rffts, 2), fft_length_sec, binsize_sec)
end
