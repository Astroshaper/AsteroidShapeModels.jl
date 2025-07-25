using AsteroidShapeModels
using BenchmarkTools
# using PkgBenchmark  # Comment out if not using PkgBenchmark
using StaticArrays

# Load test shape model once
const SHAPE_PATH = joinpath(@__DIR__, "..", "test", "shape", "ryugu_test.obj")
const SHAPE     = load_shape_obj(SHAPE_PATH; with_face_visibility=false, with_bvh=true)
const SHAPE_VIS = load_shape_obj(SHAPE_PATH; with_face_visibility=true,  with_bvh=true)

# Benchmark suite
const SUITE = BenchmarkGroup()

# 1. Shape loading benchmarks
SUITE["loading"] = BenchmarkGroup()
SUITE["loading"]["without_visibility"] = @benchmarkable load_shape_obj($SHAPE_PATH; with_face_visibility=false)
SUITE["loading"]["with_visibility"]    = @benchmarkable load_shape_obj($SHAPE_PATH; with_face_visibility=true)

# 2. Face property calculations
SUITE["face_properties"] = BenchmarkGroup()
let nodes = SHAPE.nodes, faces = SHAPE.faces
    # Single face calculations
    face = faces[1]
    v1, v2, v3 = get_face_nodes(nodes, faces, 1)
    face_nodes = SA[v1, v2, v3]
    
    SUITE["face_properties"]["face_center"] = @benchmarkable face_center($face_nodes)
    SUITE["face_properties"]["face_normal"] = @benchmarkable face_normal($face_nodes)
    SUITE["face_properties"]["face_area"]   = @benchmarkable face_area($face_nodes)
    
    # Batch calculations (100 faces)
    SUITE["face_properties"]["batch_centers"] = @benchmarkable begin
        for i in 1:100
            face = $faces[i]
            v1, v2, v3 = get_face_nodes($nodes, $faces, i)
            fn = SA[v1, v2, v3]
            face_center(fn)
        end
    end
end

# 3. Visibility calculations
SUITE["visibility"] = BenchmarkGroup()
let view_dir = SA[1.0, 0.0, 0.0]
    # Single face query
    SUITE["visibility"]["single_face"] = @benchmarkable isilluminated($SHAPE_VIS, $view_dir, 1; with_self_shadowing=true)
    
    # Batch queries
    SUITE["visibility"]["batch_100_faces"] = @benchmarkable begin
        for idx in 1:100
            isilluminated($SHAPE_VIS, $view_dir, idx; with_self_shadowing=true)
        end
    end
    
    # Direct visibility graph access
    SUITE["visibility"]["num_visible_faces"] = @benchmarkable num_visible_faces($SHAPE_VIS.face_visibility_graph, 1)
    SUITE["visibility"]["get_visible_face_indices"] = @benchmarkable get_visible_face_indices($SHAPE_VIS.face_visibility_graph, 1)
    SUITE["visibility"]["get_view_factors"] = @benchmarkable get_view_factors($SHAPE_VIS.face_visibility_graph, 1)
    
    # Sequential vs random access
    seq_indices = 1:100
    rand_indices = rand(1:length(SHAPE_VIS.faces), 100)
    
    SUITE["visibility"]["sequential_access"] = @benchmarkable begin
        for i in $seq_indices
            num_visible_faces($SHAPE_VIS.face_visibility_graph, i)
        end
    end
    
    SUITE["visibility"]["random_access"] = @benchmarkable begin
        for i in $rand_indices
            num_visible_faces($SHAPE_VIS.face_visibility_graph, i)
        end
    end
end

# 4. Ray intersection benchmarks
SUITE["ray_intersection"] = BenchmarkGroup()
let ray = Ray([0.0, 0.0, 1000.0], [0.0, 0.0, -1.0])
    # Single triangle intersection
    A, B, C = get_face_nodes(SHAPE, 1)
    
    SUITE["ray_intersection"]["single_triangle"] = @benchmarkable intersect_ray_triangle($ray, $A, $B, $C)
    
    # Full shape intersection
    SUITE["ray_intersection"]["full_shape"] = @benchmarkable intersect_ray_shape($ray, $SHAPE)
    
    # Multiple rays - old method (loop)
    rays_mat = [Ray([x, y, 1000.0], [0.0, 0.0, -1.0]) for x in -500:100:500, y in -500:100:500]
    SUITE["ray_intersection"]["multiple_rays_loop"] = @benchmarkable begin
        for ray in $rays_mat
            intersect_ray_shape(ray, $SHAPE)
        end
    end
    
    # Batch processing - new method (vector)
    rays_vec = vec(rays_mat)  # Convert to vector
    SUITE["ray_intersection"]["batch_rays_vector"] = @benchmarkable intersect_ray_shape($rays_vec, $SHAPE)
    
    # Batch processing - matrix interface
    SUITE["ray_intersection"]["batch_rays_matrix"] = @benchmarkable intersect_ray_shape($rays_mat, $SHAPE)
    
    # Raw matrix interface (maximum performance)
    n_rays = length(rays_vec)
    origins = zeros(3, n_rays)
    directions = zeros(3, n_rays)
    for (i, ray) in enumerate(rays_vec)
        origins[:, i] = ray.origin
        directions[:, i] = ray.direction
    end
    SUITE["ray_intersection"]["batch_rays_raw"] = @benchmarkable intersect_ray_shape($SHAPE, $origins, $directions)
end

# 5. Shape characteristics
SUITE["shape_characteristics"] = BenchmarkGroup()
SUITE["shape_characteristics"]["volume"] = @benchmarkable polyhedron_volume($SHAPE)
SUITE["shape_characteristics"]["equivalent_radius"] = @benchmarkable equivalent_radius($SHAPE)
SUITE["shape_characteristics"]["maximum_radius"] = @benchmarkable maximum_radius($SHAPE)
SUITE["shape_characteristics"]["minimum_radius"] = @benchmarkable minimum_radius($SHAPE)

# 6. Memory allocation benchmarks
SUITE["memory"] = BenchmarkGroup()
SUITE["memory"]["shape_model_creation"] = @benchmarkable begin
    nodes = [SA[rand(), rand(), rand()] for _ in 1:1000]
    faces = [SA[rand(1:1000), rand(1:1000), rand(1:1000)] for _ in 1:2000]
    ShapeModel(nodes, faces; with_face_visibility=false)
end

# FaceVisibilityGraph memory usage
SUITE["memory"]["visibility_graph_size"] = @benchmarkable begin
    Base.summarysize($SHAPE_VIS.face_visibility_graph)
end

# 7. Find visible facets performance
SUITE["find_visible_facets"] = BenchmarkGroup()
SUITE["find_visible_facets"]["small_shape"] = @benchmarkable begin
    shape = deepcopy($SHAPE)
    build_face_visibility_graph!(shape)
end

# If running standalone (not through PkgBenchmark)
if abspath(PROGRAM_FILE) == @__FILE__
    results = run(SUITE, verbose=true)
    println("\n=== Benchmark Results ===")
    for (group_name, group) in results
        println("\n$group_name:")
        for (bench_name, bench) in group
            println("  $bench_name: $(median(bench))")
        end
    end
end
