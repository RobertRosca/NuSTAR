# ds9 nu302002004A01_cl.evt -scale log -geometry 512x770 -export png image.png -exit

function make_img_ds9_uf(;local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"], local_utility=ENV["NU_ARCHIVE_UTIL"], local_archive_pr=ENV["NU_ARCHIVE_PR"], regions=[], debug=false)

    numaster_path = string(local_utility, "/numaster_df.csv")

    numaster_df = read_numaster(numaster_path)

    queue_uf = @from i in numaster_df begin
        @where i.Downloaded==1

        @select string("", local_archive, i.obsid, "/event_uf/nu", i.obsid, "A_uf.evt.gz",
        " -scale log -geometry 512x770",
        " -export png ", local_archive_pr, i.obsid, "/images/evt_uf.png",
        " -exit")
        @collect
    end

    ds9_queue_filename = string(local_utility, "/ds9_queue.sh")
    # 0755 is equiv to chmod +x

    f = open(ds9_queue_filename, "w")

    if length(queue_uf) > 0
        for ds9_call in queue_uf
            img_path = abspath(split(ds9_call)[end-1])
            img_dir = dirname(abspath(split(ds9_call)[end-1]))

            if !isdir(img_dir)
                mkpath(img_dir)
            end

            if isfile(img_path)
                continue
            end

            if debug
                println("ds9 $ds9_call")
            else
                write(f, "ds9 $ds9_call\n")
            end
        end
    end

    close(f)
    return
end

function make_img_plt_cl(;local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"], local_utility=ENV["NU_ARCHIVE_UTIL"], local_archive_pr=ENV["NU_ARCHIVE_PR"], debug=false, overwrite=false, queues="both")

    numaster_path = string(local_utility, "/numaster_df.csv")

    numaster_df = read_numaster(numaster_path)

    if queues=="both" || queues=="no_reg"
        queue_cl = @from i in numaster_df begin
            @where i.Cleaned==1&&i.RegSrc!=1&&i.ValidSci==1
            @select i.obsid
            @collect
        end
    end

    if length(queue_cl) > 0
        for obsid in queue_cl
            obs_path = string(local_archive_cl, obsid, "/pipeline_out/nu", obsid, "A01_cl.evt")
            img_path = string(local_archive_pr, obsid, "/images/evt_cl.png")
            img_dir  = dirname(img_path)

            if !isdir(img_dir)
                mkpath(img_dir)
            end

            if isfile(img_path) && !overwrite
                continue
            end

            if debug
                println("$obs_path - $img_path")
            else
                info("Plotting $img_path")
                make_plot(obs_path, img_path)
            end
        end
    end

    if queues=="both" || queues=="reg"
        queue_cl_src = @from i in numaster_df begin
            @where i.Cleaned==1&&i.RegSrc==1
            @select i.obsid
            @collect
        end
    end

    if length(queue_cl_src) > 0
        for obsid in queue_cl_src # Source-region images need to check the age of the regionfiles
            obs_path = string(local_archive_cl, obsid, "/pipeline_out/nu", obsid, "A01_cl.evt")
            reg_src_path = string(local_archive_cl, obsid, "/source.reg")
            img_path = string(local_archive_pr, obsid, "/images/evt_cl.png")
            img_dir  = dirname(img_path)

            if !isdir(img_dir)
                mkpath(img_dir)
            end

            if isfile(img_path) && !overwrite
                reg_src_maketime = stat(reg_src_path).mtime

                image_maketime = stat(img_path).mtime

                if image_maketime - reg_src_maketime > 0 # image newer than source1
                    info("$obsid image newer than source, skipped")
                    continue
                end
            end

            if debug
                println("$obs_path - $img_path - $reg_src_path\n")
            else
                info("Plotting $img_path")
                make_plot_src(obs_path, img_path, reg_src_path)
            end
        end
    end
end
