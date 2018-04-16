function generate_all_binned(unbinned_evt::Unbinned_event, bin::Number)
    lc = calc_bin_lc(unbinned_evt, bin); print(".")
    lc_fft = calc_pds(lc); print(".")
    lc_stft = calc_spectrogram(lc); print(".")
    lc_periodogram = calc_periodogram(lc); print(".")

    return lc, lc_fft, lc_stft, lc_periodogram
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

    if !isfile(string(path_lc_dir, "lc_05.jld2")) || overwrite
        print("lc_05")
        lc_05, lc_05_pds, lc_05_stft, lc_05_periodogram = generate_all_binned(unbinned_evt, 0.5)
        save_evt(string(path_lc_dir, "lc_05.jld2"), lc=lc_05, periodogram=lc_05_periodogram, stft=lc_05_stft, pds=lc_05_pds); print(". ")
    end

    if !isfile(string(path_lc_dir, "lc_1.jld2")) || overwrite
        print("lc_1")
        lc_1, lc_1_pds, lc_1_stft, lc_1_periodogram = generate_all_binned(unbinned_evt, 1)
        save_evt(string(path_lc_dir, "lc_1.jld2"), lc=lc_1, periodogram=lc_1_periodogram, stft=lc_1_stft, pds=lc_1_pds); print(". ")
    end

    if !isfile(string(path_lc_dir, "lc_2.jld2")) || overwrite
        print("lc_2")
        lc_2, lc_2_pds, lc_2_stft, lc_2_periodogram = generate_all_binned(unbinned_evt, 2)
        save_evt(string(path_lc_dir, "lc_2.jld2"), lc=lc_2, periodogram=lc_2_periodogram, stft=lc_2_stft, pds=lc_2_pds); print(". ")
    end

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
