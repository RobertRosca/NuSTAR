function html_escape(cell)
    if typeof(cell) == Missings.Missing
        return "missing"
    end

    cell = string(cell)

    cell = replace(cell, "&"=>"&amp;")
    cell = replace(cell, "<"=>"&lt;")
    cell = replace(cell, ">"=>"&gt;")
    return cell
end

# NuSTAR.WebGen(filename="/home/robert/Scratch/WebApps/NuSTAR-WebView/NuSTAR-WebView.html", homedev=true, subpage_gen=true)

function WebGen(;filename="/home/robertr/public_html/index.html", df=load_numaster(), select_cols=[:observation_mode, :spacecraft_mode, :slew_mode, :prnb, :category_code, :priority, :cycle, :obs_type, :issue_flag, :status, :Downloaded, :Cleaned, :ValidSci, :RegSrc, :RegBkg], shown_cols=[:name, :obsid, :Downloaded, :Cleaned, :ValidSci, :RegSrc, :obs_type, :category_code, :Interesting], blacklist_cols=[:abstract, :pi_lname, :pi_fname, :copi_lname, :copi_fname, :country], whitelist_cols=[], list_choice="whitelist", homedev=false, local_archive_pr=ENV["NU_ARCHIVE_PR"], subpage_gen=true)
    if length(whitelist_cols) == 0
        whitelist_cols = vcat(shown_cols, [:public_date, :obs_type, :observation_mode, :RegBkg])
    end

    if list_choice == "blacklist"
        df = df[:, filter(x->!(x in blacklist_cols), names(df))]
    elseif list_choice == "whitelist"
        df = df[:, filter(x->(x in whitelist_cols), names(df))]
    end

    category_dict = Dict(0=>"Non-Pointing", 1=>"Calibration", 2=>"Solar System", 3=>"Galactic Compact", 4=>"Supernovae/Galactic Diffuse",
    5=>"Normal Galaxies", 6=>"Active Galaxies/Quasars", 7=>"Galaxy Clusters/Extragalactic Diffuse", 8=>"Proposed ToOs", 9=>"Non-proposal ToOs")

    gnr_c = 0
    @from i in df begin
        @where DateTime(i.public_date)<Base.Dates.today() && i.obs_type!="CAL" && i.observation_mode=="SCIENCE"
        @select gnr_c += 1
        @collect
    end

    df_summary = DataFrame(
        Total=size(df, 1),
        GoodPublic=gnr_c,
        Downloaded=count(x->x==1, df[:Downloaded]),
        Calibrated=count(x->x==1, df[:Cleaned]),
        ValidScience=count(x->x==1, df[:ValidSci]),
        RegSrcDone=count(x->x==1, df[:RegSrc]),
        RegSrcIntr=count(x->x==2, df[:RegSrc]),
        RegSrcBad=count(x->x==-1, df[:RegSrc]),
        RegSrcCheck=count(x->x==-2, df[:RegSrc]),
        InterestingLC=count(x->x!="NA"&&x!="No", df[:Interesting]))

    f = open(filename, "w")

    file_path = abspath(filename)
    file_dir = dirname(file_path)
    file_dir_web = "."

    if homedev
        file_dir_web = file_dir
    end

    # Head
    write(f, "<!DOCTYPE html>\n")
    write(f, "<html class=\"no-js\">\n")
    write(f, "<head>\n")
    write(f, "\t<title>NuSTAR.jl Web View</title>\n")
    write(f, "\t<meta charset=\"utf-8\">\n\n")
    write(f, "\t<link rel=\"stylesheet\" href=\"./assets/bootstrap/css/bootstrap.min.css\">\n")
    write(f, "\t<link rel=\"stylesheet\" href=\"./assets/bootstrap-table/src/bootstrap-table.css\">\n")
    write(f, "\t<link rel=\"stylesheet\" href=\"./assets/bootstrap-table/src/extensions/sticky-header/bootstrap-table-sticky-header.css\">\n")
    write(f, "\t<link rel=\"stylesheet\" href=\"./assets/examples.css\">\n")
    write(f, "\t<script src=\"./assets/jquery.min.js\"></script>\n")
    write(f, "\t<script src=\"./assets/bootstrap/js/bootstrap.min.js\"></script>\n")
    write(f, "\t<script src=\"./assets/bootstrap-table/src/bootstrap-table.js\"></script>\n")
    write(f, "\t<script src=\"./assets/bootstrap-table/src/extensions/filter-control/bootstrap-table-filter-control.js\"></script>\n\n")

    write(f, "\t<style>\n")
    write(f, "\t.no-js #loader { display: none;  }\n")
    write(f, "\t.js #loader { display: block; position: absolute; left: 100px; top: 0; }\n")
    write(f, "\t.se-pre-con {\n")
    write(f, "\t\tposition: fixed;\n")
    write(f, "\t\tleft: 0px;\n")
    write(f, "\t\ttop: 0px;\n")
    write(f, "\t\twidth: 100%;\n")
    write(f, "\t\theight: 100%;\n")
    write(f, "\t\tz-index: 9999;\n")
    write(f, "\t\tbackground: center no-repeat #fff;\n") # url(assets/loading.gif)
    write(f, "\t}\n")
    write(f, "\t.table-success {\n")
    write(f, "\t\tbackground-color: #c3e6cb;\n")
    write(f, "\t}\n")
    write(f, "\t.table-failure {\n")
    write(f, "\t\tbackground-color: #f5c6cb;\n")
    write(f, "\t}\n")
    write(f, "\t.table-info {\n")
    write(f, "\t\tbackground-color: #bee5eb;\n")
    write(f, "\t}\n")
    write(f, "\t.table-warn {\n")
    write(f, "\t\tbackground-color: #ffeeba;\n")
    write(f, "\t}\n")
    write(f, "\t</style>\n\n")

    write(f, "\t<script>\n")
    write(f, "\t\t\$(window).load(function() {\n")
    write(f, "\t\t\t\$(\".se-pre-con\").fadeOut(\"slow\");;\n")
    write(f, "\t\t});\n")
    write(f, "\t</script>\n")

    write(f, "</head>\n")

    # Body
    write(f, "<body>\n")
    write(f, "\t<div class=\"se-pre-con\"></div>\n")
    write(f, "\t<div class=\"container\">\n")
    write(f, "\t<h1>NuSTAR.jl WebView</h1>\n")
    write(f, "\t<p>Table of the current local Numaster catalog, run `NuSTAR.Numaster()` to update</p>\n")
    write(f, "\t<p>Mixing filters, search, and ordering, doesn't work too well currently. Doing basic things should work fine-ish though.</p>\n")
    write(f, "\t<p>Page might take a while to fully load since the table is quite large.</p>\n")

    write(f, "\t<hr>\n")

    # Summary
    write(f, "\t<h2>Summary</h2>\n")

    make_table(f, df_summary; table_id="summary-table", data_show_columns="false", data_filter_control="true", data_filter_show_clear="false", data_pagination="false", data_sort_stable="false")

    write(f, "\t<hr>\n")

    # Table
    write(f, "\t<table id=\"table\"\n\t\t\tdata-show-columns=\"true\"\n\t\t\tdata-toggle=\"table\"\n\t\t\tdata-filter-control=\"true\"\n\t\t\tdata-filter-show-clear=\"true\"\n\t\t\tdata-pagination=\"true\"\n\t\t\tdata-page-size=\"100\"\n\t\t\tdata-page-list=\"[100, 500, 5000]\"\n\t\t\tdata-sort-name=\"Interesting\"\n\t\t\tdata-sort-order=\"desc\"\n\t\t\tdata-sort-stable=\"true\">\n")

    cnames = names(df)

    write(f, "\t\t<thead>\n")
    write(f, "\t\t\t<tr>\n")
    for column_name in cnames
        column_name in select_cols ? input_type="select" : input_type="input"
        column_name in shown_cols ? visible="true" : visible="false"
        write(f, "\t\t\t\t<th data-sortable=\"true\" data-field=\"$column_name\" data-filter-control=\"$input_type\" data-visible=\"$visible\">$column_name</th>\n")
    end
    write(f, "\t\t\t</tr>\n")
    write(f, "\t\t</thead>\n")

    write(f, "\t\t<tbody>\n")

    n = size(df, 1)

    mxrow = n

    for row in 1:mxrow
        obsid = df[row, :obsid]
        df[row, :Downloaded] == 1 ? color_downloaded="table-success" : color_downloaded=""
        df[row, :Cleaned] == 1 ? color_cleaned="table-success" : color_cleaned=""
        df[row, :ValidSci] == 1 ? color_validsci="table-success" : color_validsci=""
        df[row, :RegBkg] == 1 ? color_bkg="table-success" : color_bkg=""
        df[row, :Interesting] != "NA" ? color_lcflg="table-success" : color_lcflg=""
        df[row, :Interesting] == "No" ? color_lcflg="table-failure" : color_lcflg=color_lcflg
        color_regsrc = ["table-warn", "table-failure", "", "table-success", "table-info"][3+df[row, :RegSrc]]

        write(f, "\t\t\t<tr>\n")

        for column_name in cnames
            cell = df[row, column_name]
            if column_name == :Downloaded
                write(f, "\t\t\t\t<td class=\"$color_downloaded\">$(html_escape(cell))</td>\n")
            elseif column_name == :Cleaned
                write(f, "\t\t\t\t<td class=\"$color_cleaned\">$(html_escape(cell))</td>\n")
            elseif column_name == :RegSrc
                write(f, "\t\t\t\t<td class=\"$color_regsrc\">$(html_escape(cell))</td>\n")
            elseif column_name == :ValidSci
                write(f, "\t\t\t\t<td class=\"$color_validsci\">$(html_escape(cell))</td>\n")
            elseif column_name == :RegBkg
                write(f, "\t\t\t\t<td class=\"$color_bkg\">$(html_escape(cell))</td>\n")
            elseif column_name == :Interesting
                write(f, "\t\t\t\t<td class=\"$color_lcflg\">$(html_escape(cell=="NA" ? "" : cell))</td>\n")
            elseif column_name == :obsid
                write(f, "\t\t\t\t<td><a href=\"$file_dir_web/obs/$obsid/details.html\" target=\"_blank\">$(html_escape(cell))</a></td>\n")
            elseif column_name == :category_code
                write(f, "\t\t\t\t<td>$(html_escape(category_dict[cell]))</td>\n")
            else
                write(f, "\t\t\t\t<td>$(html_escape(cell))</td>\n")
            end
        end
        write(f, "\t\t\t</tr>\n")
    end
    if n > mxrow
        write(f, "\t\t\t<tr>\n")
        write(f, "\t\t\t\t<th>&vellip;</th>\n")
        for column_name in cnames
            write(f, "\t\t\t\t<td>&vellip;</td>\n")
        end
        write(f, "\t\t\t</tr>\n")
    end
    write(f, "\t\t</tbody>\n")
    write(f, "\t</table>\n")

    write(f, "</body>")

    close(f)

    info("Saved to: $file_path")

    if subpage_gen
        info("Generating subpages")

        WebGen_subpages(;folder_path=file_dir, df=load_numaster(),
            hidden_cols=[:abstract, :name, :obsid, :comments, :title, :subject_category], local_archive_pr=local_archive_pr)
    end

    info("Done")
end

function WebGen_subpages(;folder_path="/home/robertr/public_html/", df=load_numaster(),
    hidden_cols=[:abstract, :name, :obsid, :comments, :title, :subject_category], local_archive_pr=ENV["NU_ARCHIVE_PR"])
    if !isdir("$folder_path/obs/")
        mkdir("$folder_path/obs/")
    end

    obsid_list = parse.(Int, df[:obsid])
    obsid_list = obsid_list[df[:EVT].!="NA"]
    sort!(obsid_list)

    obsid_list_rev = obsid_list[end:-1:1]

    for i in 1:size(df, 1)
        if !isdir("$folder_path/obs/$(df[i, :obsid])")
            mkdir("$folder_path/obs/$(df[i, :obsid])")
        end
        obsid = "$(df[i, :obsid])"
        filename = "$folder_path/obs/$obsid/details.html"

        f = open(filename, "w")

        file_path = abspath(filename)
        file_dir  = dirname(file_path)

        # Head
        write(f, "<!DOCTYPE html>\n")
        write(f, "<html class=\"no-js\">\n")
        write(f, "<head>\n")
        write(f, "\t<title>$obsid</title>\n")
        write(f, "\t<meta charset=\"utf-8\">\n\n")
        write(f, "\t<link rel=\"stylesheet\" href=\"../../assets/bootstrap/css/bootstrap.min.css\">\n")
        write(f, "\t<link rel=\"stylesheet\" href=\"../../assets/bootstrap-table/src/bootstrap-table.css\">\n")
        write(f, "\t<link rel=\"stylesheet\" href=\"../../assets/flex.css\">\n")
        write(f, "\t<script src=\"../../assets/jquery.min.js\"></script>\n")
        write(f, "\t<script src=\"../../assets/bootstrap/js/bootstrap.min.js\"></script>\n")
        write(f, "\t<script src=\"../../assets/bootstrap-table/src/bootstrap-table.js\"></script>\n")

        write(f, "\t<script>\n")
        write(f, "\tfunction copyObsid() {\n")
        write(f, "\t\tvar copyText = document.getElementById(\"obsidInput\");;\n")
        write(f, "\t\tcopyText.select();\n")
        write(f, "\t\tdocument.execCommand(\"Copy\");\n")
        write(f, "\t}\n")
        write(f, "\t</script>\n")

        write(f, "</head>\n")

        # Body
        write(f, "<body>\n")
        write(f, "\t<div class=\"container\">\n")
        write(f, "\t<h1>Observation $obsid - $(df[i, :name])</h1>\n")
        write(f, "\t<hr>\n")
        write(f, "\t<h2>Abstract</h2>\n")
        write(f, "\t<h4>$(df[i, :subject_category]) - $(df[i, :title])</h4>\n")
        write(f, "\t<div class=\"flex-container\">\n")
        write(f, "\t\t<div><img src=\"./images/evt_uf.png\" alt=\"evt_uf\" width=\"256\" height=\"256\"></div>\n")
        !isdir("$local_archive_pr$obsid/images/") ? mkpath("$local_archive_pr$obsid/images/") : ""
        !islink("$file_dir/images") ? symlink("$local_archive_pr$obsid/images/", "$file_dir/images") : ""
        write(f, "\t\t<div><img src=\"./images/evt_cl.png\" alt=\"evt_cl\" width=\"256\" height=\"256\"></div>\n")
        write(f, "\t\t<div><p>$(df[i, :abstract])</p></div>\n")
        write(f, "\t</div>\n")
        write(f, "\t<hr>\n")
        write(f, "\t<h4>Status</h4>\n")
        make_table(f, df[i, :]; something_list_cols=[:public_date, :status, :caldb_version, :Downloaded, :Cleaned, :ValidSci, :RegSrc,  :RegBkg, :Interesting], list_choice="whitelist", data_filter_show_clear="false", data_show_columns="false", data_filter_control="false", data_pagination="false")
        write(f, "\t<hr>\n")
        write(f, "\t<h4>Source Details</h4>\n")
        make_table(f, df[i, :]; something_list_cols=[:name, :obs_type, :ra, :dec, :lii, :bii], list_choice="whitelist", data_filter_show_clear="false", data_show_columns="false", data_filter_control="false", data_pagination="false")
        write(f, "\t<hr>\n")
        write(f, "\t<h4>Observation Details</h4>\n")
        make_table(f, df[i, :]; something_list_cols=[:time, :end_time, :exposure_a, :exposure_b, :ontime_a, :ontime_b], list_choice="whitelist", data_filter_show_clear="false", data_show_columns="false", data_filter_control="false", data_pagination="false")
        write(f, "\t<hr>\n")
        write(f, "\t<h4>Instrument Details</h4>\n")
        make_table(f, df[i, :]; something_list_cols=[:spacecraft_mode, :instrument_mode, :observation_mode, :slew_mode, :solar_activity, :issue_flag], list_choice="whitelist", data_filter_show_clear="false", data_show_columns="false", data_filter_control="false", data_pagination="false")

        write(f, "\t<hr>\n")
        write(f, "\t<h4>Comments</h4>\n")
        write(f, "\t<p>$(df[i, :comments])</p>\n")
        
        write(f, "\t<hr>\n")
        write(f, "\t<input type=\"text\" value=\"$obsid\" id=\"obsidInput\" readonly>\n")
        write(f, "\t<button onclick=\"copyObsid()\">Copy obsid</button>\n")

        next_idx = findfirst(obsid_list_rev.<parse(Int, obsid))
        if next_idx > 0
            prev_obsid_with_plot = obsid_list_rev[next_idx]
            write(f, "\t<a href=\"http://asimov.phys.soton.ac.uk/~robertr/obs/$prev_obsid_with_plot/details.html\">\n")
            write(f, "\t\t<button>Previous obs (with plot)</button>\n")
            write(f, "\t</a>\n")
        end

        prev_idx = findfirst(obsid_list.>parse(Int, obsid))
        if prev_idx > 0
            next_obsid_with_plot = obsid_list[prev_idx]
            write(f, "\t<a href=\"http://asimov.phys.soton.ac.uk/~robertr/obs/$next_obsid_with_plot/details.html\">\n")
            write(f, "\t\t<button>Next obs (with plot)</button>\n")
            write(f, "\t</a>\n")
        end

        interesting_file = string("$local_archive_pr$obsid/interesting_comment.txt")
        if isfile(interesting_file)
            write(f, "\t<hr>\n")
            write(f, "\t<p>$(join(readlines(interesting_file), "<br>"))</p>\n")
        end

        img_dir = "$file_dir/images/"

        if isdir(img_dir)
            img_contents = readdir(img_dir)
            img_lc_dir = string(img_dir, "/lc/")

            if isfile("$img_dir/summary.png")
                write(f, "\t<hr>\n")
                write(f, "\t\t<h4>Lightcurves</h4>\n")
                write(f, "\t\t\t<div><img src=\"./images/summary.png\" alt=\"summary\" width=\"100%\"></div>\n")
            end

            if isdir(img_lc_dir) && false
                lc_folders = readdir(img_lc_dir)

                for lc_folder in sort(lc_folders, lt=natural)
                    if length(readdir("$file_dir/images/lc/$lc_folder/")) > 0
                        make_lc(f, file_dir, lc_folder)
                        write(f, "\t<hr>\n")
                        write(f, "\t<br>\n")
                    end
                end
            end
        end

        write(f, "</body>")

        close(f)
    end
end

function make_lc(f, file_dir, lc_folder)
    lc_path = "$file_dir/images/lc/$lc_folder/"
    lc_plts = sort(readdir(lc_path), lt=natural)

    write(f, "<p><b>$lc_folder</b> - Found $(size(lc_plts, 1)-1) generated lightcurve</p>")
    write(f, "\t\t\t<div><img src=\"./images/lc/$lc_folder/$(lc_plts[1])\" alt=\"evt_uf\" width=\"100%\"></div>\n")

    write(f, "<div class=\"panel-group\">")
    write(f, "<div class=\"panel panel-default\">")
    write(f, "<div class=\"panel-heading\">")
    write(f, "<h4 class=\"panel-title\">")
    write(f, "<a data-toggle=\"collapse\" href=\"#$(replace(lc_folder, ".", "_"))\">Lightcurve - $lc_folder</a>")
    write(f, "</h4>")
    write(f, "</div>")
    write(f, "<div id=\"$(replace(lc_folder, ".", "_"))\" class=\"panel-collapse collapse\">")
    write(f, "<div class=\"panel-body\">")
    for plt in lc_plts[2:end]
        write(f, "<hr>")
        write(f, "\t\t\t<div><img src=\"./images/lc/$lc_folder/$plt\" alt=\"evt_uf\" width=\"100%\"></div>\n")
    end
    write(f, "</div>")
    write(f, "<div class=\"panel-footer\"><a data-toggle=\"collapse\" href=\"#$(replace(lc_folder, ".", "_"))\">Collapse - $lc_folder</a></div>")
    write(f, "</div>")

    write(f, "\t</div>\n")
end

function make_table(f, df; table_id="", hidden_cols=[], select_cols=[], shown_cols=[], something_list_cols=[], list_choice="blacklist", data_show_columns="true", data_toggle="table", data_filter_control="true", data_filter_show_clear="true", data_pagination="true", data_page_size="100", data_page_list="[100, 500, 5000]", data_sort_name="Downloaded", data_sort_order="desc", data_sort_stable="true")
    if list_choice == "blacklist"
        df = df[:, filter(x->!(x in something_list_cols), names(df))]
    elseif list_choice == "whitelist"
        df = df[:, filter(x->(x in something_list_cols), names(df))]
    end

    write(f, "\t<table id=\"$table_id\"\n\t\t\tdata-show-columns=\"$data_show_columns\"\n\t\t\tdata-toggle=\"$data_toggle\"\n\t\t\tdata-filter-control=\"$data_filter_control\"\n\t\t\tdata-filter-show-clear=\"$data_filter_show_clear\"\n\t\t\tdata-pagination=\"$data_pagination\"\n\t\t\tdata-page-size=\"$data_page_size\"\n\t\t\tdata-page-list=\"$data_page_list\"\n\t\t\tdata-sort-name=\"$data_sort_name\"\n\t\t\tdata-sort-order=\"$data_sort_order\"\n\t\t\tdata-sort-stable=\"$data_sort_stable\">\n")

    cnames = names(df)

    write(f, "\t\t<thead>\n")
    write(f, "\t\t\t<tr>\n")
    for column_name in cnames
        column_name in hidden_cols ? visible="false" : visible="true"
        write(f, "\t\t\t\t<th data-sortable=\"false\" data-field=\"$column_name\" data-visible=\"$visible\">$column_name</th>\n")
    end
    write(f, "\t\t\t</tr>\n")
    write(f, "\t\t</thead>\n")

    write(f, "\t\t<tbody>\n")

    n = size(df, 1)

    mxrow = n

    for row in 1:mxrow
        write(f, "\t\t\t<tr>\n")
        #write(f, "<th>$row</th>\n")data-filter-control=\"input\"
        for column_name in cnames
            cell = df[row, column_name]
            write(f, "\t\t\t\t<td>$(html_escape(cell))</td>\n")
        end
        write(f, "\t\t\t</tr>\n")
    end
    if n > mxrow
        write(f, "\t\t\t<tr>\n")
        write(f, "\t\t\t\t<th>&vellip;</th>\n")
        for column_name in cnames
            write(f, "\t\t\t\t<td>&vellip;</td>\n")
        end
        write(f, "\t\t\t</tr>\n")
    end
    write(f, "\t\t</tbody>\n")
    write(f, "\t</table>\n")
end
