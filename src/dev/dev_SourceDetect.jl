using FITSIO
using WCS
using DataFrames

path = "/mnt/hgfs/.nustar_archive_cl/30202002002/pipeline_out/nu30202002002A01_cl.evt"

pixcoords = [501.0;  # x coordinates
             501.0]  # y coordinates

"""
    FITSWCS(path, pixcoords)

Reads FITS at `path`, extracts relevant values for WCS conversion

Takes in array of x and y pixel coordinates in `pixcoords`

Returns array of WCS, FK5, degrees α and δ
"""
function FITSWCS(path, pixcoords)
    file = FITS(path)

    header_image = read_header(file[2])
    header_keys  = keys(header_image)

    # Keys used during WCS transform:
    # cdelt -> [TCDLT'X' TCDLT'Y']
    # ctype -> [TCTYP'X' TCTYP'Y']
    # crpix -> [TCRPX'X' TCRPX'Y']
    # crval -> [TCRVL'X' TCRVL'Y']
    # pv    -> coordinates being converted...?

    keys_useful = []

    # To select the useful key types
    # for ALL COORDINATES (DET1, DET2, etc... and desired declination/right ascension)
    for key in header_keys
        if length(key) >= 5
            if key[1:5] in ["TCDLT" "TCTYP" "TCRPX" "TCRVL" "TCNULL"]
                append!(keys_useful, [key])
            end
        end
    end

    # Now that ALL keys have been found, select the ones corresponding to dec/ra
    # to find the key numbers
    keys_radec = []
    for key in keys_useful
        if header_image[key] == "DEC--TAN"
            append!(keys_radec, [key])
        elseif header_image[key] == "RA---TAN"
            append!(keys_radec, [key])
        end
    end

    @assert length(keys_radec) == 2 "Incorrect number of keys found"

    # Keys ending in these numbers correspond to the desired degree units
    keys_radec_id = replace.(keys_radec, "TCTYP", "")

    # In the next part we assume that the key id has TWO DIGITS, which seems to always be true
    # check here anyway
    @assert !(false in [parse.(Int, keys_radec_id) .>= 10]) "Key ID under two digits"

    keys_selected = []
    for key in keys_useful
        if key[end-1:end] in keys_radec_id # Select just keys ending in the key nunber
            append!(keys_selected, [key])
        end
    end

    # Set up the transform
    cdelt = [header_image[string("TCDLT", keys_radec_id[1])], header_image[string("TCDLT", keys_radec_id[2])]]
    ctype = [header_image[string("TCTYP", keys_radec_id[1])], header_image[string("TCTYP", keys_radec_id[2])]]
    crpix = [header_image[string("TCRPX", keys_radec_id[1])], header_image[string("TCRPX", keys_radec_id[2])]]
    crval = [header_image[string("TCRVL", keys_radec_id[1])], header_image[string("TCRVL", keys_radec_id[2])]]

    wcs = WCSTransform(2;
                        cdelt = cdelt,
                        ctype = ctype,
                        crpix = crpix,
                        crval = crval)

    pix_to_world(wcs, pixcoords)
end
