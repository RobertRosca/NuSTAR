# ds9 nu302002004A01_cl.evt -scale log -geometry 512x770 -export png image.png -exit

function ds9_make_img(;local_archive=ENV["NU_ARCHIVE"], local_archive_cl=ENV["NU_ARCHIVE_CL"], local_utility=ENV["NU_ARCHIVE_UTIL"], local_archive_pr=ENV["NU_ARCHIVE_PR"], regions=[])

    numaster_path = string(local_utility, "/numaster_df.csv")

    numaster_df = read_numaster(numaster_path)

    queue_uf = @from i in numaster_df begin
        @where i.Downloaded==1

        @select string("", local_archive, i.obsid, "/event_uf/nu", i.obsid, "A_uf.evt.gz",
        " -scale log -geometry 512x770",
        " -export png ", local_archive_pr, i.obsid, "/images/event_uf.png",
        " -exit")
        @collect
    end

    queue_cl = @from i in numaster_df begin
        @where i.Cleaned==1&&i.RegSrc!=1
        @select string("", local_archive_cl, i.obsid, "/pipeline_out/nu", i.obsid, "A01_cl.evt",
        " -scale log -geometry 512x770",
        " -export png ", local_archive_pr, i.obsid, "/images/event_cl.png",
        " -exit")
        @collect
    end

    queue_cl_src = @from i in numaster_df begin
        @where i.Cleaned==1&&i.RegSrc==1&&i.RegBkg==1
        @select string("", local_archive_cl, i.obsid, "/pipeline_out/nu", i.obsid, "A01_cl.evt",
        " -regions ", local_archive_cl, i.obsid, "/source.reg ",
        " -regions ", local_archive_cl, i.obsid, "/background.reg",
        " -scale log -geometry 512x770",
        " -export png ", local_archive_pr, i.obsid, "/images/event_cl.png",
        " -exit")
        @collect
    end

    for ds9_call in vcat(queue_uf, queue_cl)[1:2]
        img_path = abspath(split(ds9_call)[end-1])
        img_dir = dirname(abspath(split(ds9_call)[end-1]))

        if !isdir(img_dir)
            mkpath(img_dir)
        end

        if isfile(img_path)
            continue
        end

        run(`ds9 $ds9_call`)

        info("Created: $img_path")
    end

    for ds9_call in queue_cl_src[1:2] # Source-region images need to check the age of the regionfiles
        img_path = abspath(split(ds9_call)[end-1])
        img_dir  = dirname(abspath(split(ds9_call)[end-1]))
        reg_src_path = abspath(split(ds9_call)[end-10])
        reg_bkg_path = abspath(split(ds9_call)[end-8])

        if !isdir(img_dir)
            mkpath(img_dir)
        end

        if isfile(img_path)
            reg_src_maketime = stat(reg_src_path).mtime
            reg_bkg_maketime = stat(reg_bkg_path).mtime

            reg_src_maketime >= reg_bkg_maketime? oldest = reg_bkg_maketime : oldest = reg_src_maketime

            image_maketime = stat(img_path).mtime

            if image_maketime - reg_src_maketime > 0 # image newer than source1
                info("Image newer than source, skipped")
                continue
            end
        end

        run(`ds9 $ds9_call`)

        info("Created: $img_path")
    end
end
