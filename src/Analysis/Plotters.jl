function make_plot(obs_path::String, out_path::String; log_flag=true, background_white=false)
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

    if background_white
        det_plt[det_plt .== 0] = NaN
    end

    heatmap(1:1000, 1:1000, det_plt, size=(512, 512), legend=false, axis=false, grid=false, c=ColorGradient([:black, :white]), aspect_ratio=:equal)
    xlims!(first_x, last_x)
    ylims!(first_y, last_y)

    savefig(out_path)

    return
end
