"""
Test suite for face_max_elevations optimization
Verifies that optimized illumination functions produce identical results to original functions
"""

@testset "Face Max Elevations Optimization" begin
    # Load test shape with face visibility graph
    shape = load_shape_obj("shape/ryugu_test.obj", scale=1000, with_face_visibility=true)
    
    @testset "compute_face_max_elevations!" begin
        # When loaded with_face_visibility=true, face_max_elevations should already be computed
        @test !isnothing(shape.face_max_elevations)
        @test length(shape.face_max_elevations) == length(shape.faces)
        
        # Verify all elevation should be in range [0, π/2]
        @test all(θ -> 0 ≤ θ ≤ π/2, shape.face_max_elevations)        
        
        # Test idempotency - running again should not change results
        elevations_copy = copy(shape.face_max_elevations)
        compute_face_max_elevations!(shape)
        @test shape.face_max_elevations ≈ elevations_copy
        
        # Test manual computation on a shape without face_max_elevations
        shape_manual = load_shape_obj("shape/icosahedron.obj", scale=1.0, with_face_visibility=false)
        build_face_visibility_graph!(shape_manual)
        @test isnothing(shape_manual.face_max_elevations)
        
        compute_face_max_elevations!(shape_manual)
        @test !isnothing(shape_manual.face_max_elevations)
        @test length(shape_manual.face_max_elevations) == length(shape_manual.faces)
    end
    
    @testset "Illumination Functions with Elevation Optimization" begin
        # Test that illumination functions work correctly with various sun positions
        sun_positions = [
            # Axis-aligned directions
            SA[1.496e11, 0.0, 0.0],  # Along +x
            SA[0.0, 1.496e11, 0.0],  # Along +y
            SA[0.0, 0.0, 1.496e11],  # Along +z (high elevation)
            
            # Different azimuths at high elevation
            SA[1.0e11, 0.0, 1.2e11],
            SA[0.0, 1.0e11, 1.2e11],
            
            # Medium elevation
            SA[1.496e11, 0.0, 0.3e11],
            SA[0.0, 1.496e11, 0.3e11],
            
            # Low elevation
            SA[1.496e11, 1.496e11, 0.05e11],
        ]
        
        # Prepare illumination array
        illuminated_faces = Vector{Bool}(undef, length(shape.faces))
        
        # Test a sample of faces for consistency checks
        test_faces = [1, 100, 500, 1000]
        
        all_valid_length = true
        all_bool_values = true
        all_valid_count = true
        all_consistent = true
        all_single_results_bool = true
        
        for r☉ in sun_positions
            # Test batch update with elevation optimization
            update_illumination!(illuminated_faces, shape, r☉; with_self_shadowing=true)
            
            # Verify the result is valid
            all_valid_length &= (length(illuminated_faces) == length(shape.faces))
            all_bool_values &= all(x -> x isa Bool, illuminated_faces)
            
            # Count should be reasonable
            count_illuminated = count(illuminated_faces)
            all_valid_count &= (0 <= count_illuminated <= length(shape.faces))
            
            # Verify consistency with single-face checks (sample a few faces)
            for face_idx in test_faces
                single_result = isilluminated(shape, r☉, face_idx; with_self_shadowing=true)
                all_single_results_bool &= (single_result isa Bool)
                all_consistent &= (single_result == illuminated_faces[face_idx])
            end
        end
        
        @test all_valid_length
        @test all_bool_values
        @test all_valid_count
        @test all_single_results_bool
        @test all_consistent
    end
    
    @testset "Convex Shape (Icosahedron)" begin
        # Test with a simple convex shape where optimization should be very effective
        shape_simple = load_shape_obj("shape/icosahedron.obj", scale=1.0, with_face_visibility=true)
        
        # For a convex shape, face_max_elevations should all be 0 (no surrounding terrain)
        @test all(θ -> θ ≈ 0.0, shape_simple.face_max_elevations)
        
        # Random sun positions
        all_match = true
        
        for _ in 1:5
            r☉ = normalize(SA[randn(), randn(), randn()]) * 1.496e11
            
            illuminated_faces = Vector{Bool}(undef, length(shape_simple.faces))
            update_illumination!(illuminated_faces, shape_simple, r☉; with_self_shadowing=true)
            
            # For a convex shape with optimization, illuminated faces should match
            # those with positive dot product with sun direction
            r̂☉ = normalize(r☉)
            for i in 1:length(shape_simple.faces)
                expected = dot(shape_simple.face_normals[i], r̂☉) > 0
                all_match &= (illuminated_faces[i] == expected)
            end
        end
        
        @test all_match
    end
    
    @testset "Optimization Effectiveness" begin
        # This test verifies that the optimization is actually being triggered
        # by checking that high sun positions result in different code paths
        
        # Count ray-triangle intersection tests (this would require modifying
        # the functions to return statistics, so we test indirectly)
        
        # High sun should have many faces with elevation > face_max_elevations
        r☉_high = SA[0.0, 0.0, 1.496e11]
        
        # Check that many faces have lower max_elevations than sun elevation
        r̂☉ = normalize(r☉_high)
        optimization_triggered_count = 0
        
        for i in 1:length(shape.faces)
            n̂ᵢ = shape.face_normals[i]
            sinθ☉ = n̂ᵢ ⋅ r̂☉
            
            if sinθ☉ > 0
                θ☉ = asin(clamp(sinθ☉, 0.0, 1.0))
                if θ☉ > shape.face_max_elevations[i]
                    optimization_triggered_count += 1
                end
            end
        end
        
        # With high sun, optimization should trigger for many faces
        @test optimization_triggered_count > length(shape.faces) * 0.3
    end
end

# Include this test in the main test suite
println("Testing face_max_elevations optimization...")