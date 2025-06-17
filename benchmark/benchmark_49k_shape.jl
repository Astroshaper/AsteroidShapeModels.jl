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
println("\n1. Visibility computation benchmark:")

# Legacy implementation
println("\n  a) Legacy implementation (adjacency list):")
shape_legacy = deepcopy(shape_base)
GC.gc()
t_legacy = @elapsed find_visiblefacets!(shape_legacy, use_visibility_graph=false)
println("       Time                : $(round(t_legacy, digits=3)) seconds")

# Count visible pairs
total_visible_legacy = sum(length.(shape_legacy.visiblefacets))
println("       Total visible pairs : $total_visible_legacy")

# Memory usage estimation
legacy_memory = sum(vf_list -> sizeof(vf_list) + length(vf_list) * sizeof(VisibleFacet), shape_legacy.visiblefacets)
println("       Estimated memory    : $(round(legacy_memory / 1024^2, digits=2)) MB")

# New implementation
println("\n  b) FaceVisibilityGraph implementation:")
shape_graph = deepcopy(shape_base)
GC.gc()
t_graph = @elapsed find_visiblefacets!(shape_graph, use_visibility_graph=true)
println("       Time                : $(round(t_graph, digits=3)) seconds")

# Verify results match
total_visible_graph = shape_graph.visibility_graph.nnz
println("       Total visible pairs : $total_visible_graph")

graph_memory = Base.summarysize(shape_graph.visibility_graph)
println("       Memory usage        : $(round(graph_memory / 1024^2, digits=2)) MB")

# Summary
println("\n  c) Performance improvement:")
println("       Speed up         : $(round(t_legacy / t_graph, digits=2))x")
println("       Memory reduction : $(round((1 - graph_memory / legacy_memory) * 100, digits=1))%")

# 2. Query performance benchmark
println("\n2. Query performance (isilluminated):")
r_sun = SA[1000.0, 500.0, 300.0]
n_queries = 1000

# Warm up
for i in 1:100
    isilluminated(shape_legacy, r_sun, i)
    isilluminated(shape_graph, r_sun, i)
end

# Legacy benchmark
b_legacy = @benchmark for i in 1:$n_queries
    isilluminated($shape_legacy, $r_sun, mod1(i, length($shape_legacy.faces)))
end samples=100

# Graph benchmark
b_graph = @benchmark for i in 1:$n_queries
    isilluminated($shape_graph, $r_sun, mod1(i, length($shape_graph.faces)))
end samples=100

println("  Legacy implementation : $(round(median(b_legacy.times) / 1000, digits=2)) μs ($n_queries queries)")
println("  FaceVisibilityGraph   : $(round(median(b_graph.times) / 1000, digits=2)) μs ($n_queries queries)")
println("  Speed ratio           : $(round(median(b_legacy.times) / median(b_graph.times), digits=2))x")

# 3. Memory access pattern analysis
println("\n3. Memory access patterns:")

# Sequential access
seq_indices = 1:min(5000, length(shape_graph.faces))
b_seq = @benchmark for i in $seq_indices
    num_visible_faces($shape_graph.visibility_graph, i)
end samples=100

# Random access
rand_indices = rand(1:length(shape_graph.faces), length(seq_indices))
b_rand = @benchmark for i in $rand_indices
    num_visible_faces($shape_graph.visibility_graph, i)
end samples=100

println("  Sequential access       : $(round(median(b_seq.times) / 1000, digits=2)) μs ($(length(seq_indices)) queries)")
println("  Random access           : $(round(median(b_rand.times) / 1000, digits=2)) μs ($(length(rand_indices)) queries)")
println("  Random/Sequential ratio : $(round(median(b_rand.times) / median(b_seq.times), digits=2))x")

# 4. Detailed visibility statistics
println("\n4. Visibility statistics:")
if !isnothing(shape_graph.visibility_graph)
    visible_counts = [num_visible_faces(shape_graph.visibility_graph, i) for i in 1:shape_graph.visibility_graph.nfaces]
    println("  Average visible faces per face : $(round(mean(visible_counts), digits=2))")
    println("  Maximum visible faces          : $(maximum(visible_counts))")
    println("  Minimum visible faces          : $(minimum(visible_counts))")
    println("  Faces with no visibility       : $(count(==(0), visible_counts))")
end

println("\n=== Benchmark Complete ===")