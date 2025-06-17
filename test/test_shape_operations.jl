@testset "Shape Operations Tests" begin
    
    @testset "Polyhedron Volume" begin
        @testset "Unit Cube" begin
            # Define unit cube vertices
            nodes = [
                SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0],
                SA[1.0, 1.0, 0.0], SA[0.0, 1.0, 0.0],
                SA[0.0, 0.0, 1.0], SA[1.0, 0.0, 1.0],
                SA[1.0, 1.0, 1.0], SA[0.0, 1.0, 1.0],
            ]
            
            # Define faces (triangulated cube) - corrected orientation
            faces = [
                SA[1, 3, 2], SA[1, 4, 3],  # Bottom face (z=0)
                SA[5, 6, 7], SA[5, 7, 8],  # Top face (z=1)
                SA[1, 2, 6], SA[1, 6, 5],  # Front face (y=0)
                SA[4, 8, 7], SA[4, 7, 3],  # Back face (y=1)
                SA[1, 5, 8], SA[1, 8, 4],  # Left face (x=0)
                SA[2, 3, 7], SA[2, 7, 6],  # Right face (x=1)
            ]
            
            volume = polyhedron_volume(nodes, faces)
            @test volume ≈ 1.0 atol=1e-10
        end
        
        @testset "Unit Tetrahedron" begin
            # Regular tetrahedron with unit edges
            nodes = [
                SA[0.0, 0.0, 0.0],
                SA[1.0, 0.0, 0.0],
                SA[0.5, sqrt(3)/2, 0.0],
                SA[0.5, sqrt(3)/6, sqrt(6)/3]
            ]
            
            faces = [
                SA[1, 2, 3],  # Base
                SA[1, 2, 4],  # Side 1
                SA[2, 3, 4],  # Side 2
                SA[3, 1, 4]   # Side 3
            ]
            
            volume = polyhedron_volume(nodes, faces)
            expected_volume = 1 / (6 * sqrt(2))  # Analytical formula
            @test volume ≈ expected_volume atol=1e-10
        end
        
        @testset "Translated Shape" begin
            # Unit cube translated by [10, 10, 10]
            offset = SA[10.0, 10.0, 10.0]
            nodes = [
                offset + SA[0.0, 0.0, 0.0], offset + SA[1.0, 0.0, 0.0],
                offset + SA[1.0, 1.0, 0.0], offset + SA[0.0, 1.0, 0.0],
                offset + SA[0.0, 0.0, 1.0], offset + SA[1.0, 0.0, 1.0],
                offset + SA[1.0, 1.0, 1.0], offset + SA[0.0, 1.0, 1.0],
            ]
            
            faces = [
                SA[1, 3, 2], SA[1, 4, 3],  # Bottom face (z=0)
                SA[5, 6, 7], SA[5, 7, 8],  # Top face (z=1)
                SA[1, 2, 6], SA[1, 6, 5],  # Front face (y=0)
                SA[4, 8, 7], SA[4, 7, 3],  # Back face (y=1)
                SA[1, 5, 8], SA[1, 8, 4],  # Left face (x=0)
                SA[2, 3, 7], SA[2, 7, 6],  # Right face (x=1)
            ]
            
            volume = polyhedron_volume(nodes, faces)
            @test volume ≈ 1.0 atol=1e-10
        end
        
        @testset "Scaled Shape" begin
            # Unit cube scaled by factor 2
            scale = 2.0
            nodes = [
                SA[0.0, 0.0, 0.0] * scale, SA[1.0, 0.0, 0.0] * scale,
                SA[1.0, 1.0, 0.0] * scale, SA[0.0, 1.0, 0.0] * scale,
                SA[0.0, 0.0, 1.0] * scale, SA[1.0, 0.0, 1.0] * scale,
                SA[1.0, 1.0, 1.0] * scale, SA[0.0, 1.0, 1.0] * scale,
            ]
            
            faces = [
                SA[1, 3, 2], SA[1, 4, 3],  # Bottom face (z=0)
                SA[5, 6, 7], SA[5, 7, 8],  # Top face (z=1)
                SA[1, 2, 6], SA[1, 6, 5],  # Front face (y=0)
                SA[4, 8, 7], SA[4, 7, 3],  # Back face (y=1)
                SA[1, 5, 8], SA[1, 8, 4],  # Left face (x=0)
                SA[2, 3, 7], SA[2, 7, 6],  # Right face (x=1)
            ]
            
            volume = polyhedron_volume(nodes, faces)
            @test volume ≈ scale^3 atol=1e-10
        end
        
        @testset "Single Triangle (Zero Volume)" begin
            nodes = [
                SA[0.0, 0.0, 0.0],
                SA[1.0, 0.0, 0.0],
                SA[0.0, 1.0, 0.0]
            ]
            faces = [SA[1, 2, 3]]
            
            volume = polyhedron_volume(nodes, faces)
            @test volume ≈ 0.0 atol=1e-10
        end
    end
    
    @testset "Equivalent Radius" begin
        @testset "From Volume" begin
            # Sphere with radius 2
            radius = 2.0
            volume = 4π/3 * radius^3
            r_eq = equivalent_radius(volume)
            @test r_eq ≈ radius atol=1e-10
            
            # Unit volume
            r_eq = equivalent_radius(1.0)
            expected = (3/(4π))^(1/3)
            @test r_eq ≈ expected atol=1e-10
        end
        
        @testset "From ShapeModel" begin
            # Create a simple tetrahedron shape
            nodes = [
                SA[0.0, 0.0, 0.0],
                SA[1.0, 0.0, 0.0],
                SA[0.5, sqrt(3)/2, 0.0],
                SA[0.5, sqrt(3)/6, sqrt(6)/3],
            ]
            faces = [
                SA[1, 2, 3],
                SA[1, 2, 4],
                SA[2, 3, 4],
                SA[3, 1, 4],
            ]
            
            # Create shape model
            shape = ShapeModel(nodes, faces)
            
            r_eq = equivalent_radius(shape)
            vol = polyhedron_volume(shape)
            expected = (3*vol/(4π))^(1/3)
            @test r_eq ≈ expected atol=1e-10
        end
    end
    
    @testset "Maximum Radius" begin
        @testset "Simple Shapes" begin
            # Points on axes
            nodes = [
                SA[1.0, 0.0, 0.0],
                SA[0.0, 2.0, 0.0],
                SA[0.0, 0.0, 3.0]
            ]
            r_max = maximum_radius(nodes)
            @test r_max ≈ 3.0 atol=1e-10
            
            # Unit cube centered at origin
            nodes = [
                SA[-0.5, -0.5, -0.5], SA[0.5, -0.5, -0.5],
                SA[0.5, 0.5, -0.5], SA[-0.5, 0.5, -0.5],
                SA[-0.5, -0.5, 0.5], SA[0.5, -0.5, 0.5],
                SA[0.5, 0.5, 0.5], SA[-0.5, 0.5, 0.5]
            ]
            r_max = maximum_radius(nodes)
            @test r_max ≈ sqrt(3)/2 atol=1e-10
        end
        
        @testset "From ShapeModel" begin
            nodes = [
                SA[2.0, 0.0, 0.0],
                SA[0.0, 3.0, 0.0],
                SA[0.0, 0.0, 4.0]
            ]
            faces = [SA[1, 2, 3]]
            
            shape = ShapeModel(nodes, faces)
            
            r_max = maximum_radius(shape)
            @test r_max ≈ 4.0 atol=1e-10
        end
    end
    
    @testset "Minimum Radius" begin
        @testset "Simple Shapes" begin
            # Points on axes
            nodes = [
                SA[1.0, 0.0, 0.0],
                SA[0.0, 2.0, 0.0],
                SA[0.0, 0.0, 3.0]
            ]
            r_min = minimum_radius(nodes)
            @test r_min ≈ 1.0 atol=1e-10
            
            # Points at equal distance
            nodes = [
                SA[2.0, 0.0, 0.0],
                SA[0.0, 2.0, 0.0],
                SA[0.0, 0.0, 2.0]
            ]
            r_min = minimum_radius(nodes)
            @test r_min ≈ 2.0 atol=1e-10
        end
        
        @testset "From ShapeModel" begin
            nodes = [
                SA[2.0, 0.0, 0.0],
                SA[0.0, 3.0, 0.0],
                SA[0.0, 0.0, 4.0],
                SA[1.0, 1.0, 1.0]  # Closest point
            ]
            faces = [
                SA[1, 2, 3],
                SA[1, 2, 4],
                SA[2, 3, 4],
                SA[3, 1, 4]
            ]
            
            face_centers = [face_center(nodes[face]) for face in faces]
            face_normals = [face_normal(nodes[face]) for face in faces]
            face_areas = [face_area(nodes[face]) for face in faces]
            visibility_graph = nothing
            
            shape = ShapeModel(nodes, faces, face_centers, face_normals, face_areas, visibility_graph)
            
            r_min = minimum_radius(shape)
            @test r_min ≈ sqrt(3) atol=1e-10
        end
    end
    
    @testset "Grid to Faces" begin
        @testset "Simple 2x2 Grid" begin
            xs = [0.0, 1.0]
            ys = [0.0, 1.0]
            zs = [0.0 0.0; 0.0 0.0]  # Flat grid
            
            nodes, faces = grid_to_faces(xs, ys, zs)
            
            # Should have 4 nodes
            @test length(nodes) == 4
            
            # Should have 2 triangular faces
            @test length(faces) == 2
            
            # Check node positions
            @test nodes[1] ≈ SA[0.0, 0.0, 0.0]
            @test nodes[2] ≈ SA[1.0, 0.0, 0.0]
            @test nodes[3] ≈ SA[0.0, 1.0, 0.0]
            @test nodes[4] ≈ SA[1.0, 1.0, 0.0]
            
            # Check face connectivity
            @test faces[1] == SA[1, 2, 3]
            @test faces[2] == SA[4, 3, 2]
        end
        
        @testset "3x3 Grid with Elevation" begin
            xs = [0.0, 1.0, 2.0]
            ys = [0.0, 1.0, 2.0]
            zs = [i + j for i in 1:3, j in 1:3]
            
            nodes, faces = grid_to_faces(xs, ys, zs)
            
            # Should have 9 nodes
            @test length(nodes) == 9
            
            # Should have 8 triangular faces (2 per grid cell, 4 cells)
            @test length(faces) == 8
            
            # Check a few node positions
            @test nodes[1] ≈ SA[0.0, 0.0, 2.0]  # zs[1,1] = 1+1 = 2
            @test nodes[5] ≈ SA[1.0, 1.0, 4.0]  # zs[2,2] = 2+2 = 4
        end
    end
end
