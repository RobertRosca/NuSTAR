struct Binned_event
    obsid::String
    binsize_sec::Real
    counts::SparseVector
    times::StepRangeLen
    gtis::Array{Float64,2}
end

function calc_bin_lc(unbinned, binsize_sec::Real)#::Unbinned_event
    if binsize_sec < 2e-6
        warn("NuSTAR temportal resolution is 2e-6, cannot bin under that value, binsec $bin_sec is invalid\nSet to 2e-6")
        binsize_sec = 2e-6
    end

    #if fft_length_sec%binsize_sec != 0; error("FFT must be a multiple of the binsize"); end

    # Load times and GTIs to variables
    times = unbinned.event[:TIME]
    gtis  = vcat(unbinned.gtis'...)

    # Fit timestamps to histogram, acts as binning to create a lightcurve
    # Done at this stage to ensure that all of the bin edges line up with each other during the FFT
    count_hist = fit(Histogram, times, 0:binsize_sec:(unbinned.stop - unbinned.start), closed=:right)
    counts = sparse(count_hist.weights)
    times  = count_hist.edges[1]

    return Binned_event(unbinned.obsid, binsize_sec, counts, times, gtis)
end
