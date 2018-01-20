#__precompile__() Precompiling completely breaks FTPClient for some reason

module NuSTAR

using FTPClient
using DataFrames
using CSV
using LightXML

include("ObsLog.jl")
include("ObsXML.jl")
include("MiscTools.jl")
include("ObsCal.jl")

#export ObsLog, ObsGenerateXML, ObsGenerateXMLBatch

end

using NuSTAR

# ObsLog() to pull newest data

# ObsGenerateXMLBatch() to create... batch of newest obs, add to FileZilla
