function plot_overview_batch(;batch_size=10000, section_size=(1200, 150), local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
    numaster_df=read_numaster(numaster_path)

    queue = @from i in numaster_df begin
        @where contains(i.LC, "lc_05 lc_0 lc_1 lc_2")
        @select i.obsid
        @collect
    end

    i = 0

    for obsid in queue
        img_path = string(string(local_archive_pr, obsid, "/images/"), "summary_v2.png")
        lc_paths = string.(string(local_archive_pr, obsid, "/products/lc/"), ["lc_05.jld2", "lc_0.jld2", "lc_1.jld2", "lc_2.jld2"])

        newest_lc = maximum(mtime.(lc_paths))
        summary_age = mtime(img_path)

        if summary_age - newest_lc < 0 || overwrite
            println("$obsid - LC newer than image - plotting")
            plot_overview(obsid; section_size=section_size, local_archive_pr=local_archive_pr)
            i += 1
            println(" ")
        else
            continue
        end

        if i >= batch_size
            return
        end
    end
end


function plot_overview_batch_files(;batch_size=10000, section_size=(1200, 150), local_archive_pr=ENV["NU_ARCHIVE_PR"], local_utility=ENV["NU_ARCHIVE_UTIL"], numaster_path=string(local_utility, "/numaster_df.csv"), overwrite=false)
    numaster_df=read_numaster(numaster_path)

    queue = @from i in numaster_df begin
        @where contains(i.LC, "lc_05 lc_0 lc_1 lc_2")
        @select i.obsid
        @collect
    end

    i = 0

    for obsid in queue
        img_path = string(string(local_archive_pr, obsid, "/images/"), "summary_v2.png")
        lc_paths = string.(string(local_archive_pr, obsid, "/products/lc/"), ["lc_05.jld2", "lc_0.jld2", "lc_1.jld2", "lc_2.jld2"])

        newest_lc = maximum(mtime.(lc_paths))
        summary_age = mtime(img_path)

        if summary_age - newest_lc < 0 || overwrite
            println("$obsid - LC newer than image - regenerating files")
            generate_standard_lc_files(obsid; local_archive_pr=ENV["NU_ARCHIVE_PR"], instrument="auto", overwrite=true)
            println("$obsid - LC newer than image - plotting")
            plot_overview(obsid; section_size=section_size, local_archive_pr=local_archive_pr)
            i += 1
            println(" ")
        else
            continue
        end

        if i >= batch_size
            return
        end
    end
end
