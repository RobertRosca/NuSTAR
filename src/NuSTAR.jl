#__precompile__(false) # Precompiling completely breaks FTPClient for some reason

module NuSTAR

using Printf # For deprecated sprintf() function
using DelimitedFiles # For deprecated Base.readdlm()
using Dates # For deprecated Base.Dates
#using GZip # Base.download() doesn't unzip anymore
using FTPClient
using DataFrames
using CSV
using LightXML
using FITSIO

if Sys.islinux()
    using WCS
else
    @info "Not Linux, running with reduced functionality"
end

include("ObsXML.jl")
include("MiscTools.jl")
include("ObsCal.jl")
include("Numaster.jl")
include("Analysis/FITSWCS.jl")
include("Analysis/SourceDetect.jl")

end
