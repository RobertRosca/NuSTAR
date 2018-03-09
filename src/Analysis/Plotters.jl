function make_plot(obs_path, out_path; log_flag=true, bkg_color=:black)
    det = zeros(Int, 1000, 1000);

    coordinates = FITS_Coords(obs_path);

    for point in 1:size([coordinates[:X] coordinates[:Y]], 1)
        det[coordinates[:Y][point], coordinates[:X][point]] += 1
    end

    if log_flag
        det_plt = log.(det)
        det_plt[det_plt .== -Inf] = 0
    else
        det_plt = det
    end

    first_x = findfirst(sum(det_plt, 1))
    last_x  = 1000 - findfirst(sum(det_plt, 1)[end:-1:1])
    first_y = findfirst(sum(det_plt, 2))
    last_y  = 1000 - findfirst(sum(det_plt, 2)[end:-1:1])

    if bkg_color == :white
        det_plt[det_plt .== 0] = NaN
        bkg_color = :white
    end

    heatmap(1:1000, 1:1000, det_plt, size=(512, 512), legend=false, axis=false, grid=false, c=ColorGradient([:black, :white]), aspect_ratio=:equal, background_color=bkg_color)
    xlims!(first_x, last_x)
    ylims!(first_y, last_y)

    savefig(out_path)
end

function make_plot_src(obs_path, out_path, reg_src_path; log_flag=true, bkg_color=:black)
    path_reg_file = abspath(string(dirname(obs_path), "/../source.reg"))

    f = open(path_reg_file)
    lines = readlines(f)
    close(f)

    lines[end] = replace(lines[end], "circle(", "")
    lines[end] = replace(lines[end], ")", "")
    src_line   = split(lines[end], ",")

    if contains(src_line[1], ":") # asume sxgm
        ra_sxgm  = parse.(Float64, split(src_line[1], ":"))
        dec_sxgm = parse.(Float64, split(src_line[2], ":"))
        ra, dec = sxgm_to_deg(ra_sxgm, dec_sxgm)
    else
        ra  = parse(Float64, src_line[1])
        dec = parse(Float64, src_line[2])
    end

    src_pix_wcs = [ra, dec]
    src_pix_pix = NuSTAR.FITSWCS(obs_path, src_pix_wcs; flag_to_world=false)
    src_radius  = parse(Float64, replace(src_line[3], "\"", ""))*(1/60/60)
    src_radius  = NuSTAR.FITSWCS(obs_path, [src_radius, src_radius]; flag_to_world=false)

    make_plot(obs_path, out_path; log_flag=true, bkg_color=:black)
    plot!([src_pix_pix[1] .+ cos.(0:0.1:2pi).*12], [src_pix_pix[2] .+ sin.(0:0.1:2pi).*12], color=:green) # 30" is about 12 pixels
    #plot!([src_pix_pix[1]], [src_pix_pix[2]], marker=(10, 0.5, :x, :red))

    savefig(out_path)
end
