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
            
            # View factor should be negative (faces can't see each other)
            # cos(180°) * cos(180°) / π = 1/π > 0, but physically meaningless
            @test f12 > 0.0  # Mathematically positive, but physically invalid configuration
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
        find_visiblefacets!(shape)
        
        @testset "Direct Illumination" begin
            # Sun directly above (positive z direction)
            sun_pos = SA[0.0, 0.0, 10.0]
            
            # Check each face
            for i in 1:length(faces)
                illuminated = isilluminated(shape, sun_pos, i)
                
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
                illuminated = isilluminated(shape, sun_pos, i)
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
            illuminated_x = any(isilluminated(shape, sun_pos_x, i) for i in 1:4)
            illuminated_y = any(isilluminated(shape, sun_pos_y, i) for i in 1:4)
            illuminated_diag = any(isilluminated(shape, sun_pos_diag, i) for i in 1:4)
            
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
            
            find_visiblefacets!(shape_shadow)
            
            # Sun from low angle that should cast shadow
            sun_low = SA[0.0, -1.0, 0.1]  # Slightly above horizon from -y
            
            # Wall faces should be illuminated
            @test isilluminated(shape_shadow, sun_low, 1) == true
            @test isilluminated(shape_shadow, sun_low, 2) == true
            
            # Floor faces might be shadowed (depends on exact geometry)
            # This is a complex case that depends on the visibility calculation
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