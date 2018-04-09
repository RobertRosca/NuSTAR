struct Lc_periodogram
    obsid::String
    gti_freqs::Array{Array{Float64,1},1}
    gti_pwers::Array{Array{Float64,1},1}
    freqs::Array{Float64,1}
    pwers::Array{Float64,1}
    freqs_welch::Array{Float64,1}
    pwers_welch::Array{Float64,1}
    bin::Number
end
