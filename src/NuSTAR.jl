#__precompile__()

module NuSTAR

using FTPClient
using DataFrames
using Query
using CSV
using LightXML
using FITSIO
using StatsBase
using FileIO, JLD2
using DSP
using Wavelets
using HDF5

using Measures
using Plots
pyplot()

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
include("WebApp/WebGen.jl")
include("Analysis/DS9Img.jl")
include("Analysis/Plotters.jl")

# Another X-ray Timing Module
include("AXTM/io.jl")
include("AXTM/lcurve.jl")
include("AXTM/fspec-dyn.jl")
include("AXTM/fspec-per.jl")
include("AXTM/plotting.jl")

include("Analysis/NuSTAR_batch_files.jl")
include("Analysis/NuSTAR_batch_plot.jl")

nustar_settings_file = string(homedir(), "/.config/julia-pkg/v0.6/NuSTAR/NuSTAR-settings.jl")

if !isfile(nustar_settings_file)
    warn("No settings file found at: $nustar_settings_file\nEnter full paths for:\n")

    mkpath(dirname(nustar_settings_file))

    println("NU_ARCHIVE: ");    ENV["NU_ARCHIVE"] = string(readline(STDIN))
    println("NU_ARCHIVE_CL: "); ENV["NU_ARCHIVE_CL"] = string(readline(STDIN))
    println("NU_ARCHIVE_PR: "); ENV["NU_ARCHIVE_PR"] = string(readline(STDIN))
    println("NU_ARCHIVE_UTIL: "); ENV["NU_ARCHIVE_UTIL"] = string(readline(STDIN))

    println("NU_SCRATCH_FLAG (true/false): "); ENV["NU_SCRATCH_FLAG"] = parse(Bool, readline(STDIN))

    open(nustar_settings_file, "w") do f
        write(f, "ENV[\"NU_ARCHIVE\"] = \"$(ENV["NU_ARCHIVE"])\"\n")
        write(f, "ENV[\"NU_ARCHIVE_CL\"] = \"$(ENV["NU_ARCHIVE_CL"])\"\n")
        write(f, "ENV[\"NU_ARCHIVE_PR\"] = \"$(ENV["NU_ARCHIVE_PR"])\"\n")

        write(f, "ENV[\"NU_ARCHIVE_UTIL\"] = \"$(ENV["NU_ARCHIVE_UTIL"])\"\n")

        write(f, "ENV[\"NU_SCRATCH_FLAG\"] = $(ENV["NU_SCRATCH_FLAG"])\n")

        if ENV["NU_SCRATCH_FLAG"] == "true"
            println("NU_ARCHIVE_LIVE: ");    ENV["NU_ARCHIVE_LIVE"] = string(readline(STDIN))
            println("NU_ARCHIVE_CL_LIVE: "); ENV["NU_ARCHIVE_CL_LIVE"] = string(readline(STDIN))
            println("NU_ARCHIVE_PR_LIVE: "); ENV["NU_ARCHIVE_PR_LIVE"] = string(readline(STDIN))

            write(f, "ENV[\"NU_ARCHIVE_LIVE\"] = \"$(ENV["NU_ARCHIVE_LIVE"])\"\n")
            write(f, "ENV[\"NU_ARCHIVE_CL_LIVE\"] = \"$(ENV["NU_ARCHIVE_CL_LIVE"])\"\n")
            write(f, "ENV[\"NU_ARCHIVE_PR_LIVE\"] = \"$(ENV["NU_ARCHIVE_PR_LIVE"])\"\n")
        end
    end
end

include(nustar_settings_file)

end
