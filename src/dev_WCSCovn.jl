using PyCall

@pyimport numpy as np
@pyimport astropy.wcs as wcs

# Create a new WCS object.  The number of axes must be set
# from the start
w = wcs.WCS(naxis=2)

# Set up an "Airy's zenithal" projection
# Vector properties may be set with Python lists, or Numpy arrays
w["wcs"]["crpix"] = [-234.75, 8.3393]
w["wcs"]["cdelt"] = np.array([-0.066667, 0.066667])
w["wcs"]["crval"] = [0, -90]
w["wcs"]["ctype"] = ["RA---AIR", "DEC--AIR"]
#w.wcs.set_pv([(2, 1, 45.0)])

pixcrd = np.array([[0, 0], [24, 38], [45, 98]], np.float_)

world = w[:wcs_pix2world](pixcrd, 1)

pixcrd2 = w[:wcs_world2pix](world, 1)

println(world)

println(pixcrd2)
