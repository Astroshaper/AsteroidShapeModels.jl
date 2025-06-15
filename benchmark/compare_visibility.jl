using AsteroidShapeModels
using BenchmarkTools
using StaticArrays

# Load test shape
shape_path = joinpath(@__DIR__, "..", "test", "shape", "ryugu_test.obj")

println("=== FaceVisibilityGraph Performance Comparison ===\n")

# 1. Visibility computation performance
println("1. Visibility computation time:")
shape1 = load_shape_obj(shape_path; find_visible_facets=false)
t1 = @elapsed find_visiblefacets!(shape1, use_visibility_graph=false)
println("   Legacy implementation: $(round(t1*1000, digits=2)) ms")

shape2 = load_shape_obj(shape_path; find_visible_facets=false)
t2 = @elapsed find_visiblefacets!(shape2, use_visibility_graph=true)
println("   FaceVisibilityGraph:   $(round(t2*1000, digits=2)) ms")
println("   Speedup: $(round(t1/t2, digits=2))x")

# 2. Memory usage comparison
println("\n2. Memory usage:")
legacy_memory = sum(vf_list -> sizeof(vf_list) + length(vf_list) * sizeof(VisibleFacet), shape1.visiblefacets)
println("   Legacy (adjacency list): $(legacy_memory) bytes")

graph_memory = memory_usage(shape2.visibility_graph)
println("   FaceVisibilityGraph:     $(graph_memory) bytes")
println("   Memory reduction: $(round((1 - graph_memory/legacy_memory)*100, digits=1))%")

# 3. Query performance
println("\n3. Query performance (isilluminated):")
r_sun = SA[1000.0, 500.0, 300.0]

# Warm up
for i in 1:100
    isilluminated(shape1, r_sun, i)
    isilluminated(shape2, r_sun, i)
end

# Benchmark
b1 = @benchmark for i in 1:100
    isilluminated($shape1, $r_sun, i)
end samples=1000

b2 = @benchmark for i in 1:100
    isilluminated($shape2, $r_sun, i)
end samples=1000

println("   Legacy implementation: $(round(median(b1.times)/1000, digits=2)) μs (100 queries)")
println("   FaceVisibilityGraph:   $(round(median(b2.times)/1000, digits=2)) μs (100 queries)")
println("   Speedup: $(round(median(b1.times)/median(b2.times), digits=2))x")

# 4. Access pattern analysis
println("\n4. Visibility statistics:")
println("   Number of faces: $(length(shape2.faces))")
println("   Total visible pairs: $(shape2.visibility_graph.nnz)")
println("   Average visible faces per face: $(round(shape2.visibility_graph.nnz / length(shape2.faces), digits=2))")

# 5. Cache efficiency test
println("\n5. Cache efficiency (sequential vs random access):")

# Sequential access
indices = 1:1000
b_seq = @benchmark for i in $indices
    get_visible_faces($shape2.visibility_graph, i)
end samples=100

# Random access
random_indices = rand(1:length(shape2.faces), 1000)
b_rand = @benchmark for i in $random_indices
    get_visible_faces($shape2.visibility_graph, i)
end samples=100

println("   Sequential access: $(round(median(b_seq.times)/1000, digits=2)) μs (1000 queries)")
println("   Random access:     $(round(median(b_rand.times)/1000, digits=2)) μs (1000 queries)")
println("   Random/Sequential ratio: $(round(median(b_rand.times)/median(b_seq.times), digits=2))x")

println("\n=== Summary ===")
println("FaceVisibilityGraph provides:")
println("- $(round((1 - graph_memory/legacy_memory)*100, digits=1))% memory reduction")
println("- Better cache locality for sequential access")
println("- Consistent O(1) access time for visibility queries")