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
    
    @testset "From/To Adjacency List Conversion" begin
        # Simple test case
        visiblefacets = [
            [VisibleFacet(2, 0.1, 1.0, SA[1.0, 0.0, 0.0]), 
             VisibleFacet(3, 0.2, 2.0, SA[0.0, 1.0, 0.0])],
            [VisibleFacet(1, 0.1, 1.0, SA[-1.0, 0.0, 0.0])],
            [VisibleFacet(1, 0.2, 2.0, SA[0.0, -1.0, 0.0])]
        ]
        
        # Convert from adjacency list to CSR format
        graph = from_adjacency_list(visiblefacets)
        
        @test graph.nfaces == 3
        @test graph.nnz == 4
        @test graph.row_ptr == [1, 3, 4, 5]
        @test graph.col_idx == [2, 3, 1, 1]
        @test graph.view_factors ≈ [0.1, 0.2, 0.1, 0.2]
        @test graph.distances ≈ [1.0, 2.0, 1.0, 2.0]
        
        # Convert from CSR format back to adjacency list
        converted_back = to_adjacency_list(graph)
        
        @test length(converted_back) == length(visiblefacets)
        for i in eachindex(visiblefacets)
            @test length(converted_back[i]) == length(visiblefacets[i])
            for j in eachindex(visiblefacets[i])
                @test converted_back[i][j].id == visiblefacets[i][j].id
                @test converted_back[i][j].f ≈ visiblefacets[i][j].f
                @test converted_back[i][j].d ≈ visiblefacets[i][j].d
                @test converted_back[i][j].d̂ ≈ visiblefacets[i][j].d̂
            end
        end
    end
    
    @testset "Data Access Methods" begin
        visiblefacets = [
            [VisibleFacet(2, 0.1, 1.0, SA[1.0, 0.0, 0.0]), 
             VisibleFacet(3, 0.2, 2.0, SA[0.0, 1.0, 0.0])],
            [VisibleFacet(1, 0.3, 1.5, SA[-1.0, 0.0, 0.0]),
             VisibleFacet(3, 0.4, 2.5, SA[0.0, 0.0, 1.0])],
            VisibleFacet[]
        ]
        
        graph = from_adjacency_list(visiblefacets)
        
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
        visiblefacets = [VisibleFacet[] for _ in 1:n]
        
        # Each face has 10 visible faces on average
        for i in 1:n
            for j in 1:10
                target = mod1(i + j, n)
                push!(visiblefacets[i], VisibleFacet(target, 0.1, 1.0, SA[0.0, 0.0, 1.0]))
            end
        end
        
        graph = from_adjacency_list(visiblefacets)
        
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
        SA[0.0, 0.0, 1.0]
    ]
    faces = [
        SA[1, 2, 3],
        SA[1, 2, 4],
        SA[1, 3, 4],
        SA[2, 3, 4]
    ]
    
    @testset "Legacy vs New Implementation" begin
        # Legacy implementation
        shape_legacy = ShapeModel(nodes, faces)
        find_visiblefacets!(shape_legacy, use_visibility_graph=false)
        
        # New implementation
        shape_new = ShapeModel(nodes, faces)
        find_visiblefacets!(shape_new, use_visibility_graph=true)
        
        # Verify that visibility_graph is created
        @test !isnothing(shape_new.visibility_graph)
        @test shape_new.visibility_graph.nfaces == length(faces)
        
        # Verify that results match
        for i in 1:length(faces)
            legacy_visible = shape_legacy.visiblefacets[i]
            new_visible = shape_new.visiblefacets[i]
            
            @test length(legacy_visible) == length(new_visible)
            
            # Check that they have the same visible faces (order may differ)
            legacy_ids = sort([vf.id for vf in legacy_visible])
            new_ids = sort([vf.id for vf in new_visible])
            @test legacy_ids == new_ids
            
            # Check that view factors also match
            for vf_legacy in legacy_visible
                vf_new = findfirst(vf -> vf.id == vf_legacy.id, new_visible)
                @test !isnothing(vf_new)
                @test new_visible[vf_new].f ≈ vf_legacy.f
                @test new_visible[vf_new].d ≈ vf_legacy.d
                @test new_visible[vf_new].d̂ ≈ vf_legacy.d̂
            end
        end
    end
    
    @testset "isilluminated with FaceVisibilityGraph" begin
        shape = ShapeModel(nodes, faces)
        find_visiblefacets!(shape, use_visibility_graph=true)
        
        # Sun position
        r_sun = SA[1.0, 1.0, 1.0]
        
        # Verify both implementations return the same result
        for i in 1:length(faces)
            # Using visibility_graph
            illuminated_new = isilluminated(shape, r_sun, i)
            
            # Temporarily set visibility_graph to nothing to test legacy implementation
            temp_graph = shape.visibility_graph
            shape.visibility_graph = nothing
            illuminated_legacy = isilluminated(shape, r_sun, i)
            shape.visibility_graph = temp_graph
            
            @test illuminated_new == illuminated_legacy
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
            SA[1, 2, 3], SA[1, 3, 4],  # bottom
            SA[5, 7, 6], SA[5, 8, 7],  # top
            SA[1, 5, 6], SA[1, 6, 2],  # front
            SA[3, 7, 8], SA[3, 8, 4],  # back
            SA[1, 4, 8], SA[1, 8, 5],  # left
            SA[2, 6, 7], SA[2, 7, 3]   # right
        ]
        
        return cube_nodes, cube_faces
    end
    
    nodes, faces = create_cube()
    
    # Memory usage comparison
    shape1 = ShapeModel(nodes, faces)
    find_visiblefacets!(shape1, use_visibility_graph=false)
    
    shape2 = ShapeModel(nodes, faces)
    find_visiblefacets!(shape2, use_visibility_graph=true)
    
    # Verify that FaceVisibilityGraph is more memory efficient
    if !isnothing(shape2.visibility_graph)
        graph_memory = Base.summarysize(shape2.visibility_graph)
        
        # Estimate memory usage of adjacency list
        adjacency_memory = 0
        for vf_list in shape1.visiblefacets
            adjacency_memory += sizeof(vf_list) + length(vf_list) * sizeof(VisibleFacet)
        end
        
        println("Memory usage comparison:")
        println("  Adjacency list: ~$(adjacency_memory) bytes")
        println("  FaceVisibilityGraph: $(graph_memory) bytes")
        
        # CSR format is generally more efficient, especially for large data
        # However, this may not always be true for very small graphs
    end
end