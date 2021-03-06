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

function MP_calib_total_crate(path_calib::String; min_gti_sec=512)
    data_calib = MP_parse_calib(path_calib)

    return MP_calib_total_crate(data_calib; min_gti_sec=min_gti_sec)
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


function MP_produce_lc(obsid; bintime = 2e-3, minimum_count_rate=4, clobber=false,
        local_archive_cl=ENV["NU_ARCHIVE_CL"], local_archive_pr=ENV["NU_ARCHIVE_PR"])

    path_pipeline = string(local_archive_cl, obsid, "/pipeline_out/")
    path_mp_out   = string(local_archive_pr, obsid, "/products/MP/")
    path_a = string(path_pipeline, "nu$(obsid)A01_cl.evt")
    path_b = string(path_pipeline, "nu$(obsid)B01_cl.evt")

    if !isfile(path_a) || !isfile(path_b)
        warn("Cleaned evt files not found\n$path_a\n$path_b")
        warn("Skipping")
        return
    end

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
        info("Lightcurve files already exist, skipping - $path_a_ev")
    else
        total_count_rate = MP_calib_total_crate(path_a_calib, path_b_calib)

        if total_count_rate < minimum_count_rate
            warn("Count rate: $total_count_rate/s - too low, aborting!")
            return
        else
            info("Count rate: $total_count_rate/s")
        end

        info("MPlcurve - $path_a_calib")
        maltpynt.lcurve[:lcurve_from_events](path_a_calib, safe_interval=[100, 300], bintime=bintime)
        info("MPlcurve - $path_b_calib")
        maltpynt.lcurve[:lcurve_from_events](path_b_calib, safe_interval=[100, 300], bintime=bintime)
    end
end

function MP_produce_lc_batch(minimum_count_rate=4;
    local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"], local_utility=ENV["NU_ARCHIVE_UTIL"], procs_to_use=4, todo=16, dry=false)

   numaster_path = string(local_utility, "/numaster_df.csv")

   numaster_df = read_numaster(numaster_path)

   queue = @from i in numaster_df begin
       @where i.RegSrc==1 && i.MP==0
       @select i.obsid
       @collect
   end

   if length(queue) > todo
       queue = queue[1:todo]
   end

   for (i, obsid) in enumerate(queue)
       warn("On $i of $(length(queue))")
       info("Running on $obsid")
       MP_produce_lc(obsid; minimum_count_rate=minimum_count_rate)
       print("\n\n")
   end

   #=
   if nprocs() < procs_to_use
        addprocs(procs_to_use - nprocs())
    end

    info("Using $(nprocs()) procs")

    info("$(length(queue)) obs queued")

    @parallel for obsid in queue
        println("Running on $obsid")
        MP_calib_total_crate(obsid)
    end=#
end

function MP_produce_lc_one(obsid, instrument; bintime = 2e-3, minimum_count_rate=2, clobber=false,
        local_archive_cl=ENV["NU_ARCHIVE_CL"], local_archive_pr=ENV["NU_ARCHIVE_PR"])

    path_pipeline = string(local_archive_cl, obsid, "/pipeline_out/")
    path_mp_out   = string(local_archive_pr, obsid, "/products/MP/")
    path = string(path_pipeline, "nu$(obsid)$(instrument)01_cl.evt")

    if !isfile(path)
        warn("Cleaned evt files not found - $path")
        warn("Skipping")
        return
    end

    if !ispath(path_mp_out)
        mkpath(path_mp_out)
    end

    info("MPread - $path")
    maltpynt.read_events[:treat_event_file](path)

    path_ev = string(path_pipeline, "nu$(obsid)$(instrument)01_cl_ev.p")
    @assert isfile(path_ev) "MP ev files not found, error while generating?"

    mv(path_ev, string(path_mp_out, "nu$(obsid)$(instrument)01_cl_ev.p"), remove_destination=true)

    path_ev = string(path_mp_out, "nu$(obsid)$(instrument)01_cl_ev.p")

    path_calib = string(path_mp_out, "nu$(obsid)$(instrument)01_cl_calib.p")

    rmf_file = "/home/sw-astro/caldb/data/nustar/fpm/cpf/rmf/nuAdet3_20100101v002.rmf"
    if isfile(path_calib) && !clobber
        info("Calib files already exist, skipping - $path_ev")
    else
        if isfile(rmf_file)
            info("MPcalibrate - $path_ev")
            maltpynt.calibrate[:calibrate](path_ev, path_calib, rmf_file=rmf_file)
        else
            info("MPcalibrate - $path_ev")
            maltpynt.calibrate[:calibrate](path_ev, path_calib)
        end
    end

    @assert isfile(path_calib) "MP calib files not found, error while generating?"

    path_lc = string(path_mp_out, "nu$(obsid)$(instrument)01_cl_lc.p")

    if isfile(path_lc) && !clobber
        info("Lightcurve files already exist, skipping - $path_ev")
    else
        total_count_rate = MP_calib_total_crate(path_calib)

        if total_count_rate < minimum_count_rate
            warn("Count rate: $total_count_rate/s - too low, aborting!\n")
            return
        else
            info("Count rate: $total_count_rate/s")
        end

        info("MPlcurve - $path_calib")
        maltpynt.lcurve[:lcurve_from_events](path_calib, safe_interval=[100, 300], bintime=bintime)
    end
end

function MP_produce_lc_batch_one(instrument; minimum_count_rate=2,
    local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"], local_utility=ENV["NU_ARCHIVE_UTIL"], procs_to_use=4, todo=16, dry=false)

   numaster_path = string(local_utility, "/numaster_df.csv")

   numaster_df = read_numaster(numaster_path)

   queue = @from i in numaster_df begin
       @where i.RegSrc==1 && i.MP==0
       @select i.obsid
       @collect
   end

   if length(queue) > todo
       queue = queue[1:todo]
   end

   for (i, obsid) in enumerate(queue)
       warn("On $i of $(length(queue))")
       info("Running on $obsid")
       MP_produce_lc_one(obsid, instrument; minimum_count_rate=minimum_count_rate)
       print("\n\n")
   end
end

function MP_produce_cpds_batch(;local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"],
                   local_utility=ENV["NU_ARCHIVE_UTIL"], local_archive_pr=ENV["NU_ARCHIVE_PR"], log_file="", batches=4, to_cal=16, dry=false)

   numaster_path = string(local_utility, "/numaster_df.csv")

   numaster_df = read_numaster(numaster_path)

   queue = @from i in numaster_df begin
       @where i.RegSrc==1 && i.MP==1 && isfile(string(local_archive_pr, i.obsid, "/products/MP/", "nu$(i.obsid)B01_cl_lc.p"))
       @select i.obsid
       @collect
   end

   if length(queue) > to_cal
       queue = queue[1:to_cal]
   else
       to_cal = length(queue)
   end

   batch_remainder = to_cal % batches
   no_rem_cal = to_cal - batch_remainder
   no_rem_batch = Int(no_rem_cal / batches)

   batch_sizes = []

   for batch in 1:batches
       append!(batch_sizes, no_rem_batch)
   end

   for remainder in 1:batch_remainder # Add remainder by one to each batch
       batch_sizes[remainder] += 1
   end

   maltpynt_run = string(Pkg.dir(), "/NuSTAR/src/Scripts/maltpynt_run_cpds.sh")

   @assert isfile(maltpynt_run) "$maltpynt_run not found"

   for i = 1:batches
       l = sum(batch_sizes[1:i]) - (batch_sizes[i] - 1)
       u = sum(batch_sizes[1:i])

       current_queue = queue[l:u]

       if typeof(current_queue) == Array{String,1}
           queue_native = join(current_queue, " ")
       elseif typeof(current_queue) == String
           queue_native = current_queue
       end

       if !dry
           run(`gnome-terminal -e "$maltpynt_run --clean="$(ENV["NU_ARCHIVE_CL"])/" --products="$(ENV["NU_ARCHIVE_PR"])/" --obsids=\"$queue_native\""`)
           info("Calibration started for $queue_native")
       else
           println("gnome-terminal -e \"$maltpynt_run --clean=\"$(ENV["NU_ARCHIVE_CL"])/\" --products=\"$(ENV["NU_ARCHIVE_PR"])/\" --obsids=\"$queue_native\"\"")
       end
   end
end
