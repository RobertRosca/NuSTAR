function MP_products(obsid; bintime = 2e-3, minimum_count_rate = 2, clobber=false,
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

    rmf_file = "/home/sw-astro/caldb/data/nustar/fpm/cpf/rmf/nuAdet3_20100101v002.rmf"
    if isfile(path_a_calib) && isfile(path_a_calib) && !clobber
        info("Calib files already exist, skipping - $path_a_ev")
    else
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
    end

    @assert isfile(path_a_calib) && isfile(path_b_calib) "MP calib files not found, error while generating?"

    path_a_lc = string(path_mp_out, "nu$(obsid)A01_cl_lc.p")
    path_b_lc = string(path_mp_out, "nu$(obsid)B01_cl_lc.p")

    if isfile(path_a_lc) && isfile(path_b_lc) && !clobber
        info("Calib files already exist, skipping - $path_a_ev")
    else
        total_count_rate = MP_calib_total_crate(path_a_calib, path_b_calib)

        if total_count_rate < minimum_count_rate
            warning("Count rate too low, aborting!")
            return
        end

        info("MPlcurve - $path_a_calib")
        maltpynt.lcurve[:lcurve_from_events](path_a_calib, safe_interval=[100, 300], bintime=bintime)
        info("MPlcurve - $path_b_calib")
        maltpynt.lcurve[:lcurve_from_events](path_b_calib, safe_interval=[100, 300], bintime=bintime)
    end

    @assert isfile(path_a_lc) && isfile(path_b_lc) "MP lc files not found, error while generating?"
end

function MP_calib_total_crate(data_calib::MP_calib; min_gti_sec=512)
    gti_good = data_calib.GTI[([x[2]-x[1] for x in data_calib.GTI] .> 512)]

    count_evt  = 0
    count_time = 0
    for gti in gti_good
        count_evt  += count(gti[2] .> data_calib.time .> gti[1])
        count_time += gti[2] - gti[1]
    end

    count_rate = count_evt/count_time

    return count_rate
end

function MP_calib_total_crate(data_a_calib::MP_calib, data_b_calib::MP_calib; min_gti_sec=512)
    count_rate_a = MP_calib_total_crate(data_a_calib; min_gti_sec=min_gti_sec)
    count_rate_b = MP_calib_total_crate(data_b_calib; min_gti_sec=min_gti_sec)

    return count_rate_a + count_rate_b
end

function MP_calib_total_crate(path_a_calib::String, path_b_calib::String; min_gti_sec=512)
    data_a_calib = MP_parse_calib(path_a_calib)
    data_b_calib = MP_parse_calib(path_b_calib)

    return MP_calib_total_crate(data_a_calib, data_b_calib; min_gti_sec=min_gti_sec)
end
