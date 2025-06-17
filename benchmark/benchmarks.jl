using AsteroidShapeModels
using BenchmarkTools
# using PkgBenchmark  # Comment out if not using PkgBenchmark
using StaticArrays

# Load test shape model once
const SHAPE_PATH = joinpath(@__DIR__, "..", "test", "shape", "ryugu_test.obj")
const SHAPE     = load_shape_obj(SHAPE_PATH; find_visible_facets=false)
const SHAPE_VIS = load_shape_obj(SHAPE_PATH; find_visible_facets=true)
const BBOX = compute_bounding_box(SHAPE)

# Benchmark suite
const SUITE = BenchmarkGroup()

# 1. Shape loading benchmarks
SUITE["loading"] = BenchmarkGroup()
SUITE["loading"]["without_visibility"] = @benchmarkable load_shape_obj($SHAPE_PATH; find_visible_facets=false)
SUITE["loading"]["with_visibility"] = @benchmarkable load_shape_obj($SHAPE_PATH; find_visible_facets=true)

# 2. Face property calculations
SUITE["face_properties"] = BenchmarkGroup()
let nodes = SHAPE.nodes, faces = SHAPE.faces
    # Single face calculations
    face = faces[1]
    face_nodes = SA[nodes[face[1]], nodes[face[2]], nodes[face[3]]]
    
    SUITE["face_properties"]["face_center"] = @benchmarkable face_center($face_nodes)
    SUITE["face_properties"]["face_normal"] = @benchmarkable face_normal($face_nodes)
    SUITE["face_properties"]["face_area"]   = @benchmarkable face_area($face_nodes)
    
    # Batch calculations (100 faces)
    SUITE["face_properties"]["batch_centers"] = @benchmarkable begin
        for i in 1:100
            face = $faces[i]
            fn = SA[$nodes[face[1]], $nodes[face[2]], $nodes[face[3]]]
            face_center(fn)
        end
    end
end

# 3. Visibility calculations
SUITE["visibility"] = BenchmarkGroup()
let view_dir = SA[1.0, 0.0, 0.0]
    SUITE["visibility"]["single_face"] = @benchmarkable isilluminated($SHAPE_VIS, $view_dir, 1)
    SUITE["visibility"]["batch_100_faces"] = @benchmarkable begin
        for idx in 1:100
            isilluminated($SHAPE_VIS, $view_dir, idx)
        end
    end
    
    # Visibility lookup
    SUITE["visibility"]["visible_facets_lookup"] = @benchmarkable begin
        num_visible_faces($SHAPE_VIS.visibility_graph, 1)
    end
end

# 4. Ray intersection benchmarks
SUITE["ray_intersection"] = BenchmarkGroup()
let ray = Ray([0.0, 0.0, 1000.0], [0.0, 0.0, -1.0])
    # Single triangle intersection
    face = SHAPE.faces[1]
    A = SHAPE.nodes[face[1]]
    B = SHAPE.nodes[face[2]]
    C = SHAPE.nodes[face[3]]
    
    SUITE["ray_intersection"]["single_triangle"] = @benchmarkable intersect_ray_triangle($ray, $A, $B, $C)
    
    # Full shape intersection
    SUITE["ray_intersection"]["full_shape"] = @benchmarkable intersect_ray_shape($ray, $SHAPE, $BBOX)
    
    # Multiple rays
    rays = [Ray([x, y, 1000.0], [0.0, 0.0, -1.0]) for x in -500:100:500, y in -500:100:500]
    SUITE["ray_intersection"]["multiple_rays"] = @benchmarkable begin
        for ray in $rays
            intersect_ray_shape(ray, $SHAPE, $BBOX)
        end
    end
end

# 5. Bounding box operations
SUITE["bounding_box"] = BenchmarkGroup()
SUITE["bounding_box"]["compute"] = @benchmarkable compute_bounding_box($SHAPE)
let ray = Ray([0.0, 0.0, 1000.0], [0.0, 0.0, -1.0])
    SUITE["bounding_box"]["intersection"] = @benchmarkable intersect_ray_bounding_box($ray, $BBOX)
end

# 6. Shape characteristics
SUITE["shape_characteristics"] = BenchmarkGroup()
SUITE["shape_characteristics"]["volume"] = @benchmarkable polyhedron_volume($SHAPE)
SUITE["shape_characteristics"]["equivalent_radius"] = @benchmarkable equivalent_radius($SHAPE)
SUITE["shape_characteristics"]["maximum_radius"] = @benchmarkable maximum_radius($SHAPE)
SUITE["shape_characteristics"]["minimum_radius"] = @benchmarkable minimum_radius($SHAPE)

# 7. Memory allocation benchmarks
SUITE["memory"] = BenchmarkGroup()
SUITE["memory"]["shape_model_creation"] = @benchmarkable begin
    nodes = [SA[rand(), rand(), rand()] for _ in 1:1000]
    faces = [SA[rand(1:1000), rand(1:1000), rand(1:1000)] for _ in 1:2000]
    ShapeModel(nodes, faces; find_visible_facets=false)
end

# Memory usage of visibility data structure
SUITE["memory"]["visibility_graph_size"] = @benchmarkable begin
    memory_usage($SHAPE_VIS.visibility_graph)
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
