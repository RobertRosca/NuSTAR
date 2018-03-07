function WebGen(;filename="/home/robertr/public_html/index.html", df="", select_cols=[:observation_mode, :spacecraft_mode, :slew_mode, :prnb, :category_code, :priority, :cycle, :obs_type, :issue_flag, :status, :Downloaded, :Cleaned, :ValidSci, :RegSrc, :RegBkg], shown_cols=[:name, :obsid, :Downloaded, :Cleaned, :ValidSci, :RegSrc, :RegBkg])
    if df == ""
        df = load_numaster()
    end

    df = df[:, filter(x->!(x in [:abstract]), names(df))]
    f = open(filename, "w")

    # Head
    write(f, "<!DOCTYPE html>\n")
    write(f, "<html>\n")
    write(f, "<head>\n")
    write(f, "\t <title>NuSTAR.jl WebView</title>\n")
    write(f, "\t <meta charset=\"utf-8\">\n")
    write(f, "\t <link rel=\"stylesheet\" href=\"./assets/bootstrap/css/bootstrap.min.css\">\n")
    write(f, "\t <link rel=\"stylesheet\" href=\"./assets/bootstrap-table/src/bootstrap-table.css\">\n")
    write(f, "\t <link rel=\"stylesheet\" href=\"./assets/bootstrap-table/src/extensions/sticky-header/bootstrap-table-sticky-header.css\">\n")
    write(f, "\t <link rel=\"stylesheet\" href=\"./assets/examples.css\">\n")
    write(f, "\t <script src=\"./assets/jquery.min.js\"></script>\n")
    write(f, "\t <script src=\"./assets/bootstrap/js/bootstrap.min.js\"></script>\n")
    write(f, "\t <script src=\"./assets/bootstrap-table/src/bootstrap-table.js\"></script>\n")
    write(f, "\t <script src=\"./assets/bootstrap-table/src/extensions/filter-control/bootstrap-table-filter-control.js\"></script>\n")
    write(f, "</head>\n")

    # Body
    write(f, "<body>\n")
    write(f, "\t<div class=\"container\">\n")
    write(f, "\t<h1>NuSTAR.jl WebView</h1>\n")
    write(f, "\t<p>Web view of current local Numaster table.</p>\n")
    write(f, "\t<hr>\n")

    # Table
    write(f, "\t<table id=\"table\"\n\t\t\t data-show-columns=\"true\"\n\t\t\t data-toggle=\"table\"\n\t\t\t data-filter-control=\"true\"\n\t\t\t data-filter-show-clear=\"true\"\n\t\t\t data-pagination=\"true\"\n\t\t\t data-page-size=\"100\"\n\t\t\t data-page-list=\"[100, 500, 5000]\"\n\t\t\t data-sort-name=\"Downloaded\"\n\t\t\t data-sort-order=\"desc\"\n\t\t\t data-sort-stable=\"true\">\n")

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

    write(f, "</body>")

    close(f)
end

function html_escape(cell)
    if typeof(cell) == Missings.Missing
        return "missing"
    end

    cell = string(cell)

    cell = replace(cell, "&"=>"&amp;")
    cell = replace(cell, "<"=>"&lt;")
    cell = replace(cell, ">"=>"&gt;")
    return cell
endC
