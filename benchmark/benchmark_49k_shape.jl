using AsteroidShapeModels
using BenchmarkTools
using Downloads
using StaticArrays
using Statistics

println("=== 49k Shape Model Benchmark ===\n")

# Download the 49k shape model if it doesn't exist
shape_filename = "SHAPE_SFM_49k_v20180804.obj"
shape_url = "https://data.darts.isas.jaxa.jp/pub/hayabusa2/paper/Watanabe_2019/$shape_filename"
shape_filepath = joinpath(@__DIR__, "shape", shape_filename)
mkpath(dirname(shape_filepath))
isfile(shape_filepath) || Downloads.download(shape_url, shape_filepath)

println("Loading high-resolution shape model...")
shape_base = @time load_shape_obj(shape_filepath; find_visible_facets=false)

println("\nShape model statistics:")
println("  Nodes: $(length(shape_base.nodes))")
println("  Faces: $(length(shape_base.faces))")

# 1. Benchmark visibility computation
println("\n1. Visibility computation:")

shape = deepcopy(shape_base)
GC.gc()
t_elapsed = @elapsed find_visiblefacets!(shape)
println("   Time                : $(round(t_elapsed, digits=3)) seconds")

# Count visible pairs
total_visible = shape.visibility_graph.nnz
println("   Total visible pairs : $total_visible")

# Memory usage
graph_memory = Base.summarysize(shape.visibility_graph)
println("   Memory usage        : $(round(graph_memory / 1024^2, digits=2)) MB")

# 2. Query performance benchmark
println("\n2. Query performance (isilluminated):")
r_sun = SA[1000.0, 500.0, 300.0]
n_queries = 1000

# Warm up
for i in 1:100
    isilluminated(shape, r_sun, i)
end

# Benchmark
b_illuminated = @benchmark for i in 1:$n_queries
    isilluminated($shape, $r_sun, mod1(i, length($shape.faces)))
end samples=100

println("   Time per query      : $(round(median(b_illuminated.times) / n_queries / 1000, digits=2)) μs")
println("   Total time          : $(round(median(b_illuminated.times) / 1000, digits=2)) μs ($n_queries queries)")

# 3. Memory access pattern analysis
println("\n3. Memory access patterns:")

# Sequential access
seq_indices = 1:min(5000, length(shape.faces))
b_seq = @benchmark for i in $seq_indices
    num_visible_faces($shape.visibility_graph, i)
end samples=100

# Random access
rand_indices = rand(1:length(shape.faces), length(seq_indices))
b_rand = @benchmark for i in $rand_indices
    num_visible_faces($shape.visibility_graph, i)
end samples=100

println("   Sequential access       : $(round(median(b_seq.times) / 1000, digits=2)) μs ($(length(seq_indices)) queries)")
println("   Random access           : $(round(median(b_rand.times) / 1000, digits=2)) μs ($(length(rand_indices)) queries)")
println("   Random/Sequential ratio : $(round(median(b_rand.times) / median(b_seq.times), digits=2))x")

# 4. Detailed visibility statistics
println("\n4. Visibility statistics:")
if !isnothing(shape.visibility_graph)
    visible_counts = [num_visible_faces(shape.visibility_graph, i) for i in 1:shape.visibility_graph.nfaces]
    println("   Average visible faces per face : $(round(mean(visible_counts), digits=2))")
    println("   Maximum visible faces          : $(maximum(visible_counts))")
    println("   Minimum visible faces          : $(minimum(visible_counts))")
    println("   Faces with no visibility       : $(count(==(0), visible_counts))")
end

println("\n=== Benchmark Complete ===")