function DataFrame_save_table(filename, df)
    #df = df[:, filter(x->x in [:name, :obsid, :Downloaded, :Cleaned], names(df))]
    f = open(filename, "w")

    cnames = names(df)
    write(f, "<table class=\"sortable\" cellpadding=\"10\">\n")
    write(f, "<thead>\n")
    write(f, "<tr>\n")
    #write(f, "<th></th>\n")
    for column_name in cnames
        write(f, "<th>$column_name</th>\n")
    end
    write(f, "</tr>\n")
    write(f, "</thead>\n")
    write(f, "<tbody>\n")

    n = size(df, 1)

    mxrow = n

    for row in 1:mxrow
        write(f, "<tr>\n")
        #write(f, "<th>$row</th>\n")
        for column_name in cnames
            cell = df[row, column_name]
            write(f, "<td>$(html_escape(cell))</td>\n")
        end
        write(f, "</tr>\n")
    end
    if n > mxrow
        write(f, "<tr>\n")
        write(f, "<th>&vellip;</th>\n")
        for column_name in cnames
            write(f, "<td>&vellip;</td>\n")
        end
        write(f, "</tr>\n")
    end
    write(f, "</tbody>\n")
    write(f, "</table>\n")

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
end
