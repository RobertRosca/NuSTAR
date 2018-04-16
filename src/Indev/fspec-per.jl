### PERIODOGRAM
struct Lc_periodogram
    obsid::String
    binsize_sec::Number
    freqs::Array{Float64,1}
    powers::Array{Float64,1}
    freqs_welch::Array{Float64,1}
    powers_welch::Array{Float64,1}
end

function calc_periodogram(binned::Binned_event; safe=(100, 300))
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

    pgram = periodogram(counts_in_gti; fs=1/binned.binsize_sec)

    pgram_welch = welch_pgram(counts_in_gti; fs=1/binned.binsize_sec)

    return Lc_periodogram(binned.obsid, binned.binsize_sec, pgram.freq, pgram.power, pgram_welch.freq, pgram_welch.power)
end
