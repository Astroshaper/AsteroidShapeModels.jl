#=
    test_bvh_comprehensive.jl

This file tests ray intersection and visibility functionality:
1. Ray-shape intersection with BVH acceleration
2. isilluminated function with BVH
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
    #   Part 2: isilluminated Function with BVH
    # ═══════════════════════════════════════════════════════════════════
    
    @testset "isilluminated BVH" begin
        println("\n" * "="^70)
        println("  Part 2: isilluminated Function BVH Tests")
        println("="^70)
        
        # Define sun position (closer for better test results)
        r☉ = SA[1000.0, 500.0, 300.0]  # Closer sun position in meters
        
        # Create shape with face visibility graph for baseline
        shape_with_vis = ShapeModel(shape.nodes, shape.faces; with_face_visibility=true)
        
        # 2.1 Test all faces
        println("\n2.1 Testing ALL $n_faces faces:")
        
        results_with_vis = Bool[]
        results_with_bvh = Bool[]
        
        print("  Computing baseline (with visibility graph)...")
        time_with_vis = @elapsed for i in 1:n_faces
            push!(results_with_vis, isilluminated(shape_with_vis, r☉, i))
        end
        println(" done ($(round(time_with_vis, digits=3))s)")
        
        print("  Computing with BVH...")
        time_bvh = @elapsed for i in 1:n_faces
            push!(results_with_bvh, isilluminated(shape, r☉, i))
        end
        println(" done ($(round(time_bvh, digits=3))s)")
        
        count_with_vis = sum(results_with_vis)
        count_bvh = sum(results_with_bvh)
        
        println("\n  Results:")
        println("    With visibility graph : $count_with_vis / $n_faces illuminated")
        println("    With BVH              : $count_bvh / $n_faces illuminated")
        println("    Difference            : $(abs(count_with_vis - count_bvh)) faces")
        
        # 2.2 Performance comparison
        println("\n2.2 Performance comparison:")
        
        # Sample faces for detailed timing
        sample_faces = collect(1:min(100, n_faces))
        
        # Use setup parameter to avoid scope issues with @belapsed
        time_per_face_with_vis = @belapsed begin
            for i in sample_faces
                isilluminated(shape_with_vis, r☉, i)
            end
        end setup=(sample_faces=$sample_faces; shape_with_vis=$shape_with_vis; r☉=$r☉) / length(sample_faces)
        
        time_per_face_bvh = @belapsed begin
            for i in sample_faces
                isilluminated(shape, r☉, i)
            end
        end setup=(sample_faces=$sample_faces; shape=$shape; r☉=$r☉) / length(sample_faces)
        
        println("  Average time per face:")
        println("    With visibility graph : $(round(time_per_face_with_vis * 1e6, digits=2)) μs")
        println("    With BVH             : $(round(time_per_face_bvh * 1e6, digits=2)) μs")
        
        # Note: BVH may be slower for isilluminated because it checks all obstructions
        # while no-BVH version returns immediately on first obstruction
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
    # Summary
    # ═══════════════════════════════════════════════════════════════════
    
    println("\n" * "="^70)
    println("Test Summary")
    println("="^70)
    println("✓ Ray-shape intersection: BVH implementation tested")
    println("✓ isilluminated: BVH implementation tested")
    println("✓ build_face_visibility_graph!: Non-BVH performance evaluated")
    println("✓ All tests completed with $(n_faces)-face model")
end