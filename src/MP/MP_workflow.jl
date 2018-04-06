function MP_products(obsid; bintime = 2e-3,
        local_archive_cl=ENV["NU_ARCHIVE_CL"], local_archive_pr=ENV["NU_ARCHIVE_PR"])

    path_pipeline = string(local_archive_cl, obsid, "/pipeline_out/")
    path_mp_out   = string(local_archive_pr, obsid, "/products/MP/")
    path_a = string(path_pipeline, "nu$(obsid)A01_cl.evt")
    path_b = string(path_pipeline, "nu$(obsid)B01_cl.evt")

    @assert isfile(path_a) && isfile(path_b) "cleaned evt files not found"

    if !ispath(path_mp_out)
        mkpath(path_mp_out)
    end

    info("MPread - $path_a")
    maltpynt.read_events[:treat_event_file](path_a)
    info("MPread - $path_b")
    maltpynt.read_events[:treat_event_file](path_b)

    path_a_ev = string(path_pipeline, "nu$(obsid)A01_cl_ev.p")
    path_b_ev = string(path_pipeline, "nu$(obsid)B01_cl_ev.p")
    @assert isfile(path_a_ev) && isfile(path_b_ev) "MP ev files not found, error while generating?"

    mv(path_a_ev, string(path_mp_out, "nu$(obsid)A01_cl_ev.p"), remove_destination=true)
    mv(path_b_ev, string(path_mp_out, "nu$(obsid)B01_cl_ev.p"), remove_destination=true)

    path_a_ev = string(path_mp_out, "nu$(obsid)A01_cl_ev.p")
    path_b_ev = string(path_mp_out, "nu$(obsid)B01_cl_ev.p")

    path_a_calib = string(path_mp_out, "nu$(obsid)A01_cl_calib.p")
    path_b_calib = string(path_mp_out, "nu$(obsid)B01_cl_calib.p")

    rmf_file = "/home/sw-astro/caldb/data/nustar/fpm/cpf/rmfnuAdet3_20100101v002.rmf"
    if isfile(rmf_file)
        info("MPcalibrate - $path_a_ev")
        maltpynt.calibrate[:calibrate](path_a_ev, path_a_calib, rmf_file=rmf_file)
        info("MPcalibrate - $path_b_ev")
        maltpynt.calibrate[:calibrate](path_b_ev, path_b_calib, rmf_file=rmf_file)
    else
        info("MPcalibrate - $path_a_ev")
        maltpynt.calibrate[:calibrate](path_a_ev, path_a_calib)
        info("MPcalibrate - $path_b_ev")
        maltpynt.calibrate[:calibrate](path_b_ev, path_b_calib)
    end

    @assert isfile(path_a_calib) && isfile(path_b_calib) "MP calib files not found, error while generating?"

    total_count_rate = MP_calib_total_crate(path_a_calib, path_b_calib)

    if total_count_rate < minimum_count_rate
        warning("Count rate too low, aborting!")
        return
    end

    path_a_lc = string(path_mp_out, "nu$(obsid)A01_cl_lc.p")
    path_b_lc = string(path_mp_out, "nu$(obsid)B01_cl_lc.p")

    info("MPlcurve - $path_a_calib")
    maltpynt.lcurve[:lcurve_from_events](path_a_calib, safe_interval=[100, 300], bintime=bintime)
    info("MPlcurve - $path_b_calib")
    maltpynt.lcurve[:lcurve_from_events](path_b_calib, safe_interval=[100, 300], bintime=bintime)

    @assert isfile(path_a_lc) && isfile(path_b_lc) "MP lc files not found, error while generating?"
end
