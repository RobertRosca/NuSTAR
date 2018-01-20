function find_default_path()
    if is_windows()
        return "I:/.nustar_archive", "I:/.nustar_archive_cl"
    elseif is_linux()
        return "/mnt/hgfs/.nustar_archive", "/mnt/hgfs/.nustar_archive_cl"
    else
        error("Unknwon path")
    end
end
