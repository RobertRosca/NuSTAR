<<<<<<< HEAD
__precompile__()
=======
__precompile__() # Precompiling completely breaks FTPClient for some reason
>>>>>>> 3e76ccedbbdd732963ad85f066a611eccf66f0b7

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

include("ObsXML.jl")
include("MiscTools.jl")
include("ObsCal.jl")
include("Numaster.jl")
include("Analysis/FITSWCS.jl")
include("Analysis/SourceDetect.jl")

end
