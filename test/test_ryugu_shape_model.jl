@testset "Ryugu Shape Model Performance Test" begin
    msg = """\n
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    |           Test: Ryugu Shape Model Performance          |
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    """
    println(msg)
    
    # Use the test shape model in the repository
    path_shape = joinpath("shape", "ryugu_test.obj")
    
    # Load shape models
    shape     = load_shape_obj(path_shape; find_visible_facets=false)
    shape_vis = load_shape_obj(path_shape; find_visible_facets=true)
    n_nodes = length(shape.nodes)
    n_faces = length(shape.faces)
    
    println("\nShape model info:")
    println("  - Nodes: $(n_nodes)")
    println("  - Faces: $(n_faces)")
        
    # 1. Benchmark OBJ file loading (without visibility)
    println("\n1. Benchmarking OBJ file loading (without visibility):")
    bench_load = @benchmark load_shape_obj($path_shape; find_visible_facets=false)
    display(bench_load)
    println()
        
    # 2. Benchmark loading with visibility calculation
    println("\n2. Benchmarking shape loading with visibility calculation:")
    bench_load_vis = @benchmark load_shape_obj($path_shape; find_visible_facets=true)
    display(bench_load_vis)
    println()
        
    # 3. Benchmark illumination checks
    println("\n3. Benchmarking illumination checks (100 faces):")
    view_dir = SA[1.0, 0.0, 0.0]
    bench_vis = @benchmark begin
        for idx in 1:100
            isilluminated($shape_vis, $view_dir, idx)
        end
    end
    display(bench_vis)
    println()
        
    # 4. Benchmark ray intersection
    println("\n4. Benchmarking ray-shape intersection:")
    ray = Ray([0.0, 0.0, 1000.0], [0.0, 0.0, -1.0])
    bbox = compute_bounding_box(shape)
    bench_ray = @benchmark intersect_ray_shape($ray, $shape, $bbox)
    display(bench_ray)
    println()
        
    # 5. Summary statistics
    println("\n=== Summary ===")
    total_visible_pairs = shape_vis.face_visibility_graph.nnz
    println("Total visible facet pairs: $total_visible_pairs")
    avg_visible_per_face = total_visible_pairs / n_faces
    println("Average visible facets per face: $(round(avg_visible_per_face, digits=2))")
end
