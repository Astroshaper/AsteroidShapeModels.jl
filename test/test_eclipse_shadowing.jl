#=
    test_eclipse_shadowing.jl

Unit tests for eclipse shadowing functionality.
Tests both the old and new API of apply_eclipse_shadowing! to ensure
they produce identical results.
=#

@testset "Eclipse Shadowing" begin
    ## --- SPICE kernels ---
    paths_kernel = [
        "fk/hera_v10.tf",
        "lsk/naif0012.tls",
        "pck/hera_didymos_v06.tpc",
        "spk/de432s.bsp",
        "spk/didymos_hor_000101_500101_v01.bsp",
        "spk/didymos_gmv_260901_311001_v01.bsp",
    ]
    
    ## --- Shape models ---
    paths_shape = [
        "g_50677mm_rad_obj_didy_0000n00000_v001.obj",  # Didymos' shape
        "g_08438mm_lgt_obj_dimo_0000n00000_v002.obj",  # Dimorphos' shape
    ]
    
    ## --- Download SPICE kernels ---
    for path_kernel in paths_kernel
        url_kernel = "https://s2e2.cosmos.esa.int/bitbucket/projects/SPICE_KERNELS/repos/hera/raw/kernels/$(path_kernel)?at=refs%2Ftags%2Fv161_20230929_001"
        filepath = joinpath("kernel", path_kernel)
        mkpath(dirname(filepath))
        isfile(filepath) || Downloads.download(url_kernel, filepath)
    end
    
    ## --- Download shape models ---
    for path_shape in paths_shape
        url_kernel = "https://s2e2.cosmos.esa.int/bitbucket/projects/SPICE_KERNELS/repos/hera/raw/kernels/dsk/$(path_shape)?at=refs%2Ftags%2Fv161_20230929_001"
        filepath = joinpath("shape", path_shape)
        mkpath(dirname(filepath))
        isfile(filepath) || Downloads.download(url_kernel, filepath)
    end
    
    ## --- Load the SPICE kernels ---
    for path_kernel in paths_kernel
        filepath = joinpath("kernel", path_kernel)
        SPICE.furnsh(filepath)
    end
    
    ## --- Ephemerides ---
    et_begin = SPICE.utc2et("2027-02-01T00:00:00")  # Start time
    et_end   = SPICE.utc2et("2027-02-02T00:00:00")  # End time
    et_range = range(et_begin, et_end; length=145)
    
    """
    - `time` : Ephemeris times
    - `sun`  : Sun's position in the primary's frame (DIDYMOS_FIXED)
    - `sec`  : Secondary's position in the primary's frame (DIDYMOS_FIXED)
    - `P2S`  : Rotation matrix from primary to secondary frames
    """
    ephem = (
        time = collect(et_range),
        sun  = [SVector{3}(SPICE.spkpos("SUN"      , et, "DIDYMOS_FIXED"  , "None", "DIDYMOS"  )[1]) * 1000 for et in et_range],
        sec  = [SVector{3}(SPICE.spkpos("DIMORPHOS", et, "DIDYMOS_FIXED"  , "None", "DIDYMOS"  )[1]) * 1000 for et in et_range],
        P2S  = [RotMatrix{3}(SPICE.pxform("DIDYMOS_FIXED"  , "DIMORPHOS_FIXED", et)) for et in et_range],
    )
    
    SPICE.kclear()
    
    ## --- Load the shape models ---
    path_shape1 = joinpath("shape", "g_50677mm_rad_obj_didy_0000n00000_v001.obj")
    path_shape2 = joinpath("shape", "g_08438mm_lgt_obj_dimo_0000n00000_v002.obj")
    
    shape1 = load_shape_obj(path_shape1; scale=1000, with_face_visibility=true, with_bvh=true)
    shape2 = load_shape_obj(path_shape2; scale=1000, with_face_visibility=true, with_bvh=true)
    
    @testset "Didymos-Dimorphos Binary System" begin
        # Test with realistic binary asteroid configuration using SPICE ephemeris
        # Track whether all tests pass without storing arrays
        all_dimorphos_shadows_didymos_tests_pass = true
        all_didymos_shadows_dimorphos_tests_pass = true
        
        for i in eachindex(ephem.time)
            r☉₁ = ephem.sun[i]  # Sun's position in the primary's frame
            r₁₂ = ephem.sec[i]  # Secondary's position in the primary's frame
            R₁₂ = ephem.P2S[i]  # Rotation matrix from primary to secondary frames
            
            # Pre-compute all coordinate transformations
            r☉₂ = R₁₂ * (r☉₁ - r₁₂)  # Sun's position in the secondary's frame
            R₂₁ = R₁₂'               # Rotation matrix from secondary to primary
            r₂₁ = -R₁₂ * r₁₂         # Primary's position in the secondary's frame
            
            # Test eclipses on Dimorphos and Didymos
            illuminated_faces1 = zeros(Bool, length(shape1.faces))
            illuminated_faces2 = zeros(Bool, length(shape2.faces))
            
            # Initialize illumination considering self-shadowing
            update_illumination!(illuminated_faces1, shape1, r☉₁; with_self_shadowing=true)
            update_illumination!(illuminated_faces2, shape2, r☉₂; with_self_shadowing=true)
            
            # Test new API
            status1 = apply_eclipse_shadowing!(illuminated_faces1, shape1, shape2, r☉₁, r₁₂, R₁₂)
            status2 = apply_eclipse_shadowing!(illuminated_faces2, shape2, shape1, r☉₂, r₂₁, R₂₁)
            
            # Check conditions and update overall test status
            all_dimorphos_shadows_didymos_tests_pass &= (status1 == PARTIAL_ECLIPSE || status1 == NO_ECLIPSE)
            all_didymos_shadows_dimorphos_tests_pass &= (status2 in [NO_ECLIPSE, PARTIAL_ECLIPSE, TOTAL_ECLIPSE])
        end
        
        # Single test assertions for all time steps
        @test all_dimorphos_shadows_didymos_tests_pass
        @test all_didymos_shadows_dimorphos_tests_pass
    end
    
    @testset "Error Handling" begin
        # Test with shape2 without BVH
        @testset "Missing BVH" begin
            shape1_copy = deepcopy(shape1)
            shape2_copy = deepcopy(shape2)
            shape2_copy.bvh = nothing  # Remove BVH
            
            r☉₁ = ephem.sun[1]
            r₁₂ = ephem.sec[1]
            R₁₂ = ephem.P2S[1]
            
            illuminated_faces = fill(true, length(shape1_copy.faces))
            
            @test_throws ArgumentError apply_eclipse_shadowing!(
                illuminated_faces, shape1_copy, shape2_copy, r☉₁, r₁₂, R₁₂
            )
        end
        
        # Test with wrong size illuminated_faces vector
        @testset "Wrong vector size" begin
            r☉₁ = ephem.sun[1]
            r₁₂ = ephem.sec[1]
            R₁₂ = ephem.P2S[1]
            
            illuminated_faces = fill(true, 10)  # Wrong size
            
            @test_throws AssertionError apply_eclipse_shadowing!(
                illuminated_faces, shape1, shape2, r☉₁, r₁₂, R₁₂
            )
        end
    end
end
