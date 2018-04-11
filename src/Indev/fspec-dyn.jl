struct Lc_pds
    obsid::String
    freqs::DSP.Util.Frequencies
    interval_powers::Array{Float64,2}
    mean_powers::Array{Float64,1}
    fft_length_sec::Number
    bin::Number
end

function evt_fft(binned::Binned_event; fft_length_sec::Number=128, safe=(0, 0))
    if binned.binsize_sec < 2e-6
        warn("NuSTAR temportal resolution is 2e-6, cannot bin under that value, binsec $bin_sec is invalid\nSet to 2e-6")
        binned.binsize_sec = 2e-6
    end

    counts_in_gti = []
    times_in_gti  = []

    # Dodgy way to convert a matrix into an array of arrays
    # so each GTI is stored as an array of [start; finish]
    # and each of those GTI arrays is an array itself
    # makes life a bit easier for the following `for gti in gtis` loop
    gtis = [evt_binned.gtis[x, :] for x in 1:size(evt_binned.gtis, 1)]

    for gti in gtis # For each GTI, store the selected times and count rate within that GTI
        start = findfirst(binned.times.+safe[1] .>= gti[1])
        stop  = findfirst(binned.times.-safe[1] .>= gti[2])-1

        if stop - start > fft_length_sec
            append!(counts_in_gti, [evt_binned.counts[start:stop]])
            append!(times_in_gti, [binned.times[start:stop].-gti[1]]) # Subtract GTI start time from all times, so all start from t=0
        end
    end

    fft_interval_count = [Int(floor(t[end]/fft_length_sec)) for t in times_in_gti] # Number of intervals that fit in fully for each GTI

    fft_intervals = [] # Stores count rate in each `fft_interval` length of data

    for (i, counts) in enumerate(counts_in_gti) # Iterate through each GTI
        current_counts_in_gti = binned.counts
        current_times_in_gti  = times_in_gti[i]

        for j in 1:fft_interval_count[i] # Iterate through each 'fft_length_sec' interval
            first_end    = findfirst(current_times_in_gti .>= fft_length_sec) - 1
            fft_interval = current_counts_in_gti[1:first_end]
            append!(fft_intervals, [fft_interval])

            current_times_in_gti  = current_times_in_gti[first_end+1:end]
            current_counts_in_gti = current_counts_in_gti[first_end+1:end]
            current_times_in_gti  = current_times_in_gti .- fft_length_sec # Set next GTI to start at next interval
        end
    end

    fft_intervals = hcat(fft_intervals...) # `fft_intervals` is an array of arrays, this converts it to a matrix
    # with each column as an interval, each row as a count rate

    FFTW.set_num_threads(4)

    rffts = rfft(fft_intervals)
    rffts[1, :] = 0 # Zero the 0-freq power
    rffts = 2*(abs.(rffts).^2)./sum(fft_intervals) # Leahy normalised

    # Finds frequency axis
    freqs  = rfftfreq(length(0:binned.binsize_sec:fft_length_sec), 1/binned.binsize_sec)

    return Lc_pds(binned.obsid, freqs, rffts, mean(rffts, 2)[:], fft_length_sec, binned.binsize_sec)
end
