type MP_ev
    MJDref::Float64
    Tstop::Float64
    time::Array{Any,1}
    PI::Array{Int32,1}
    Tstart::Float64
    Instr::String
    GTI::Array{Any,1}
end
function MP_parse_ev(path)
    data = maltpynt.io[:load_data](path)

    MJDref = convert(Float64, data["MJDref"])
    Tstop  = convert(Float64, data["Tstop"])
    time   = convert(Array{Float64,1}, data["time"])
    PI     = data["PI"]
    Tstart = convert(Float64, data["Tstart"])
    Instr  = data["Instr"]

    GTI = []
    for gti in data["GTI"]
        append!(GTI, [convert(Array{Float64,1}, gti)])
    end

    return MP_ev(MJDref, Tstop, time, PI, Tstart, Instr, GTI)
end


type MP_calib
    MJDref::Float64
    Tstop::Float64
    time::Array{Any,1}
    PI::Array{Int32,1}
    E::Array{Float64,1}
    Tstart::Float64
    Instr::String
    GTI::Array{Any,1}
end
function MP_parse_calib(path)
    data = maltpynt.io[:load_data](path)

    MJDref = convert(Float64, data["MJDref"])
    Tstop  = convert(Float64, data["Tstop"])
    time   = convert(Array{Float64,1}, data["time"])
    PI     = data["PI"]
    E      = data["E"]
    Tstart = convert(Float64, data["Tstart"])
    Instr  = data["Instr"]
    GTI    = MP_parse_gti(data["GTI"])

    return MP_ev(MJDref, Tstop, time, PI, Tstart, Instr, GTI)
end


type MP_lc
    MJDref::Float64
    Tstop::Float64
    lc::Array{Float64,1}
    total_ctrate::Float64
    time::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    dt::Float64
    source_ctrate::Float64
    Tstart::Float64
    Instr::String
    GTI::Array{Any,1}
end
function MP_parse_lc(path)
    data = maltpynt.io[:_load_data_pickle](path)

    MJDref        = convert(Float64, data["MJDref"])
    Tstop         = convert(Float64, data["Tstop"])
    lc            = data["lc"]
    total_ctrate  = convert(Float64, data["total_ctrate"])
    dt            = convert(Float64, data["dt"])
    time_start    = convert(Float64, data["time"][1])
    time_stop     = convert(Float64, data["time"][end])
    time          = time_start:dt:time_stop
    source_ctrate = convert(Float64, data["source_ctrate"])
    Tstart        = convert(Float64, data["Tstart"])
    Instr         = data["Instr"]
    GTI           = MP_parse_gti(data["GTI"])

    return MP_lc(MJDref, Tstop, lc, total_ctrate, time, dt, source_ctrate, Tstart, Instr, GTI)
end


type MP_cpds
    rebin::Int64
    time::Float64
    total_ctrate::Float64
    back_ctrate::Float64
    fftlen::Int64
    ctrate::Float64
    ecpds::Array{Float64,1}
    cpds::Array{Complex{Float64},1}
    norm::String
    freq::Array{Float64,1}
    MJDref::Float64
    ncpds::Int64
    Instrs::String
end

function MP_parse_cpds(path)
    data = maltpynt.io[:_load_data_pickle](path)

    rebin        = data["rebin"]
    time         = convert(Float64, data["time"])
    total_ctrate = convert(Float64, data["total_ctrate"])
    back_ctrate  = data["back_ctrate"]
    fftlen       = data["fftlen"]
    ctrate       = convert(Float64, data["ctrate"])
    ecpds        = data["ecpds"]
    cpds         = data["cpds"]
    norm         = data["norm"]
    freq         = data["freq"]
    MJDref       = convert(Float64, data["MJDref"])
    ncpds        = data["ncpds"]
    Instrs       = data["Instrs"]

    return MP_cpds(rebin, time, total_ctrate, back_ctrate, fftlen, ctrate, ecpds, cpds, norm, freq, MJDref, ncpds, Instrs)
end
