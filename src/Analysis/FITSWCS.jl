struct FITS_WCS_Values
    cdelt::Array{Float64}
    ctype::Array{String}
    crpix::Array{Float64}
    crval::Array{Float64}
end

"""
    get_fits_transform(path)

Returns the values required to perform a WCS transform on the pixel data,
giving coordinates in RA and DEC FK5
"""
function gets_fits_transform(path)
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

    return FITS_WCS_Values(cdelt, ctype, crpix, crval)
end

"""
    FITSWCS(path, pixcoords)

Reads FITS at `path`, extracts relevant values for WCS conversion

Takes in array of x and y pixel coordinates in `pixcoords`

Returns array of WCS, FK5, degrees α and δ
"""
function FITSWCS(path, pixcoords; flag_to_world=true)
    fits_transform = gets_fits_transform(path)

    wcs = WCSTransform(2;
                        cdelt = fits_transform.cdelt,
                        ctype = fits_transform.ctype,
                        crpix = fits_transform.crpix,
                        crval = fits_transform.crval)

    if flag_to_world
        return pix_to_world(wcs, float(pixcoords))
    else
        return world_to_pix(wcs, float(pixcoords))
    end
end

"""
    decdeg_to_sxgm(deg)

Converts degrees to sexagesimal hh:mm:ss
"""
function decdeg_to_sxgm(deg)
    sign_flag = deg >= 0
    deg = abs(deg)

    mnt, sec = divrem(deg*3600, 60)
    deg, mnt = divrem(mnt,      60)

    if !sign_flag # If degrees are negative
        deg = -deg
    end

    return deg, mnt, sec
end

function sxgm_to_deg(ra, dec)
    ra_hr, ra_min, ra_sec    = ra

    ra_deg =ra_hr*(15) + ra_min*(1/4) + ra_sec*(1/240)

    dec_hr, dec_min, dec_sec = dec

    if dec_hr < 0
        dec_deg = -(abs(dec_hr) + dec_min*(1/60) + dec_sec*(1/60/60))
    else
        dec_deg = dec_hr + dec_min*(1/60) + dec_sec*(1/60/60)
    end

    return ra_deg, dec_deg
end

"""
    FITSWCS_Delta(path, pixcoords_1, pixcoords_2)

Gives the arcsecond distance between two sets of pixel coordinates

Used during source detection to check the distance between the bounds of the source
if the distance is >> 20 arcseconds, something's probably wrong
"""
function FITSWCS_Delta(coords_1, coords_2; flag_pix=true, path="")
    if flag_pix
        fits_transform = gets_fits_transform(path)

        wcs = WCSTransform(2;
                            cdelt = fits_transform.cdelt,
                            ctype = fits_transform.ctype,
                            crpix = fits_transform.crpix,
                            crval = fits_transform.crval)

        (ra_1, dec_1) = pix_to_world(wcs, float(coords_1))
        (ra_2, dec_2) = pix_to_world(wcs, float(coords_2))
    else
        ra_1, dec_1 = coords_1
        ra_2, dec_2 = coords_2
    end

    cos_law = sind(dec_1)*sind(dec_2) + cosd(dec_1)*cosd(dec_2)*cosd(ra_1-ra_2)

    sxgm = decdeg_to_sxgm(rad2deg(acos(cos_law)))

    arcsec_dist = sxgm[1]*60*60 + sxgm[2]*60 + sxgm[3]

    return arcsec_dist
end
