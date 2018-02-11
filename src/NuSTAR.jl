__precompile__(false) # Precompiling completely breaks FTPClient for some reason

module NuSTAR

using FTPClient
using DataFrames
using CSV
using LightXML
using FITSIO

if is_linux()
    using WCS
else
    info("Not Linux, running with reduced functionality")
end

#include("ObsLog.jl")
include("ObsXML.jl")
include("MiscTools.jl")
include("ObsCal.jl")
include("Numaster.jl")
include("Analysis\\FITSWCS.jl")
include("Analysis\\SourceDetect.jl")

#export ObsLog, ObsGenerateXML, ObsGenerateXMLBatch

end

# using NuSTAR

# ObsLog() to pull newest data

# ObsGenerateXMLBatch() to create... batch of newest obs, add to FileZilla
