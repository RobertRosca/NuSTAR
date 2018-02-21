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
function FITSWCS(path, pixcoords)
    fits_transform = gets_fits_transform(path)

    wcs = WCSTransform(2;
                        cdelt = fits_transform.cdelt,
                        ctype = fits_transform.ctype,
                        crpix = fits_transform.crpix,
                        crval = fits_transform.crval)

    pix_to_world(wcs, float(pixcoords))
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

"""
    FITSWCS_Delta(path, pixcoords_1, pixcoords_2)

Gives the arcsecond distance (ra, dec) between two sets of pixel coordinates

Used during source detection to check the distance between the bounds of the source
if the distance is >> 20 arcseconds, something's probably wrong
"""
function FITSWCS_Delta(path, pixcoords_1, pixcoords_2)
    fits_transform = gets_fits_transform(path)

    wcs = WCSTransform(2;
                        cdelt = fits_transform.cdelt,
                        ctype = fits_transform.ctype,
                        crpix = fits_transform.crpix,
                        crval = fits_transform.crval)

    (ra_1, dec_1) = pix_to_world(wcs, float(pixcoords_1))
    (ra_2, dec_2) = pix_to_world(wcs, float(pixcoords_2))

    # RA difference [arcsecond] = RA difference [seconds of time]  x 15 cos(Dec)

    ra_1_arcsec = ra_1 * 15 * cos(dec_1)
    ra_2_arcsec = ra_2 * 15 * cos(dec_2)

    delt_deg_ra  = abs(ra_1_arcsec - ra_2_arcsec)
    delt_deg_dec = abs(dec_1 - dec_2)

    delt_sxgm_ra  = decdeg_to_sxgm(delt_deg_ra)
    delt_sxgm_dec = decdeg_to_sxgm(delt_deg_dec)

    delt_arcsec_ra  = delt_sxgm_ra[1]*60*60 + delt_sxgm_ra[2]*60 + delt_sxgm_ra[3]
    delt_arcsec_dec = delt_sxgm_dec[1]*60*60 + delt_sxgm_dec[2]*60 + delt_sxgm_dec[3]

    return delt_arcsec_ra, delt_arcsec_dec
end
