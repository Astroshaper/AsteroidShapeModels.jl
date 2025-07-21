using AsteroidShapeModels
using BenchmarkTools
using LinearAlgebra
using Printf
using Random
using StaticArrays
using Statistics

# Function to generate sun positions for one asteroid rotation
function generate_sun_positions_rotation()
    positions = Vector{SVector{3,Float64}}()
    
    # 72 steps for one full rotation (5 degree increments)
    n_steps = 72
    
    # Sun always on the equatorial plane (z = 0)
    for i in 0:(n_steps-1)
        angle = 2π * i / n_steps  # Rotation angle in radians
        
        # Sun position in asteroid-fixed frame
        # As asteroid rotates, sun appears to move in opposite direction
        x = cos(-angle)
        y = sin(-angle)
        z = 0.0
        
        push!(positions, SA[x, y, z])
    end
    
    return positions
end

# Function to verify results match between optimization on/off
function verify_results_match(shape_vis, sun_positions)
    println("\nVerifying results consistency...")
    
    mismatches = 0
    total_checks = 0
    
    for (i, r☉) in enumerate(sun_positions)
        for face_idx in 1:length(shape_vis.faces)
            result_with_opt = isilluminated(shape_vis, r☉, face_idx; 
                                           with_self_shadowing=true, 
                                           use_elevation_optimization=true)
            result_without_opt = isilluminated(shape_vis, r☉, face_idx; 
                                             with_self_shadowing=true, 
                                             use_elevation_optimization=false)
            
            if result_with_opt != result_without_opt
                mismatches += 1
                if mismatches <= 5  # Print first few mismatches
                    println(
                        "  Mismatch at sun position $i, face $face_idx: " *
                        "with_opt=$result_with_opt, without_opt=$result_without_opt"
                    )
                end
            end
            total_checks += 1
        end
    end
    
    if mismatches == 0
        println("  ✓ All results match perfectly! ($total_checks checks)")
    else
        println("  ✗ Found $mismatches mismatches out of $total_checks checks")
    end
    
    return mismatches == 0
end

# Function to analyze optimization effectiveness
function analyze_optimization_effectiveness(shape_vis, sun_positions)
    println("\nAnalyzing optimization effectiveness...")
    
    # Track how often the optimization kicks in
    optimization_used_count = 0
    total_faces_checked = 0
    
    for r☉ in sun_positions
        # Calculate sun elevation for this position
        sun_unit = normalize(r☉)
        
        for face_idx in 1:length(shape_vis.faces)
            total_faces_checked += 1
            
            # Get face center and normal
            v1, v2, v3 = get_face_nodes(shape_vis, face_idx)
            face_nodes = SA[v1, v2, v3]
            fc = face_center(face_nodes)
            fn = face_normal(face_nodes)
            
            # Check if face is facing the sun
            if dot(fn, sun_unit) > 0
                # Calculate elevation angle from face to sun
                to_sun = sun_unit - fc
                horizontal_dist = sqrt(to_sun[1]^2 + to_sun[2]^2)
                elevation_angle = atan(to_sun[3], horizontal_dist)
                
                # Check if optimization would skip this face
                if shape_vis.face_max_elevations !== nothing && 
                    elevation_angle > shape_vis.face_max_elevations[face_idx]
                        optimization_used_count += 1
                end
            end
        end
    end
    
    effectiveness = optimization_used_count / total_faces_checked * 100
    println(
        "  Optimization triggered for $(optimization_used_count)/$(total_faces_checked) " *
        "checks ($(round(effectiveness, digits=1))%)"
    )
    
    return effectiveness
end

# Main benchmark function
function benchmark_illumination()
    println("=" ^ 70)
    println("Illumination Benchmarking Suite")
    println("=" ^ 70)
    
    # Load shape models
    println("\nLoading shape models...")
    
    # Small test model
    shape_path_small = joinpath(@__DIR__, "..", "test", "shape", "ryugu_test.obj")
    shape_small = load_shape_obj(shape_path_small; with_face_visibility=false, with_bvh=true)
    shape_small_vis = load_shape_obj(shape_path_small; with_face_visibility=true, with_bvh=true)
    println("  Small model loaded: $(length(shape_small.faces)) faces")
    
    # Large 49k model
    shape_path_49k = joinpath(@__DIR__, "shape", "SHAPE_SFM_49k_v20180804.obj")
    if isfile(shape_path_49k)
        shape_49k = load_shape_obj(shape_path_49k; with_face_visibility=false, with_bvh=true)
        shape_49k_vis = load_shape_obj(shape_path_49k; with_face_visibility=true, with_bvh=true)
        println("  49k model loaded: $(length(shape_49k.faces)) faces")
    else
        println("  ⚠ 49k model not found at: $shape_path_49k")
        shape_49k = nothing
        shape_49k_vis = nothing
    end
    
    # Generate sun positions for one full rotation
    sun_positions = generate_sun_positions_rotation()
    println("\nGenerated $(length(sun_positions)) sun positions for one full rotation (5° increments)")
    
    # Create benchmark suite
    suite = BenchmarkGroup()
    
    # Small model benchmarks
    println("\n" * ("=" ^ 50))
    println("Small Model Benchmarks ($(length(shape_small.faces)) faces)")
    println("=" ^ 50)
    
    # Verify results match
    @assert verify_results_match(shape_small_vis, sun_positions[1:3])
    
    # Analyze optimization effectiveness
    effectiveness_small = analyze_optimization_effectiveness(shape_small_vis, sun_positions)
    
    # Benchmark different illumination modes
    suite["small_model"] = BenchmarkGroup()
    
    # (1) Pseudo-convex model
    suite["small_model"]["pseudo_convex"] = @benchmarkable begin
        for r☉ in $sun_positions
            for face_idx in 1:length($shape_small.faces)
                isilluminated($shape_small, r☉, face_idx; with_self_shadowing=false)
            end
        end
    end
    
    # (2) Self-shadowing without optimization
    suite["small_model"]["self_shadowing_no_opt"] = @benchmarkable begin
        for r☉ in $sun_positions
            for face_idx in 1:length($shape_small_vis.faces)
                isilluminated(
                    $shape_small_vis, r☉, face_idx; 
                    with_self_shadowing=true, 
                    use_elevation_optimization=false,
                )
            end
        end
    end
    
    # (3) Self-shadowing with optimization
    suite["small_model"]["self_shadowing_with_opt"] = @benchmarkable begin
        for r☉ in $sun_positions
            for face_idx in 1:length($shape_small_vis.faces)
                isilluminated(
                    $shape_small_vis, r☉, face_idx; 
                    with_self_shadowing=true, 
                    use_elevation_optimization=true,
                )
            end
        end
    end
    
    # 49k model benchmarks (if available)
    if shape_49k !== nothing
        println("\n" * ("=" ^ 50))
        println("49k Model Benchmarks ($(length(shape_49k.faces)) faces)")
        println("=" ^ 50)
        
        # Verify results match (use fewer positions for large model)
        @assert verify_results_match(shape_49k_vis, sun_positions[1:1])
        
        # Analyze optimization effectiveness
        effectiveness_49k = analyze_optimization_effectiveness(shape_49k_vis, sun_positions)
        
        suite["49k_model"] = BenchmarkGroup()
        
        # Use all sun positions for 49k model (full rotation)
        sun_positions_49k = sun_positions
        
        # (1) Pseudo-convex model
        suite["49k_model"]["pseudo_convex"] = @benchmarkable begin
            for r☉ in $sun_positions_49k
                for face_idx in 1:length($shape_49k.faces)
                    isilluminated($shape_49k, r☉, face_idx; with_self_shadowing=false)
                end
            end
        end
        
        # (2) Self-shadowing without optimization
        suite["49k_model"]["self_shadowing_no_opt"] = @benchmarkable begin
            for r☉ in $sun_positions_49k
                for face_idx in 1:length($shape_49k_vis.faces)
                    isilluminated(
                        $shape_49k_vis, r☉, face_idx; 
                        with_self_shadowing=true, 
                        use_elevation_optimization=false,
                    )
                end
            end
        end
        
        # (3) Self-shadowing with optimization
        suite["49k_model"]["self_shadowing_with_opt"] = @benchmarkable begin
            for r☉ in $sun_positions_49k
                for face_idx in 1:length($shape_49k_vis.faces)
                    isilluminated(
                        $shape_49k_vis, r☉, face_idx; 
                        with_self_shadowing=true, 
                        use_elevation_optimization=true,
                    )
                end
            end
        end
    end
    
    # Run benchmarks
    println("\n" * ("=" ^ 50))
    println("Running Benchmarks...")
    println("=" ^ 50)
    
    results = run(suite; verbose=true, seconds=5)
    
    # Display results
    println("\n" * ("=" ^ 70))
    println("Benchmark Results Summary")
    println("=" ^ 70)
    
    # Small model results
    if haskey(results, "small_model")
        println("\nSmall Model ($(length(shape_small.faces)) faces):")
        println("  Total calculations: $(length(shape_small.faces)) faces × $(length(sun_positions)) steps = $(length(shape_small.faces) * length(sun_positions)) illumination checks")
        println("  Optimization effectiveness: $(round(effectiveness_small, digits=1))%")
        println()
        
        pseudo_convex_time = median(results["small_model"]["pseudo_convex"]).time
        no_opt_time = median(results["small_model"]["self_shadowing_no_opt"]).time
        with_opt_time = median(results["small_model"]["self_shadowing_with_opt"]).time
        
        println("  Pseudo-convex model       : $(format_time(pseudo_convex_time))")
        println("  Self-shadowing (no opt)   : $(format_time(no_opt_time))")
        println("  Self-shadowing (with opt) : $(format_time(with_opt_time))")
        println()
        println("  Speedup from optimization : $(round(no_opt_time / with_opt_time, digits=2))x")
    end
    
    # 49k model results
    if shape_49k !== nothing && haskey(results, "49k_model")
        println("\n49k Model ($(length(shape_49k.faces)) faces):")
        println("  Total calculations: $(length(shape_49k.faces)) faces × $(length(sun_positions)) steps = $(length(shape_49k.faces) * length(sun_positions)) illumination checks")
        println("  Optimization effectiveness: $(round(effectiveness_49k, digits=1))%")
        println()
        
        pseudo_convex_time = median(results["49k_model"]["pseudo_convex"]).time
        no_opt_time = median(results["49k_model"]["self_shadowing_no_opt"]).time
        with_opt_time = median(results["49k_model"]["self_shadowing_with_opt"]).time
        
        println("  Pseudo-convex model       : $(format_time(pseudo_convex_time))")
        println("  Self-shadowing (no opt)   : $(format_time(no_opt_time))")
        println("  Self-shadowing (with opt) : $(format_time(with_opt_time))")
        println()
        println("  Speedup from optimization : $(round(no_opt_time / with_opt_time, digits=2))x")
    end
    
    println("\n" * ("=" ^ 70))
    
    return results
end

# Helper function to format time nicely
function format_time(nanoseconds)
    if nanoseconds < 1e3
        return @sprintf("%.1f ns", nanoseconds)
    elseif nanoseconds < 1e6
        return @sprintf("%.1f μs", nanoseconds / 1e3)
    elseif nanoseconds < 1e9
        return @sprintf("%.1f ms", nanoseconds / 1e6)
    else
        return @sprintf("%.2f s", nanoseconds / 1e9)
    end
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    benchmark_illumination()
end
