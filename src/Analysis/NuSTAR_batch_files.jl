function generate_all_binned(unbinned_evt::Unbinned_event, bin::Number)
    lc = calc_bin_lc(unbinned_evt, bin); print(".")
    lc_fft = calc_pds(lc); print(".")
    lc_stft = calc_spectrogram(lc); print(".")
    lc_periodogram = calc_periodogram(lc); print(".")

    return lc, lc_fft, lc_stft, lc_periodogram
end

function __wrap_generate_checks(path_file, unbinned_evt, binsize_sec; overwrite=false)
    if !isfile(path_file) || overwrite
        print("lc_$binsize_sec")
        try
            lc, lc_pds, lc_stft, lc_periodogram = generate_all_binned(unbinned_evt, binsize_sec)
            save_evt(path_file, lc=lc, periodogram=lc_periodogram, stft=lc_stft, pds=lc_pds); print(". ")
        catch e
            println("Saving blank file due to error - $(typeof(e))")
            lc = Binned_event(unbinned_evt.obsid, binsize_sec, sparse([]), 0.0:0.0, [0 0; 0 0])
            lc_pds = Lc_pds(unbinned_evt.obsid, binsize_sec, DSP.Util.Frequencies(0, 0, 0), [0 0; 0 0], [], 0)
            lc_stft = Lc_spectrogram(unbinned_evt.obsid, binsize_sec, Array{Complex{Float64},2}(0, 0), [], 0.0:0.0, [], [], 0, (0,0))
            lc_periodogram = Lc_periodogram(unbinned_evt.obsid, binsize_sec, [], [], [], [])
            save_evt(path_file, lc=lc, periodogram=lc_periodogram, stft=lc_stft, pds=lc_pds); print(". ")
        end
    end
end

function generate_standard_lc_files(path_evt, path_evt_unbinned, path_lc_dir; overwrite=false)
    if !isfile(path_evt_unbinned) || overwrite
        unbinned_evt = extract_evts(path_evt; gti_width_min=128)
        save_evt(path_evt_unbinned, unbinned_evt=unbinned_evt)
    else
        unbinned_evt = read_evt(path_evt_unbinned)
    end

    if !isfile(string(path_lc_dir, "lc_0.jld2")) || overwrite
        print("lc_0")
        lc_ub = calc_bin_lc(unbinned_evt, 2e-3); print(".")
        lc_ub_pds = calc_pds(lc_ub); print(".")
        save_evt(string(path_lc_dir, "lc_0.jld2"), lc=lc_ub, pds=lc_ub_pds); print(". ")
    end

    __wrap_generate_checks(string(path_lc_dir, "lc_05.jld2"), unbinned_evt, 0.5; overwrite=overwrite)

    __wrap_generate_checks(string(path_lc_dir, "lc_1.jld2"), unbinned_evt, 1; overwrite=overwrite)

    __wrap_generate_checks(string(path_lc_dir, "lc_2.jld2"), unbinned_evt, 2; overwrite=overwrite)

    print("\n")
end

function generate_standard_lc_files(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"], instrument="auto", overwrite=false)
    if instrument=="auto"
        instrument_list = ["AB"; "A"; "B"]
        instrument_path = string.(local_archive_pr, obsid, "/products/event/evt_", instrument_list, ".fits")
        instrument_idx = findfirst(isfile.(instrument_path))

        if instrument_idx == 0
            error("Event file not found automatically, ensure one of $(join(basename.(instrument_path), ", ")) is present in $(dirname(instrument_path[1]))")
        end

        instrument = instrument_list[instrument_idx]
    end

    path_fits_lc = string(local_archive_pr, obsid, "/products/event/evt_$instrument.fits")

    if !isfile(path_fits_lc)
        error("Event file not found at $path_fits_lc")
    end

    info("$path_fits_lc loaded")

    path_evt_unbinned = string(local_archive_pr, obsid, "/products/event/evt_$instrument.jld2")

    path_lc_dir = string(local_archive_pr, obsid, "/products/lc/")

    generate_standard_lc_files(path_fits_lc, path_evt_unbinned, path_lc_dir; overwrite=overwrite)
end

function batch_standard_summary_files(;batch_size=10000, local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
    numaster_df=read_numaster(numaster_path)

    queue = @from i in numaster_df begin
        @where i.EVT != "NA"
        @select i.obsid
        @collect
    end

    i = 0

    for obsid in queue
        generate_standard_lc_files(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"], instrument="auto", overwrite=overwrite)
    end
end
