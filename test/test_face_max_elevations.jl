"""
Test suite for face_max_elevations optimization
Verifies that optimized illumination functions produce identical results to original functions
"""

@testset "Face Max Elevations Optimization" begin
    # Load test shape with face visibility graph
    shape = load_shape_obj("shape/ryugu_test.obj", scale=1000, with_face_visibility=true)
    
    @testset "compute_face_max_elevations!" begin
        # Test initialization
        @test isnothing(shape.face_max_elevations)
        
        # Compute face max elevations
        compute_face_max_elevations!(shape)
        
        # Verify field is populated
        @test !isnothing(shape.face_max_elevations)
        @test length(shape.face_max_elevations) == length(shape.faces)
        
        # Verify all elevation should be in range [0, π/2]
        @test all(θ -> 0 ≤ θ ≤ π/2, shape.face_max_elevations)        
        
        # Test idempotency - running again should not change results
        elevations_copy = copy(shape.face_max_elevations)
        compute_face_max_elevations!(shape)
        @test shape.face_max_elevations ≈ elevations_copy
    end
    
    @testset "Result Consistency - Single Face" begin
        # Create various sun positions
        sun_positions = [
            # High elevation (should trigger optimization)
            SA[0.0, 0.0, 1.496e11],  # Directly above (90°)
            SA[1.0e11, 0.0, 1.0e11],  # 45° elevation
            
            # Medium elevation
            SA[1.496e11, 0.0, 0.5e11],  # ~18.4° elevation
            
            # Low elevation (less likely to trigger optimization)
            SA[1.496e11, 0.0, 0.1e11],  # ~3.8° elevation
            SA[1.496e11, 0.0, 0.0],     # On horizon (0°)
        ]
        
        # Test each face with various sun positions
        test_faces = [1, length(shape.faces)÷4, length(shape.faces)÷2, length(shape.faces)]
        
        for face_idx in test_faces
            for r☉ in sun_positions
                # Original implementation
                result_original = isilluminated(shape, r☉, face_idx; with_self_shadowing=true)
                
                # Optimized implementation
                result_optimized = isilluminated_with_self_shadowing_optimized(shape, r☉, face_idx)
                
                # Results must match exactly
                @test result_original == result_optimized
            end
        end
    end
    
    @testset "Result Consistency - Batch Update" begin
        # Prepare illumination arrays
        illuminated_original  = Vector{Bool}(undef, length(shape.faces))
        illuminated_optimized = Vector{Bool}(undef, length(shape.faces))
        
        # Test with various sun positions
        sun_positions = [
            # Different azimuths at high elevation
            SA[1.0e11, 0.0, 1.2e11],
            SA[0.0, 1.0e11, 1.2e11],
            SA[-1.0e11, 0.0, 1.2e11],
            SA[0.0, -1.0e11, 1.2e11],
            
            # Different azimuths at medium elevation
            SA[1.496e11, 0.0, 0.3e11],
            SA[0.0, 1.496e11, 0.3e11],
            
            # Low elevation
            SA[1.496e11, 1.496e11, 0.05e11],
        ]
        
        for r☉ in sun_positions
            # Original batch update
            update_illumination!(illuminated_original, shape, r☉; with_self_shadowing=true)
            
            # Optimized batch update
            update_illumination_with_self_shadowing_optimized!(illuminated_optimized, shape, r☉)
            
            # Results must match for all faces
            @test illuminated_original == illuminated_optimized
            
            # Additional check: count of illuminated faces should match
            @test count(illuminated_original) == count(illuminated_optimized)
        end
    end
    
    @testset "Different Shape Models" begin
        # Test with a simple shape (icosahedron)
        shape_simple = load_shape_obj("shape/icosahedron.obj", scale=1.0, with_face_visibility=true)
        compute_face_max_elevations!(shape_simple)
        
        # Random sun positions
        for _ in 1:10
            r☉ = SA[randn(), randn(), randn()] * 1.496e11
            
            illuminated_original = Vector{Bool}(undef, length(shape_simple.faces))
            illuminated_optimized = Vector{Bool}(undef, length(shape_simple.faces))
            
            update_illumination!(illuminated_original, shape_simple, r☉; with_self_shadowing=true)
            update_illumination_with_self_shadowing_optimized!(illuminated_optimized, shape_simple, r☉)
            
            @test illuminated_original == illuminated_optimized
        end
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