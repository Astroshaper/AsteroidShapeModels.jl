#= ====================================================================
                 Ryugu Shape Model Performance Test
====================================================================
This file benchmarks performance with a realistic asteroid shape model:
- OBJ file loading with and without visibility calculation
- Illumination checks for multiple faces
- Ray-shape intersection performance
- Memory usage and visibility graph statistics
- Uses the Ryugu test model (2976 nodes, 5932 faces)
=# 

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
    shape     = load_shape_obj(path_shape; with_face_visibility=false, with_bvh=true)
    shape_vis = load_shape_obj(path_shape; with_face_visibility=true,  with_bvh=true)
    n_nodes = length(shape.nodes)
    n_faces = length(shape.faces)
    
    println("\nShape model info:")
    println("  - Nodes: $(n_nodes)")
    println("  - Faces: $(n_faces)")
        
    # 1. Benchmark OBJ file loading (without visibility)
    println("\n1. Benchmarking OBJ file loading (without visibility):")
    bench_load = @benchmark load_shape_obj($path_shape; with_face_visibility=false)
    display(bench_load)
    println()
        
    # 2. Benchmark loading with visibility calculation
    println("\n2. Benchmarking shape loading with visibility calculation:")
    bench_load_vis = @benchmark load_shape_obj($path_shape; with_face_visibility=true)
    display(bench_load_vis)
    println()
        
    # 3. Benchmark illumination checks
    println("\n3. Benchmarking illumination checks (100 faces):")
    view_dir = SA[1.0, 0.0, 0.0]
    bench_vis = @benchmark begin
        for idx in 1:100
            isilluminated($shape_vis, $view_dir, idx; with_self_shadowing=true)
        end
    end
    display(bench_vis)
    println()
        
    # 4. Benchmark ray intersection
    println("\n4. Benchmarking ray-shape intersection:")
    ray = Ray([0.0, 0.0, 1000.0], [0.0, 0.0, -1.0])
    bench_ray = @benchmark intersect_ray_shape($ray, $shape)
    display(bench_ray)
    println()
        
    # 5. Summary statistics
    println("\n=== Summary ===")
    total_visible_pairs = shape_vis.face_visibility_graph.nnz
    println("Total visible facet pairs: $total_visible_pairs")
    avg_visible_per_face = total_visible_pairs / n_faces
    println("Average visible facets per face: $(round(avg_visible_per_face, digits=2))")
end
