using AsteroidShapeModels
using BenchmarkTools
using StaticArrays

# Load test shape
shape_path = joinpath(@__DIR__, "..", "test", "shape", "ryugu_test.obj")

println("=== FaceVisibilityGraph Performance Analysis ===\n")

# 1. Visibility computation performance
println("1. Visibility computation time:")
shape = load_shape_obj(shape_path; with_face_visibility=false)
t_elapsed = @elapsed build_face_visibility_graph!(shape)
println("   Time: $(round(t_elapsed*1000, digits=2)) ms")

# 2. Memory usage
println("\n2. Memory usage:")
graph_memory = Base.summarysize(shape.face_visibility_graph)
println("   FaceVisibilityGraph: $(graph_memory) bytes")
println("   Memory per face: $(round(graph_memory / length(shape.faces), digits=2)) bytes")
println("   Memory per visible pair: $(round(graph_memory / shape.face_visibility_graph.nnz, digits=2)) bytes")

# 3. Query performance
println("\n3. Query performance (isilluminated):")
r_sun = SA[1000.0, 500.0, 300.0]

# Warm up
for i in 1:100
    isilluminated(shape, r_sun, i)
end

# Benchmark
b_query = @benchmark for i in 1:100
    isilluminated($shape, $r_sun, i)
end samples=1000

println("   Time: $(round(median(b_query.times)/1000, digits=2)) μs (100 queries)")
println("   Time per query: $(round(median(b_query.times)/100, digits=2)) ns")

# 4. Access pattern analysis
println("\n4. Visibility statistics:")
println("   Number of faces: $(length(shape.faces))")
println("   Total visible pairs: $(shape.face_visibility_graph.nnz)")
println("   Average visible faces per face: $(round(shape.face_visibility_graph.nnz / length(shape.faces), digits=2))")

# Distribution of visible faces
visible_counts = [num_visible_faces(shape.face_visibility_graph, i) for i in 1:shape.face_visibility_graph.nfaces]
println("   Max visible faces for a single face: $(maximum(visible_counts))")
println("   Min visible faces for a single face: $(minimum(visible_counts))")

# 5. Cache efficiency test
println("\n5. Cache efficiency (sequential vs random access):")

# Sequential access
indices = 1:1000
b_seq = @benchmark for i in $indices
    get_visible_face_indices($shape.face_visibility_graph, i)
end samples=100

# Random access
random_indices = rand(1:length(shape.faces), 1000)
b_rand = @benchmark for i in $random_indices
    get_visible_face_indices($shape.face_visibility_graph, i)
end samples=100

println("   Sequential access: $(round(median(b_seq.times)/1000, digits=2)) μs (1000 queries)")
println("   Random access:     $(round(median(b_rand.times)/1000, digits=2)) μs (1000 queries)")
println("   Random/Sequential ratio: $(round(median(b_rand.times)/median(b_seq.times), digits=2))x")

println("\n=== Summary ===")
println("FaceVisibilityGraph CSR format provides:")
println("- Efficient memory usage: $(round(graph_memory / 1024, digits=2)) KB total")
println("- Fast visibility queries: $(round(median(b_query.times)/100, digits=2)) ns per query")
println("- Good cache locality for sequential access")