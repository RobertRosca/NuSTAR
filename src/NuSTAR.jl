#__precompile__()

module NuSTAR

using FTPClient
using DataFrames
using CSV
using LightXML
using FITSIO
using StatsBase

if is_linux()
    using WCS
else
    info("Not Linux, running with reduced functionality")
end

include("ObsXML.jl")
include("MiscTools.jl")
include("ObsCal.jl")
include("Numaster.jl")
include("Analysis/FITSWCS.jl")
include("Analysis/SourceDetect.jl")
include("Analysis/Xselect.jl")

end
