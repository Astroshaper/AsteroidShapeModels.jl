#=
    test_ray_intersection_vs_spice.jl

Validation tests comparing ray-shape intersection against SPICE/DSK.
This file validates our ray-shape intersection algorithm against
NASA's SPICE toolkit using the Digital Shape Kernel (DSK) format.

The test downloads actual mission data from ESA's Hera mission
and compares intersection results between:
- AsteroidShapeModels.jl's implementation
- SPICE's `sincpt` function with DSK shape models

This ensures our implementation produces accurate results when
compared to the industry-standard SPICE toolkit.
=#

@testset "Ray-Shape Intersection vs. SPICE/DSK" begin
    msg = """\n
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    |       Test: Ray-Shape Intersection vs. SPICE/DSK       |
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    """
    println(msg)

    # ================================================================
    #                   Download Required Files
    # ================================================================

    # Download SPICE kernels and shape models from ESA's repository
    # These files contain spacecraft ephemeris, frame definitions,
    # and the Didymos asteroid shape model

    # SPICE kernel files needed for the test
    paths_kernel = [
        "fk/hera_v14.tf",                    # Frame definitions
        "fk/hera_ops_v05.tf",                # Operational frames
        "fk/hera_dsk_surfaces_v05.tf",       # DSK surface definitions
        "dsk/g_01165mm_spc_obj_didy_0000n00000_v003.bds",  # Didymos DSK
        "ik/hera_tiri_v03.ti",               # TIRI instrument kernel
        "lsk/naif0012.tls",                  # Leap seconds kernel
        "pck/pck00011.tpc",                  # Planetary constants
        "pck/hera_didymos_v06.tpc",          # Didymos constants
        "sclk/hera_fict_181203_v01.tsc",     # Spacecraft clock
        "spk/de432s.bsp",                    # Planetary ephemeris
        "spk/didymos_hor_000101_500101_v01.bsp",  # Didymos trajectory
        "spk/hera_dart_impact_site_v04.bsp", # DART impact site
        "spk/hera_sci_v01.bsp",              # Hera science trajectory
        "spk/hera_struct_v02.bsp",           # Hera structure
        "ck/hera_sc_crema_2_1_LPO_241007_270303_f181203_v01.bc",  # Attitude
        "spk/didymos_crema_2_1_ECP_PDP_DCP_261120_270515_v01.bsp",
        "spk/hera_sc_crema_2_1_LPO_241007_261202_v01.bsp",
        "spk/hera_sc_crema_2_1_ECP_PDP_DCP_261125_270303_v01.bsp"
    ]

    # Shape model file (OBJ format)
    paths_shape = [
        "g_01165mm_spc_obj_didy_0000n00000_v003.obj"
    ]

    # Download kernels if not already present
    for path_kernel in paths_kernel
        url_kernel = "https://spiftp.esac.esa.int/data/SPICE/HERA/kernels/$(path_kernel)"
        filepath = joinpath("kernel", path_kernel)
        mkpath(dirname(filepath))
        isfile(filepath) || Downloads.download(url_kernel, filepath)
    end

    # Download shape models if not already present
    for path_shape in paths_shape
        url_shape = "https://spiftp.esac.esa.int/data/SPICE/HERA/kernels/dsk/$(path_shape)"
        filepath = joinpath("shape", path_shape)
        mkpath(dirname(filepath))
        isfile(filepath) || Downloads.download(url_shape, filepath)
    end

    # ================================================================
    #                    Load SPICE Kernels
    # ================================================================

    # Load all downloaded kernels into SPICE
    for path_kernel in paths_kernel
        filepath = joinpath("kernel", path_kernel)
        SPICE.furnsh(filepath)
    end

    # ================================================================
    #              AsteroidShapeModels.jl Test Setup
    # ================================================================

    # Load the Didymos shape model and prepare for ray intersection

    obj_path = joinpath("shape", "g_01165mm_spc_obj_didy_0000n00000_v003.obj")
    shape = load_shape_obj(obj_path; scale=1000.0)  # Convert km to m
    println(shape)

    # ================================================================
    #                  Define Test Scenario
    # ================================================================

    # Set up a realistic observation scenario:
    # - Epoch: 01:00:00 on February 1, 2027
    # - Instrument: TIRI (Thermal Infrared Imager) onboard ESA's Hera spacecraft
    # - Target: Asteroid Didymos
    
    TIRI_ID = -91200  # SPICE instrument ID for TIRI
    
    # Observation time
    utc = "2027-02-01T01:00:00"
    et = SPICE.utc2et(utc)  # Convert to ephemeris time [s]
    
    # Reference frames and corrections
    ref    = "DIDYMOS_FIXED"  # Didymos body-fixed frame
    abcorr = "NONE"           # No aberration correction
    # abcorr = "LT+S"         # Light-time + stellar aberration (The intersection point shifts by ~0.0012 m)
    obs    = "DIDYMOS"        # Observer (target body)
    
    # Get TIRI camera position relative to Didymos
    camera_position = SVector{3, Float64}(SPICE.spkpos("HERA_TIRI", et, ref, abcorr, obs)[1]) * 1000  # Convert km to m

    # Get camera boresight direction
    _, fov_frame, boresight, _ = SPICE.getfov(TIRI_ID)  # Boresight in camera frame
    rotation_matrix = SPICE.pxform(fov_frame, ref, et)  # Transform to target frame
    camera_boresight = SVector{3, Float64}(rotation_matrix * boresight)  # Boresight in target frame

    # Create ray for intersection test
    ray = Ray(camera_position, camera_boresight)
        
    # Perform ray intersection with our implementation
    intersection = intersect_ray_shape(ray, shape)

    # ================================================================
    #                  SPICE sincpt Comparison
    # ================================================================

    # Use SPICE's `sincpt` (surface intercept) function to find the
    # same intersection point using the DSK shape model
    # Reference: https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/sincpt_c.html

    # Call SPICE sincpt function
    spoint, trgepc, srfvec = SPICE.sincpt(
        "DSK/UNPRIORITIZED",  # Use DSK shape model
        obs,                  # Target body name
        et,                   # Ephemeris time
        ref,                  # Target body frame
        abcorr,               # Aberration correction
        "HERA_TIRI",          # Observer name  
        "HERA_TIRI",          # Reference frame for ray
        collect(boresight)    # Ray direction vector
    )

    spoint *= 1000  # Convert from km to m
    srfvec *= 1000  # Convert from km to m

    # ================================================================
    #                  Compare Results
    # ================================================================

    # Verify that both methods produce the same intersection point
    diff = norm(spoint - intersection.point)  # Difference in meters

    println("Intersection point [m]")
    println("    ∘ AsteroidShapeModels.jl : $(intersection.point)")
    println("    ∘ SPICE/DSK              : $spoint")
    println("    → Difference between them : $diff m")

    @test diff < 0.01  # Allow up to 1 cm difference

    println()
    
    # ================================================================
    #               Performance Comparison
    # ================================================================

    # Compare computation times between implementations
    println("Computation time")
    print("    ∘ intersect_ray_shape in AsteroidShapeModels.jl :")
    @time intersect_ray_shape(ray, shape)
    print("    ∘ sincpt in SPICE.jl                            :")
    @time SPICE.sincpt("DSK/UNPRIORITIZED", obs, et, ref, abcorr, "HERA_TIRI", "HERA_TIRI", collect(boresight))

    println()

    # Unload all SPICE kernels
    SPICE.kclear()
end
