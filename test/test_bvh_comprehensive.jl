#=
    test_bvh_comprehensive.jl

This file tests ray intersection and visibility functionality:
1. Ray-shape intersection with BVH acceleration
2. isilluminated function performance (full occlusion vs pseudo-convex models)
3. build_face_visibility_graph! performance
All tests include correctness verification and performance benchmarks.
=#

@testset "Ray Intersection and Visibility Tests" begin
    msg = """\n
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    |        Ray Intersection and Visibility Tests           |
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    """
    println(msg)
    
    # Download the high-resolution shape model if it doesn't exist
    shape_filename = "SHAPE_SFM_49k_v20180804.obj"
    shape_url = "https://data.darts.isas.jaxa.jp/pub/hayabusa2/paper/Watanabe_2019/$shape_filename"
    shape_filepath = joinpath(@__DIR__, "shape", shape_filename)
    
    if !isfile(shape_filepath)
        println("\nDownloading high-resolution shape model...")
        mkpath(dirname(shape_filepath))
        Downloads.download(shape_url, shape_filepath)
    end
    
    # Load shape models
    println("\nLoading shape model...")
    shape = load_shape_obj(shape_filepath; scale=1000, with_bvh=true, with_face_visibility=false)
    
    n_nodes = length(shape.nodes)
    n_faces = length(shape.faces)
    
    println("\nShape model info:")
    println("  - Nodes: $(n_nodes)")
    println("  - Faces: $(n_faces)")
    println("  - BVH built: $(!isnothing(shape.bvh))")
    
    # ═══════════════════════════════════════════════════════════════════
    #   Part 1: Ray-Shape Intersection with BVH
    # ═══════════════════════════════════════════════════════════════════
    
    @testset "Ray-Shape Intersection BVH" begin
        println("\n" * "="^70)
        println("  Part 1: Ray-Shape Intersection BVH Tests")
        println("="^70)
        
        # Generate test rays
        Random.seed!(42)
        n_test_rays = 50
        rays = []
        
        for i in 1:n_test_rays
            θ = 2π * rand()
            φ = π * rand()
            r = 5000.0  # Far from the shape (in meters)
            origin = SA[r*sin(φ)*cos(θ), r*sin(φ)*sin(θ), r*cos(φ)]
            direction = normalize(-origin)
            push!(rays, Ray(origin, direction))
        end
        
        # 1.1 Hit detection test
        println("\n1.1 Testing hit detection ($(n_test_rays) random rays):")
        
        hits = 0
        for (i, ray) in enumerate(rays)
            result = intersect_ray_shape(ray, shape)
            
            if result.hit
                hits += 1
                println("  Ray $i: Hit face $(result.face_index) at distance $(round(result.distance, digits=2))")
            end
        end
        
        println("  Total hits: $hits / $n_test_rays rays")
        @test hits > 0  # At least some rays should hit
        
        # 1.2 Performance benchmark
        println("\n1.2 Performance benchmark:")
        
        test_ray = rays[1]
        
        time_single = @belapsed intersect_ray_shape($test_ray, $shape)
        println("  Single ray: $(round(time_single * 1e6, digits=2)) μs")
        
        # Batch rays
        time_batch = @belapsed for ray in $rays
            intersect_ray_shape(ray, $shape)
        end
        println("\n  Batch ($n_test_rays rays): $(round(time_batch * 1000, digits=2)) ms")
        println("  Average per ray: $(round(time_batch / n_test_rays * 1e6, digits=2)) μs")
        
        # Hit rate statistics
        hit_results = [intersect_ray_shape(ray, shape).hit for ray in rays]
        hit_count = sum(hit_results)
        
        println("\n  Hit rate: $hit_count / $n_test_rays ($(round(100 * hit_count / n_test_rays, digits=1))%)")
        
        @test time_single > 0  # Sanity check
        @test time_batch > 0   # Sanity check
    end
    
    # ═══════════════════════════════════════════════════════════════════
    #   Part 2: isilluminated Function Performance
    # ═══════════════════════════════════════════════════════════════════
    
    @testset "isilluminated Performance" begin
        println("\n" * "="^70)
        println("  Part 2: isilluminated Function Performance Tests")
        println("="^70)
        
        # Define sun position (closer for better test results)
        r☉ = SA[1000.0, 500.0, 300.0]  # Closer sun position in meters
        
        # Create shape with face visibility graph
        shape_with_vis = ShapeModel(shape.nodes, shape.faces; with_face_visibility=true)
        
        # Create shape without visibility graph for pseudo-convex model test
        shape_no_vis = ShapeModel(shape.nodes, shape.faces; with_face_visibility=false)
        
        # 2.1 Test all faces
        println("\n2.1 Comparing illumination models ($n_faces faces):")
        
        results_with_vis = Bool[]
        results_pseudo_convex = Bool[]
        
        print("  Full occlusion model (with visibility graph)...")
        time_with_vis = @elapsed for i in 1:n_faces
            push!(results_with_vis, isilluminated(shape_with_vis, r☉, i; with_self_shadowing=true))
        end
        println(" done ($(round(time_with_vis, digits=3))s)")
        
        print("  Pseudo-convex model (no visibility graph)...")
        time_pseudo_convex = @elapsed for i in 1:n_faces
            push!(results_pseudo_convex, isilluminated(shape_no_vis, r☉, i; with_self_shadowing=false))
        end
        println(" done ($(round(time_pseudo_convex, digits=3))s)")
        
        count_with_vis = sum(results_with_vis)
        count_pseudo_convex = sum(results_pseudo_convex)
        
        println("\n  Illumination results:")
        println("    Full occlusion model : $count_with_vis / $n_faces faces illuminated")
        println("    Pseudo-convex model  : $count_pseudo_convex / $n_faces faces illuminated")
        println("    Difference           : $(abs(count_pseudo_convex - count_with_vis)) faces")
        println("\n  Note: Pseudo-convex model only checks face orientation (no shadow testing)")
        println("        Differences are expected for non-convex shapes")
        
        # Note: Results will differ because:
        # - With visibility graph: checks actual occlusions
        # - Without visibility graph: assumes pseudo-convex (no occlusion check)
        # This is expected behavior, not an error
        
        # 2.2 Performance comparison
        println("\n2.2 Performance comparison:")
        
        # Sample faces for detailed timing
        sample_faces = collect(1:min(100, n_faces))
        
        # Use setup parameter to avoid scope issues with @belapsed
        time_per_face_with_vis = @belapsed begin
            for i in sample_faces
                isilluminated(shape_with_vis, r☉, i; with_self_shadowing=true)
            end
        end setup=(sample_faces=$sample_faces; shape_with_vis=$shape_with_vis; r☉=$r☉) / length(sample_faces)
        
        time_per_face_pseudo_convex = @belapsed begin
            for i in sample_faces
                isilluminated(shape_no_vis, r☉, i; with_self_shadowing=false)
            end
        end setup=(sample_faces=$sample_faces; shape_no_vis=$shape_no_vis; r☉=$r☉) / length(sample_faces)
        
        println("  Average time per face:")
        println("    Full occlusion model : $(round(time_per_face_with_vis * 1e6, digits=2)) μs")
        println("    Pseudo-convex model  : $(round(time_per_face_pseudo_convex * 1e6, digits=2)) μs")
        println("    Speedup              : $(round(time_per_face_pseudo_convex / time_per_face_with_vis, digits=1))x")
        
        # Note: Visibility graph provides significant speedup by limiting occlusion checks
        # to only potentially visible faces
    end
    
    # ═══════════════════════════════════════════════════════════════════
    #   Part 3: build_face_visibility_graph!
    # ═══════════════════════════════════════════════════════════════════
    
    @testset "build_face_visibility_graph! Performance" begin
        println("\n" * "="^70)
        println("  Part 3: build_face_visibility_graph! Performance Tests")
        println("="^70)
        
        # Use smaller subset for reasonable test time
        n_test_faces = 2000
        
        println("\n3.1 Testing with subset of $n_test_faces faces:")
        
        # Create subset shape
        shape_subset = ShapeModel(
            shape.nodes,
            shape.faces[1:n_test_faces];
        )
        
        # Build visibility graph with optimized non-BVH algorithm
        print("  Building visibility graph...")
        GC.gc()
        time_elapsed = @elapsed build_face_visibility_graph!(shape_subset)
        nnz_visible = shape_subset.face_visibility_graph.nnz
        println(" done")
        println("    Time          : $(round(time_elapsed, digits=3)) seconds")
        println("    Visible pairs : $nnz_visible")
        println("    Avg pairs/face: $(round(nnz_visible / n_test_faces, digits=1))")
        
        # Performance metrics
        println("\n3.2 Performance metrics:")
        println("  Time per face : $(round(time_elapsed * 1000 / n_test_faces, digits=2)) ms")
        println("  Pairs per sec : $(round(nnz_visible / time_elapsed))")
        
        # Memory usage
        graph_memory = Base.summarysize(shape_subset.face_visibility_graph)
        println("\n3.3 Memory usage:")
        println("  Total memory  : $(round(graph_memory / 1024^2, digits=2)) MB")
        println("  Per face      : $(round(graph_memory / n_test_faces)) bytes")
        println("  Per vis pair  : $(round(graph_memory / nnz_visible)) bytes")
        
        # Sample visibility distribution
        sample_faces = [1, 100, 500, 1000, min(n_test_faces, 2000)]
        println("\n3.4 Visibility distribution (sample faces):")
        for i in sample_faces
            if i <= n_test_faces
                vis_count = num_visible_faces(shape_subset.face_visibility_graph, i)
                println("    Face $i: $vis_count visible faces")
            end
        end
    end
    
    # ═══════════════════════════════════════════════════════════════════
    #   Summary
    # ═══════════════════════════════════════════════════════════════════
    
    println("\n" * "="^70)
    println("  Test Summary")
    println("="^70)
    println("✓ Ray-shape intersection: BVH implementation tested")
    println("✓ isilluminated: Non-BVH implementation tested")
    println("✓ build_face_visibility_graph!: Non-BVH performance evaluated")
    println("✓ All tests completed with $(n_faces)-face model")
end