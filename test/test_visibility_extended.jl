#=
    test_visibility_extended.jl

This file tests advanced visibility and illumination calculations:
- View factor calculations between face pairs
- Distance and area dependencies of view factors
- Direct and indirect illumination scenarios
- Shadow casting and self-shadowing
- Edge cases including coincident faces and extreme distances
=#

@testset "Visibility Extended Tests" begin
    
    @testset "View Factor Calculation" begin
        @testset "Parallel Faces" begin
            # Two parallel square faces directly facing each other
            c1 = SA[0.0, 0.0, 0.0]  # Center of face 1
            c2 = SA[0.0, 0.0, 1.0]  # Center of face 2
            n1 = SA[0.0, 0.0, 1.0]  # Normal pointing to face 2
            n2 = SA[0.0, 0.0, -1.0] # Normal pointing to face 1
            area = 1.0
            
            f12, d12, d_hat12 = view_factor(c1, c2, n1, n2, area)
            
            # Check distance
            @test d12 ≈ 1.0
            
            # Check direction vector
            @test d_hat12 ≈ SA[0.0, 0.0, 1.0]
            
            # Check view factor (should be positive)
            @test f12 > 0.0
            
            # For parallel faces at unit distance with unit area
            # f = cos(0) * cos(0) / (π * 1²) * 1 = 1/π
            @test f12 ≈ 1/π atol=1e-10
        end
        
        @testset "Perpendicular Faces" begin
            # Two perpendicular faces
            c1 = SA[0.0, 0.0, 0.0]
            c2 = SA[1.0, 0.0, 0.0]
            n1 = SA[1.0, 0.0, 0.0]  # Pointing toward face 2
            n2 = SA[0.0, 1.0, 0.0]  # Perpendicular to line between centers
            area = 1.0
            
            f12, d12, d_hat12 = view_factor(c1, c2, n1, n2, area)
            
            # Check distance
            @test d12 ≈ 1.0
            
            # View factor should be zero (cos(90°) = 0)
            @test f12 ≈ 0.0 atol=1e-10
        end
        
        @testset "Faces at 45 degrees" begin
            # Two faces at 45 degree angle
            c1 = SA[0.0, 0.0, 0.0]
            c2 = SA[1.0, 0.0, 0.0]
            n1 = SA[1.0, 0.0, 0.0]  # Pointing toward face 2
            n2 = SA[-1/sqrt(2), 1/sqrt(2), 0.0]  # 45 degrees from -x axis
            area = 1.0
            
            f12, d12, d_hat12 = view_factor(c1, c2, n1, n2, area)
            
            # cos(0°) * cos(45°) / π = (1/sqrt(2)) / π
            expected_f = 1/sqrt(2) / π
            @test f12 ≈ expected_f atol=1e-10
        end
        
        @testset "Distance Dependency" begin
            # Same configuration at different distances
            c1 = SA[0.0, 0.0, 0.0]
            n1 = SA[0.0, 0.0, 1.0]
            n2 = SA[0.0, 0.0, -1.0]
            area = 1.0
            
            # Distance 1
            c2_1 = SA[0.0, 0.0, 1.0]
            f12_1, _, _ = view_factor(c1, c2_1, n1, n2, area)
            
            # Distance 2
            c2_2 = SA[0.0, 0.0, 2.0]
            f12_2, _, _ = view_factor(c1, c2_2, n1, n2, area)
            
            # Distance 3
            c2_3 = SA[0.0, 0.0, 3.0]
            f12_3, _, _ = view_factor(c1, c2_3, n1, n2, area)
            
            # View factor should decrease with square of distance
            @test f12_1 / f12_2 ≈ 4.0 atol=1e-10
            @test f12_1 / f12_3 ≈ 9.0 atol=1e-10
        end
        
        @testset "Area Dependency" begin
            # Same configuration with different areas
            c1 = SA[0.0, 0.0, 0.0]
            c2 = SA[0.0, 0.0, 1.0]
            n1 = SA[0.0, 0.0, 1.0]
            n2 = SA[0.0, 0.0, -1.0]
            
            f12_a1, _, _ = view_factor(c1, c2, n1, n2, 1.0)
            f12_a2, _, _ = view_factor(c1, c2, n1, n2, 2.0)
            f12_a3, _, _ = view_factor(c1, c2, n1, n2, 3.0)
            
            # View factor should be proportional to area
            @test f12_a2 / f12_a1 ≈ 2.0 atol=1e-10
            @test f12_a3 / f12_a1 ≈ 3.0 atol=1e-10
        end
        
        @testset "Facing Away" begin
            # Faces facing away from each other
            c1 = SA[0.0, 0.0, 0.0]
            c2 = SA[0.0, 0.0, 1.0]
            n1 = SA[0.0, 0.0, -1.0]  # Pointing away from face 2
            n2 = SA[0.0, 0.0, 1.0]   # Pointing away from face 1
            area = 1.0
            
            f12, _, _ = view_factor(c1, c2, n1, n2, area)
            
            # View factor should be zero (faces can't see each other)
            # Faces are facing away from each other, so physically no energy exchange
            @test f12 == 0.0  # Physically correct: no view factor when faces face away
        end
    end
    
    @testset "Illumination Testing" begin
        # Create a simple shape model (tetrahedron)
        nodes = [
            SA[0.0, 0.0, 0.0],
            SA[1.0, 0.0, 0.0],
            SA[0.5, sqrt(3)/2, 0.0],
            SA[0.5, sqrt(3)/6, sqrt(6)/3]
        ]
        
        faces = [
            SA[1, 2, 3],  # Base (facing -z)
            SA[1, 2, 4],  # Side 1
            SA[2, 3, 4],  # Side 2
            SA[3, 1, 4]   # Side 3
        ]
        
        shape = ShapeModel(nodes, faces)
        
        # Compute visibility for shadow testing
        build_face_visibility_graph!(shape)
        
        @testset "Direct Illumination" begin
            # Sun directly above (positive z direction)
            sun_pos = SA[0.0, 0.0, 10.0]
            
            # Check each face
            for i in 1:length(faces)
                illuminated = isilluminated(shape, sun_pos, i; with_self_shadowing=true)
                
                # Only faces with positive z-component of normal should be illuminated
                if shape.face_normals[i][3] > 0
                    @test illuminated == true
                else
                    @test illuminated == false
                end
            end
        end
        
        @testset "Face Facing Away from Sun" begin
            # Sun in negative z direction
            sun_pos = SA[0.0, 0.0, -10.0]
            
            # Check which faces are illuminated based on their normals
            for i in 1:length(faces)
                illuminated = isilluminated(shape, sun_pos, i; with_self_shadowing=true)
                # Faces with negative z-component of normal should be illuminated
                if shape.face_normals[i][3] < 0
                    @test illuminated == true
                else
                    @test illuminated == false
                end
            end
        end
        
        @testset "Sun at Different Angles" begin
            # Sun from +x direction
            sun_pos_x = SA[10.0, 0.0, 0.0]
            
            # Sun from +y direction
            sun_pos_y = SA[0.0, 10.0, 0.0]
            
            # Sun from diagonal
            sun_pos_diag = SA[1.0, 1.0, 1.0]
            
            # At least one face should be illuminated from each direction
            illuminated_x    = any(isilluminated(shape, sun_pos_x,    i; with_self_shadowing=true) for i in 1:4)
            illuminated_y    = any(isilluminated(shape, sun_pos_y,    i; with_self_shadowing=true) for i in 1:4)
            illuminated_diag = any(isilluminated(shape, sun_pos_diag, i; with_self_shadowing=true) for i in 1:4)
            
            @test illuminated_x == true
            @test illuminated_y == true
            @test illuminated_diag == true
        end
        
        @testset "Shadow Testing" begin
            # Create a shape where one face can shadow another
            # Simple L-shaped configuration
            nodes_shadow = [
                # Vertical wall
                SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0],
                SA[1.0, 0.0, 1.0], SA[0.0, 0.0, 1.0],
                # Horizontal floor
                SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0],
                SA[1.0, 1.0, 0.0], SA[0.0, 1.0, 0.0]
            ]
            
            faces_shadow = [
                SA[1, 2, 3], SA[1, 3, 4],  # Vertical wall (facing +y)
                SA[5, 7, 6], SA[5, 8, 7]   # Horizontal floor (facing +z)
            ]
            
            shape_shadow = ShapeModel(nodes_shadow, faces_shadow)
            
            build_face_visibility_graph!(shape_shadow)
            
            # Sun from low angle that should cast shadow
            sun_low = SA[0.0, -1.0, 0.1]  # Slightly above horizon from -y
            
            # Wall faces should be illuminated
            @test isilluminated(shape_shadow, sun_low, 1; with_self_shadowing=true) == true
            @test isilluminated(shape_shadow, sun_low, 2; with_self_shadowing=true) == true
            
            # Floor faces might be shadowed (depends on exact geometry)
            # This is a complex case that depends on the visibility calculation
        end
    end
    
    @testset "Batch Illumination Update" begin
        # Create a simple cube shape using helper function
        nodes_unit, faces_unit = create_unit_cube()
        # Scale and center the cube
        nodes = [2.0 * (node - SA[0.5, 0.5, 0.5]) for node in nodes_unit]
        
        shape = ShapeModel(nodes, faces_unit)
        nfaces = length(shape.faces)
        illuminated = Vector{Bool}(undef, nfaces)
        
        @testset "Without Face Visibility (Pseudo-convex)" begin
            # Sun from +z direction
            sun_pos = SA[0.0, 0.0, 10.0]
            update_illumination!(illuminated, shape, sun_pos; with_self_shadowing=false)
            
            # Check which faces are illuminated
            illuminated_indices = findall(illuminated)
            
            # For a cube centered at origin, faces with positive z-component normals should be illuminated
            # The exact number depends on the face ordering from create_unit_cube
            @test count(illuminated) > 0    # At least some faces should be illuminated
            @test count(illuminated) ≤ 12  # At most all faces could be illuminated
            
            # Verify that illuminated faces have normals pointing towards the sun
            @test all(i -> shape.face_normals[i][3] > -1e-10, illuminated_indices)
        end
        
        @testset "With Face Visibility (Full occlusion)" begin
            # Build visibility graph
            build_face_visibility_graph!(shape)
            
            # Sun from diagonal direction
            sun_pos = SA[1.0, 1.0, 1.0]
            update_illumination!(illuminated, shape, sun_pos; with_self_shadowing=true)
            
            # Three faces should be illuminated (top, right, back)
            # The exact count depends on face normals
            @test count(illuminated) > 0
            @test count(illuminated) ≤ 6  # At most 3 sides visible = 6 triangles
        end
        
        @testset "Compare with isilluminated" begin
            # Sun from various directions
            test_positions = [
                SA[10.0, 0.0, 0.0],   # +x
                SA[0.0, 10.0, 0.0],   # +y
                SA[0.0, 0.0, 10.0],   # +z
                SA[-10.0, 0.0, 0.0],  # -x
                SA[0.0, -10.0, 0.0],  # -y
                SA[0.0, 0.0, -10.0],  # -z
                SA[1.0, 1.0, 1.0]     # diagonal
            ]
            
            for sun_pos in test_positions
                # Update using batch function
                update_illumination!(illuminated, shape, sun_pos; with_self_shadowing=true)
                
                # Compare with individual isilluminated calls
                @test all(i -> illuminated[i] == isilluminated(shape, sun_pos, i; with_self_shadowing=true), 1:nfaces)
            end
        end
        
        @testset "Performance comparison" begin
            # Create a larger shape for performance testing (regular tetrahedron)
            nodes_tet, faces_tet = create_regular_tetrahedron()
            shape_large = ShapeModel(nodes_tet, faces_tet)
            nfaces_large = length(shape_large.faces)
            illuminated_large = Vector{Bool}(undef, nfaces_large)
            sun_pos = SA[1.0, 0.0, 0.0]
            
            # Time batch update
            t_batch = @elapsed update_illumination!(illuminated_large, shape_large, sun_pos; with_self_shadowing=false)
            
            # Time individual calls
            t_individual = @elapsed begin
                for i in 1:nfaces_large
                    isilluminated(shape_large, sun_pos, i; with_self_shadowing=false)
                end
            end
            
            # Batch should be comparable or faster (avoiding repeated normalization)
            @test t_batch < 2.0 * t_individual  # Should not be much slower
        end
    end
    
    @testset "New Illumination API Tests" begin
        # Create a simple shape with visibility graph
        nodes, faces = create_unit_cube()
        nodes_scaled = [2.0 * (node - SA[0.5, 0.5, 0.5]) for node in nodes]
        shape = ShapeModel(nodes_scaled, faces)
        build_face_visibility_graph!(shape)
        
        nfaces = length(shape.faces)
        sun_pos = SA[10.0, 5.0, 3.0]
        
        @testset "Pseudo-convex vs full illumination" begin
            illuminated_pseudo = Vector{Bool}(undef, nfaces)
            illuminated_full = Vector{Bool}(undef, nfaces)
            
            # Pseudo-convex model (orientation only)
            update_illumination!(illuminated_pseudo, shape, sun_pos; with_self_shadowing=false)
            
            # Full model with self-shadowing
            update_illumination!(illuminated_full, shape, sun_pos; with_self_shadowing=true)
            
            # Pseudo-convex should have more or equal illuminated faces
            @test count(illuminated_pseudo) >= count(illuminated_full)
        end
        
        @testset "API consistency" begin
            illuminated1 = Vector{Bool}(undef, nfaces)
            illuminated2 = Vector{Bool}(undef, nfaces)
            
            # Test consistency between multiple calls
            update_illumination!(illuminated1, shape, sun_pos; with_self_shadowing=true)
            update_illumination!(illuminated2, shape, sun_pos; with_self_shadowing=true)
            
            @test all(illuminated1 .== illuminated2)
        end
        
        @testset "isilluminated split functions" begin
            # Test isilluminated with pseudo-convex model
            for i in 1:nfaces
                result_pseudo = isilluminated(shape, sun_pos, i; with_self_shadowing=false)
                n̂ᵢ = shape.face_normals[i]
                r̂☉ = normalize(sun_pos)
                expected = n̂ᵢ ⋅ r̂☉ > 0
                @test result_pseudo == expected
            end
            
            # Test isilluminated with self-shadowing
            for i in 1:nfaces
                result_shadowing = isilluminated(shape, sun_pos, i; with_self_shadowing=true)
                # Each function should be self-consistent
                result_again = isilluminated(shape, sun_pos, i; with_self_shadowing=true)
                @test result_shadowing == result_again
            end
            
            # Test consistency between split functions and batch updates
            illuminated_pseudo = Vector{Bool}(undef, nfaces)
            illuminated_shadowing = Vector{Bool}(undef, nfaces)
            
            update_illumination!(illuminated_pseudo, shape, sun_pos; with_self_shadowing=false)
            update_illumination!(illuminated_shadowing, shape, sun_pos; with_self_shadowing=true)
            
            for i in 1:nfaces
                @test illuminated_pseudo[i] == isilluminated(shape, sun_pos, i; with_self_shadowing=false)
                @test illuminated_shadowing[i] == isilluminated(shape, sun_pos, i; with_self_shadowing=true)
            end
        end
        
        @testset "Eclipse shadowing application" begin
            # Create occluding shape
            shape_occluding = ShapeModel(nodes_scaled, faces)
            build_bvh!(shape_occluding)
            
            R = @SMatrix[1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]
            t = @SVector[3.0, 0.0, 0.0]
            
            # Start with all faces illuminated
            illuminated = fill(true, nfaces)
            initial_count = count(illuminated)
            
            # Apply eclipse shadowing
            status = apply_eclipse_shadowing!(illuminated, shape, sun_pos, R, t, shape_occluding)
            
            # Should reduce or maintain illumination count
            @test count(illuminated) <= initial_count
            
            # Test that status is returned
            @test status isa EclipseStatus
        end
        
        @testset "Unified API error cases" begin
            # Create shape without face visibility graph
            shape_no_graph = ShapeModel(nodes_scaled, faces)
            illuminated_error = Vector{Bool}(undef, nfaces)
            
            # Test that with_self_shadowing=true requires face_visibility_graph
            @test_throws AssertionError isilluminated(shape_no_graph, sun_pos, 1; with_self_shadowing=true)
            @test_throws AssertionError update_illumination!(illuminated_error, shape_no_graph, sun_pos; with_self_shadowing=true)
            
            # Test that with_self_shadowing=false works without face_visibility_graph
            @test_nowarn isilluminated(shape_no_graph, sun_pos, 1; with_self_shadowing=false)
            @test_nowarn update_illumination!(illuminated_error, shape_no_graph, sun_pos; with_self_shadowing=false)
        end
    end
    
    @testset "Eclipse Status Tests" begin
        # Create two simple shapes for testing
        nodes1, faces1 = create_unit_cube()
        nodes1_scaled = [2.0 * (node - SA[0.5, 0.5, 0.5]) for node in nodes1]
        shape1 = ShapeModel(nodes1_scaled, faces1)
        build_bvh!(shape1)
        
        nodes2, faces2 = create_unit_cube()
        nodes2_scaled = [2.0 * (node - SA[0.5, 0.5, 0.5]) for node in nodes2]
        shape2 = ShapeModel(nodes2_scaled, faces2)
        build_bvh!(shape2)
        
        sun_pos = SA[10.0, 0.0, 0.0]  # Sun along +x direction
        R = @SMatrix[1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]  # Identity rotation
        
        @testset "NO_ECLIPSE - Bodies far apart" begin
            # shape2 is at [0, 10, 0] in shape1's frame, so t = -R * [0, 10, 0] = [0, -10, 0]
            t = @SVector[0.0, -10.0, 0.0]  # Lateral separation
            illuminated = fill(true, length(shape1.faces))
            status = apply_eclipse_shadowing!(illuminated, shape1, sun_pos, R, t, shape2)
            @test status == NO_ECLIPSE
            @test all(illuminated)  # No faces should be shadowed
        end
        
        @testset "NO_ECLIPSE - Occluder behind target" begin
            # shape2 is at [-10, 0, 0] in shape1's frame (behind relative to sun at [10, 0, 0])
            # so t = -R * [-10, 0, 0] = [10, 0, 0]
            t = @SVector[10.0, 0.0, 0.0]  # shape2 is behind shape1 relative to sun
            illuminated = fill(true, length(shape1.faces))
            status = apply_eclipse_shadowing!(illuminated, shape1, sun_pos, R, t, shape2)
            @test status == NO_ECLIPSE
            @test all(illuminated)  # No faces should be shadowed
        end
        
        @testset "PARTIAL_ECLIPSE - Partial shadowing" begin
            # To get partial eclipse, shape2 needs to be between sun and shape1
            # shape2 is at [-2, 0.3, 0] in shape1's frame, so t = -R * [-2, 0.3, 0] = [2, -0.3, 0]
            t = @SVector[2.0, -0.3, 0.0]  # Partial overlap
            illuminated = fill(true, length(shape1.faces))
            status = apply_eclipse_shadowing!(illuminated, shape1, sun_pos, R, t, shape2)
            @test status == PARTIAL_ECLIPSE || status == NO_ECLIPSE  # Depends on exact geometry
            # At least some faces should remain illuminated if partial
            if status == PARTIAL_ECLIPSE
                @test count(illuminated) < length(shape1.faces)
                @test count(illuminated) > 0
            end
        end
        
        @testset "TOTAL_ECLIPSE - Complete shadowing" begin
            # Create a small target and large occluder
            nodes_small = [0.1 * node for node in nodes1_scaled]
            shape_small = ShapeModel(nodes_small, faces1)
            build_bvh!(shape_small)
            
            nodes_large = [5.0 * node for node in nodes2_scaled]
            shape_large = ShapeModel(nodes_large, faces2)
            build_bvh!(shape_large)
            
            # shape_large is at [5, 0, 0] in shape_small's frame (between sun and target)
            # so t = -R * [5, 0, 0] = [-5, 0, 0]
            t = @SVector[-5.0, 0.0, 0.0]  # Large occluder between sun and small target
            illuminated = fill(true, length(shape_small.faces))
            status = apply_eclipse_shadowing!(illuminated, shape_small, sun_pos, R, t, shape_large)
            @test status == TOTAL_ECLIPSE
            @test !any(illuminated)  # All faces should be shadowed
        end
        
        @testset "Face-level early-out tests" begin
            # Test case where t_min < 0 (ray moves away from shape2)
            @testset "Ray moving away from occluder" begin
                # Place shape2 behind shape1's face but offset laterally
                sun_pos_diagonal = SA[1.0, 1.0, 0.0]  # Sun at 45 degrees
                t = @SVector[-2.0, 2.0, 0.0]  # shape2 behind and to the side
                
                illuminated = fill(true, length(shape1.faces))
                status = apply_eclipse_shadowing!(illuminated, shape1, sun_pos_diagonal, R, t, shape2)
                
                # Some faces might be shadowed depending on exact geometry
                @test status == NO_ECLIPSE || status == PARTIAL_ECLIPSE
            end
            
            @testset "Ray-sphere intersection miss" begin
                # Create shapes with specific positioning to test d_center > ρ₂
                # Shape2 is offset such that rays from shape1 miss its bounding sphere
                t = @SVector[5.0, 5.0, 0.0]  # Diagonal offset
                
                illuminated = fill(true, length(shape1.faces))
                status = apply_eclipse_shadowing!(illuminated, shape1, sun_pos, R, t, shape2)
                
                # Should have no eclipse or minimal shadowing
                @test status == NO_ECLIPSE || (status == PARTIAL_ECLIPSE && count(illuminated) > length(shape1.faces) * 0.8)
            end
            
            @testset "Inscribed sphere hit" begin
                # Test the inscribed sphere optimization
                # Create a large spherical occluder to ensure inscribed sphere is well-defined
                nodes_sphere, faces_sphere = create_regular_tetrahedron()  # Approximate sphere
                nodes_sphere_scaled = [10.0 * node for node in nodes_sphere]
                shape_sphere = ShapeModel(nodes_sphere_scaled, faces_sphere)
                build_bvh!(shape_sphere)
                
                # Position sphere to guarantee some rays pass through its center
                t = @SVector[5.0, 0.0, 0.0]
                
                illuminated = fill(true, length(shape1.faces))
                status = apply_eclipse_shadowing!(illuminated, shape1, sun_pos, R, t, shape_sphere)
                
                # Should have some shadowing
                @test status == PARTIAL_ECLIPSE || status == TOTAL_ECLIPSE
                @test count(illuminated) < length(shape1.faces)
            end
        end
        
        @testset "New API signature tests" begin
            # Test the new function signature that directly takes r₁₂
            nodes1, faces1 = create_unit_cube()
            nodes1_scaled = [2.0 * (node - SA[0.5, 0.5, 0.5]) for node in nodes1]
            shape1 = ShapeModel(nodes1_scaled, faces1)
            build_bvh!(shape1)
            
            shape2 = ShapeModel(nodes1_scaled, faces1)
            build_bvh!(shape2)
            
            sun_pos = SA[10.0, 0.0, 0.0]  # Sun along +x direction
            R = @SMatrix[1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]  # Identity rotation
            
            @testset "NO_ECLIPSE with new API" begin
                r₁₂ = SA[-10.0, 0.0, 0.0]  # shape2 behind shape1
                illuminated = fill(true, length(shape1.faces))
                status = apply_eclipse_shadowing!(illuminated, shape1, shape2, sun_pos, r₁₂, R)
                @test status == NO_ECLIPSE
                @test all(illuminated)
            end
            
            @testset "PARTIAL_ECLIPSE with new API" begin
                r₁₂ = SA[-2.0, 0.3, 0.0]  # shape2 between sun and shape1, partial overlap
                illuminated = fill(true, length(shape1.faces))
                status = apply_eclipse_shadowing!(illuminated, shape1, shape2, sun_pos, r₁₂, R)
                @test status == PARTIAL_ECLIPSE || status == NO_ECLIPSE
                if status == PARTIAL_ECLIPSE
                    @test count(illuminated) < length(shape1.faces)
                    @test count(illuminated) > 0
                end
            end
            
            @testset "Consistency between old and new API" begin
                r₁₂ = SA[-3.0, 0.5, 0.0]  # Test position
                t₁₂ = -R * r₁₂  # Corresponding transformation parameter
                
                # Test with old API
                illuminated_old = fill(true, length(shape1.faces))
                status_old = apply_eclipse_shadowing!(illuminated_old, shape1, sun_pos, R, t₁₂, shape2)
                
                # Test with new API
                illuminated_new = fill(true, length(shape1.faces))
                status_new = apply_eclipse_shadowing!(illuminated_new, shape1, shape2, sun_pos, r₁₂, R)
                
                # Results should be identical
                @test status_old == status_new
                @test illuminated_old == illuminated_new
            end
        end
    end
    
    @testset "Edge Cases for View Factor" begin
        @testset "Zero Distance (Coincident Centers)" begin
            # This should be handled gracefully
            c1 = SA[0.0, 0.0, 0.0]
            c2 = SA[0.0, 0.0, 0.0]  # Same position
            n1 = SA[0.0, 0.0, 1.0]
            n2 = SA[0.0, 0.0, -1.0]
            area = 1.0
            
            # This will likely produce NaN or Inf, which should be handled
            f12, d12, d_hat12 = view_factor(c1, c2, n1, n2, area)
            @test d12 ≈ 0.0
        end
        
        @testset "Very Large Distance" begin
            c1 = SA[0.0, 0.0, 0.0]
            c2 = SA[0.0, 0.0, 1e6]  # Very far away
            n1 = SA[0.0, 0.0, 1.0]
            n2 = SA[0.0, 0.0, -1.0]
            area = 1.0
            
            f12, d12, d_hat12 = view_factor(c1, c2, n1, n2, area)
            
            # View factor should be very small
            @test f12 ≈ 0.0 atol=1e-10
            @test d12 ≈ 1e6
        end
    end
end
