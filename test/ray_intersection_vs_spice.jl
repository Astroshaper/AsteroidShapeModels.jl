@testset "Ray-Shape Intersection vs. SPICE/DSK" begin
    msg = """\n
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    |       Test: Ray-Shape Intersection vs. SPICE/DSK       |
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    """
    println(msg)

    ##==== Download Files ====##

    # List of minimal SPICE kernels needed for the test
    paths_kernel = [
        "fk/hera_v14.tf",
        "fk/hera_ops_v05.tf", 
        "fk/hera_dsk_surfaces_v05.tf",
        "dsk/g_01165mm_spc_obj_didy_0000n00000_v003.bds",
        "ik/hera_tiri_v03.ti",
        "lsk/naif0012.tls",
        "pck/pck00011.tpc",
        "pck/hera_didymos_v06.tpc",
        "sclk/hera_fict_181203_v01.tsc",
        "spk/de432s.bsp",
        "spk/didymos_hor_000101_500101_v01.bsp",
        "spk/hera_dart_impact_site_v04.bsp",
        "spk/hera_sci_v01.bsp",
        "spk/hera_struct_v02.bsp",
        "ck/hera_sc_crema_2_1_LPO_241007_270303_f181203_v01.bc",
        "spk/didymos_crema_2_1_ECP_PDP_DCP_261120_270515_v01.bsp",
        "spk/hera_sc_crema_2_1_LPO_241007_261202_v01.bsp",
        "spk/hera_sc_crema_2_1_ECP_PDP_DCP_261125_270303_v01.bsp"
    ]

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

    ##==== Load data with SPICE ====##
    for path_kernel in paths_kernel
        filepath = joinpath("kernel", path_kernel)
        SPICE.furnsh(filepath)
    end

    ##==== AsteroidShapeModels.jl ray intersection test ====##

    obj_path = joinpath("shape", "g_01165mm_spc_obj_didy_0000n00000_v003.obj")
    shape = load_shape_obj(obj_path; scale=1000.0)
    println(shape)

    # Define camera parameters
    TIRI_ID = -91200
    
    utc = "2027-02-01T01:00:00"
    et = SPICE.utc2et(utc)
    
    ref    = "DIDYMOS_FIXED"
    abcorr = "NONE"  # No aberration correction
    # abcorr = "LT+S"  # If aberration correction works, the intersection point shifts by 0.0012 m.
    obs    = "DIDYMOS"
    
    camera_position = SVector{3, Float64}(SPICE.spkpos("HERA_TIRI", et, ref, abcorr, obs)[1]) * 1000  # TIRI position in meters

    _, fov_frame, boresight, _ = SPICE.getfov(TIRI_ID)  # Boresight vector at the camera frame
    rotation_matrix = SPICE.pxform(fov_frame, ref, et)  # Rotation matrix from camera frame to target frame
    camera_boresight = SVector{3, Float64}(rotation_matrix * boresight)  # Transform boresight to the target frame

    ray = Ray(camera_position, camera_boresight)
        
    # Compute bounding box
    bbox = compute_bounding_box(shape)
        
    # Perform ray intersection with AsteroidShapeModels.jl
    intersection = intersect_ray_shape(ray, shape, bbox)

    ##==== SPICE sincpt function comparison ====##
    ## cf. https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/sincpt_c.html

    # Call SPICE sincpt function
    spoint, trgepc, srfvec = SPICE.sincpt(
        "DSK/UNPRIORITIZED",  # Shape model type
        obs,                  # Target body name
        et,                   # Ephemeris time
        ref,                  # Target body frame
        abcorr,               # Aberration correction
        "HERA_TIRI",          # Observer name  
        "HERA_TIRI",          # Reference frame
        collect(boresight)    # Ray direction vector
    )

    spoint *= 1000  # Convert from km to m
    srfvec *= 1000  # Convert from km to m

    ##==== Compare intersection results ====##

    diff = norm(spoint - intersection.point)  # Difference in intersection points [m]
    @test diff < 0.01  # Allow up to 0.01 m difference

    println("Intersection point [m]")
    println("    ∘ AsteroidShapeModels.jl : $(intersection.point)")
    println("    ∘ SPICE/DSK              : $spoint")
    println("    → Difference between them : $diff m")
    println()
    
    #### Computation time comparison ####
    
    println("Computation time")
    print("    ∘ intersect_ray_shape in AsteroidShapeModels.jl :")
    @time intersect_ray_shape(ray, shape, bbox)
    print("    ∘ sincpt in SPICE.jl                            :")
    @time SPICE.sincpt("DSK/UNPRIORITIZED", obs, et, ref, abcorr, "HERA_TIRI", "HERA_TIRI", collect(boresight))
    println()

    SPICE.kclear()  # Unload SPICE kernels
end
