### PDS
struct Lc_pds
    obsid::String
    binsize_sec::Number
    freqs::DSP.Util.Frequencies
    interval_powers::Array{Float64,2}
    mean_powers::Array{Float64,1}
    fft_length_sec::Number
end

function calc_pds(binned::Binned_event; fft_length_sec::Number=128, safe=(0, 0))
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

    return Lc_pds(binned.obsid, binned.binsize_sec, freqs, rffts, mean(rffts, 2)[:], fft_length_sec)
end


### SPECTROGRAM
struct Lc_spectrogram
    obsid::String
    binsize_sec::Number
    stft_powers::Array{Complex{Float64},2}
    stft_time::Array{Float64,1}
    stft_freqs::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    gti_lengths::Array{Float64,1}
    gti_bounds::Array{Float64,1}
    stft_intervals::Real
    safe::Tuple{Real,Real}
end

function calc_spectrogram(binned::Binned_event; safe=(100, 300), stft_intervals=1024)
    counts_in_gti = []
    times_in_gti  = []

    gtis = [binned.gtis[x, :] for x in 1:size(binned.gtis, 1)]

    for gti in gtis # For each GTI, store the selected times and count rate within that GTI
        start = findfirst(binned.times.-safe[1] .> gti[1])
        stop  = findfirst(binned.times.+safe[2] .> gti[2])

        if stop - start > 0
            append!(counts_in_gti, [binned.counts[start:stop]])
            append!(times_in_gti, [binned.times[start:stop]])
        end
    end

    counts_in_gti = vcat(counts_in_gti...)

    dsp_stft      = stft(counts_in_gti, stft_intervals; fs=1/binned.binsize_sec)
    dsp_stft_time = collect(1:size(dsp_stft, 2)).*(stft_intervals/2)
    dsp_stft_freq  = linspace(0, 0.5*(1/binned.binsize_sec), size(dsp_stft, 1))

    start = [x[1] for x in times_in_gti]
    stop  = [x[end] for x in times_in_gti]

    gti_lengths   = stop .- start
    gti_bounds    = cumsum(gti_lengths)
    gti_bounds[end] = maximum(dsp_stft_time)

    Lc_spectrogram(binned.obsid, binned.binsize_sec, dsp_stft, dsp_stft_time, dsp_stft_freq, gti_lengths, gti_bounds, stft_intervals, safe)
end
