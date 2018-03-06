function find_default_path()
    if is_windows()
        return Dict("dir_archive" => "I:/.nustar_archive", "dir_archive_cl" => "I:/.nustar_archive_cl",
            "dir_archive_pr" => "I:/.nustar_archive_pr", "dir_utility" => "I:/.nustar_archive/00000000000 - utility")
    elseif is_linux()
        return Dict("dir_archive" => "/mnt/hgfs/.nustar_archive", "dir_archive_cl" => "/mnt/hgfs/.nustar_archive_cl",
            "dir_archive_pr" => "/mnt/hgfs/.nustar_archive_pr", "dir_utility" => "/mnt/hgfs/.nustar_archive/00000000000 - utility")
    else
        error("Unknwon path")
    end
end
