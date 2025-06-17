using Test
using AsteroidShapeModels
using StaticArrays

@testset "FaceVisibilityGraph" begin
    
    @testset "Basic Construction" begin
        # Empty graph
        graph = FaceVisibilityGraph()
        @test graph.nfaces == 0
        @test graph.nnz == 0
        
        # Empty graph with specified size
        graph = FaceVisibilityGraph(5)
        @test graph.nfaces == 5
        @test graph.nnz == 0
    end
    
    @testset "Direct CSR Construction" begin
        # Simple test case: construct graph directly in CSR format
        row_ptr = [1, 3, 4, 5]
        col_idx = [2, 3, 1, 1]
        view_factors = [0.1, 0.2, 0.1, 0.2]
        distances = [1.0, 2.0, 1.0, 2.0]
        directions = [SA[1.0, 0.0, 0.0], SA[0.0, 1.0, 0.0], SA[-1.0, 0.0, 0.0], SA[0.0, -1.0, 0.0]]
        
        # Construct FaceVisibilityGraph directly
        graph = FaceVisibilityGraph(row_ptr, col_idx, view_factors, distances, directions)
        
        @test graph.nfaces == 3
        @test graph.nnz == 4
        @test graph.row_ptr == [1, 3, 4, 5]
        @test graph.col_idx == [2, 3, 1, 1]
        @test graph.view_factors ≈ [0.1, 0.2, 0.1, 0.2]
        @test graph.distances ≈ [1.0, 2.0, 1.0, 2.0]
    end
    
    @testset "Data Access Methods" begin
        # Manually construct CSR format data for testing
        row_ptr = [1, 3, 5, 5]  # Face 1: 2 visible, Face 2: 2 visible, Face 3: 0 visible
        col_idx = [2, 3, 1, 3]
        view_factors = [0.1, 0.2, 0.3, 0.4]
        distances = [1.0, 2.0, 1.5, 2.5]
        directions = [SA[1.0, 0.0, 0.0], SA[0.0, 1.0, 0.0], SA[-1.0, 0.0, 0.0], SA[0.0, 0.0, 1.0]]
        
        graph = FaceVisibilityGraph(row_ptr, col_idx, view_factors, distances, directions)
        
        # get_visible_faces
        @test collect(get_visible_faces(graph, 1)) == [2, 3]
        @test collect(get_visible_faces(graph, 2)) == [1, 3]
        @test collect(get_visible_faces(graph, 3)) == []
        
        # get_view_factors
        @test collect(get_view_factors(graph, 1)) ≈ [0.1, 0.2]
        @test collect(get_view_factors(graph, 2)) ≈ [0.3, 0.4]
        @test collect(get_view_factors(graph, 3)) == []
        
        # get_distances
        @test collect(get_distances(graph, 1)) ≈ [1.0, 2.0]
        @test collect(get_distances(graph, 2)) ≈ [1.5, 2.5]
        
        # get_directions
        @test collect(get_directions(graph, 1))[1] ≈ SA[1.0, 0.0, 0.0]
        @test collect(get_directions(graph, 1))[2] ≈ SA[0.0, 1.0, 0.0]
        
        # num_visible_faces
        @test num_visible_faces(graph, 1) == 2
        @test num_visible_faces(graph, 2) == 2
        @test num_visible_faces(graph, 3) == 0
        
        # get_visible_facet_data
        data = get_visible_facet_data(graph, 1, 1)
        @test data.id == 2
        @test data.f ≈ 0.1
        @test data.d ≈ 1.0
        @test data.d̂ ≈ SA[1.0, 0.0, 0.0]
    end
    
    @testset "Memory Usage" begin
        # Check memory usage with a larger graph
        n = 100
        nnz = n * 10  # Each face has 10 visible faces on average
        
        # Build CSR format data
        row_ptr = Vector{Int}(undef, n + 1)
        col_idx = Vector{Int}(undef, nnz)
        view_factors = fill(0.1, nnz)
        distances = fill(1.0, nnz)
        directions = fill(SA[0.0, 0.0, 1.0], nnz)
        
        # Build row_ptr and col_idx
        row_ptr[1] = 1
        idx = 1
        for i in 1:n
            row_ptr[i + 1] = row_ptr[i] + 10
            for j in 1:10
                col_idx[idx] = mod1(i + j, n)
                idx += 1
            end
        end
        
        graph = FaceVisibilityGraph(row_ptr, col_idx, view_factors, distances, directions)
        
        @test graph.nfaces == n
        @test graph.nnz == n * 10
        
        # Calculate memory usage
        mem_usage = Base.summarysize(graph)
        expected_min = sizeof(Int) * (n + 1 + n * 10) + sizeof(Float64) * (n * 10 * 2) + sizeof(SVector{3, Float64}) * n * 10
        @test mem_usage >= expected_min
    end
    
    @testset "Bounds Checking" begin
        graph = FaceVisibilityGraph(3)
        
        # Test out-of-bounds access
        @test_throws BoundsError get_visible_faces(graph, 0)
        @test_throws BoundsError get_visible_faces(graph, 4)
        @test_throws BoundsError get_view_factors(graph, 0)
        @test_throws BoundsError num_visible_faces(graph, 4)
    end
end

@testset "ShapeModel with FaceVisibilityGraph" begin
    # Simple tetrahedron test
    nodes = [
        SA[0.0, 0.0, 0.0],
        SA[1.0, 0.0, 0.0],
        SA[0.0, 1.0, 0.0],
        SA[0.0, 0.0, 1.0],
    ]
    faces = [
        SA[1, 3, 2],
        SA[1, 2, 4],
        SA[1, 4, 3],
        SA[2, 3, 4],
    ]
    
    @testset "FaceVisibilityGraph Implementation" begin
        # Create shape with visibility computation
        shape = ShapeModel(nodes, faces)
        build_face_visibility_graph!(shape)
        
        # Verify that visibility_graph is created
        @test !isnothing(shape.visibility_graph)
        @test shape.visibility_graph.nfaces == length(faces)
        
        # For a tetrahedron, no face should see any other face (convex shape)
        @test shape.visibility_graph.nnz == 0
        
        # Verify that all faces have no visible faces
        for i in 1:length(faces)
            visible_faces = get_visible_faces(shape.visibility_graph, i)
            @test length(visible_faces) == 0
            @test num_visible_faces(shape.visibility_graph, i) == 0
        end
    end
    
    @testset "isilluminated with FaceVisibilityGraph" begin
        shape = ShapeModel(nodes, faces)
        build_face_visibility_graph!(shape)
        
        # Sun position
        r_sun = SA[1.0, 1.0, 1.0]
        
        # Verify illumination for each face
        for i in 1:length(faces)
            illuminated = isilluminated(shape, r_sun, i)
            
            # Check if face normal points toward the sun
            face_normal = shape.face_normals[i]
            r_sun_normalized = normalize(r_sun)
            cos_angle = dot(face_normal, r_sun_normalized)
            
            # Face should be illuminated if it faces the sun
            expected_illuminated = cos_angle > 0
            @test illuminated == expected_illuminated
        end
    end
end

@testset "Performance and Memory Comparison" begin
    # Larger test case (cube)
    function create_cube()
        # Create unit cube
        cube_nodes = [
            SA[-1.0, -1.0, -1.0], SA[1.0, -1.0, -1.0],
            SA[1.0, 1.0, -1.0], SA[-1.0, 1.0, -1.0],
            SA[-1.0, -1.0, 1.0], SA[1.0, -1.0, 1.0],
            SA[1.0, 1.0, 1.0], SA[-1.0, 1.0, 1.0]
        ]
        
        cube_faces = [
            SA[1, 3, 2], SA[1, 4, 3],  # bottom (-z face, outward normal)
            SA[5, 6, 7], SA[5, 7, 8],  # top    (+z face, outward normal)
            SA[1, 2, 6], SA[1, 6, 5],  # front  (-y face, outward normal)
            SA[3, 4, 8], SA[3, 8, 7],  # back   (+y face, outward normal)
            SA[1, 5, 8], SA[1, 8, 4],  # left   (-x face, outward normal)
            SA[2, 3, 7], SA[2, 7, 6],  # right  (+x face, outward normal)
        ]
        
        return cube_nodes, cube_faces
    end
    
    nodes, faces = create_cube()
    
    # Create shape with visibility computation
    shape = ShapeModel(nodes, faces)
    build_face_visibility_graph!(shape)
    
    # Verify that FaceVisibilityGraph is created
    @test !isnothing(shape.visibility_graph)
    
    # Display memory usage
    graph_memory = Base.summarysize(shape.visibility_graph)
    println("Memory usage for cube:")
    println("  FaceVisibilityGraph: $(graph_memory) bytes")
    println("  Number of faces: $(shape.visibility_graph.nfaces)")
    println("  Number of visible pairs: $(shape.visibility_graph.nnz)")
    
    # For a cube, no external face should see any other external face
    @test shape.visibility_graph.nnz == 0
end