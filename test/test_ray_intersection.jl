#=
    test_ray_intersection.jl

Tests for ray-shape intersection algorithms.
This file verifies:
- Ray-triangle intersection using Möller-Trumbore algorithm
- Ray-bounding box intersection for acceleration
- Ray-shape model intersection finding closest hit
- Edge cases and numerical precision
- Performance characteristics
=#

@testset "Ray intersection tests" begin
    
    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                      Basic Ray Intersection                       ║
    # ╚═══════════════════════════════════════════════════════════════════╝

    @testset "Basic ray intersection" begin
        # Test a simple downward ray hitting a triangle on the XY plane
        #
        #    Ray origin (0,0,1)
        #         |
        #         v
        #     ----△---- (XY plane at z=0)
        
        ray = Ray([0.0, 0.0, 1.0], [0.0, 0.0, -1.0])
        
        # Triangle vertices on XY plane
        nodes, _ = create_xy_triangle()
        v1, v2, v3 = nodes[1], nodes[2], nodes[3]
        
        result = intersect_ray_triangle(ray, v1, v2, v3)
        test_ray_intersection(result, true, 1.0, @SVector [0.0, 0.0, 0.0])
    end
    
    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                         Simple Raycast                            ║
    # ╚═══════════════════════════════════════════════════════════════════╝

    @testset "Simple raycast" begin
        # Test the simplified raycast function
        # This function returns only hit/miss without detailed intersection info
        
        A = @SVector [0.0, 0.0, 0.0]
        B = @SVector [1.0, 0.0, 0.0]
        C = @SVector [0.0, 1.0, 0.0]
        R = @SVector [0.0, 0.0, -1.0]  # Ray direction (downward)
        O = @SVector [0.1, 0.1, 1.0]   # Ray origin above the triangle
        
        # Test with intersect_ray_triangle
        ray = Ray(O, R)
        @test intersect_ray_triangle(ray, A, B, C).hit == true
    end

    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║           Comprehensive Ray-Triangle Tests (FOVSimulator)         ║
    # ╚═══════════════════════════════════════════════════════════════════╝

    @testset "Ray-Triangle Intersection (FOVSimulator ported tests)" begin
        # Define a standard test triangle on the XY plane
        # 
        #      v3 (0,1,0)
        #       |\
        #       | \
        #       |  \
        #       |   \
        #       |____\
        #      v1     v2
        #   (0,0,0)  (1,0,0)
        
        nodes, _ = create_xy_triangle()  # Standard triangle on XY plane
        v1, v2, v3 = nodes[1], nodes[2], nodes[3]
        
        # Test Case 1: Direct Hit
        # Ray from (0.25, 0.25, 1) pointing down should hit the triangle
        ray1 = Ray(@SVector([0.25, 0.25, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result1 = intersect_ray_triangle(ray1, v1, v2, v3)
        
        test_ray_intersection(result1, true, 1.0, @SVector([0.25, 0.25, 0.0]))
        
        # Test Case 2: Complete Miss
        # Ray from (2, 2, 1) is outside the triangle bounds
        ray2 = Ray(@SVector([2.0, 2.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result2 = intersect_ray_triangle(ray2, v1, v2, v3)
        
        @test result2.hit == false
        
        # Test Case 3: Parallel Ray
        # Ray parallel to the triangle plane should not intersect
        ray3 = Ray(@SVector([0.5, 0.5, 1.0]), @SVector([1.0, 0.0, 0.0]))
        result3 = intersect_ray_triangle(ray3, v1, v2, v3)
        
        @test result3.hit == false
        
        # Test Case 4: Vertex Hit
        # Ray passing exactly through vertex v1 at origin
        ray4 = Ray(@SVector([0.0, 0.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result4 = intersect_ray_triangle(ray4, v1, v2, v3)
        
        test_ray_intersection(result4, true, 1.0, @SVector([0.0, 0.0, 0.0]))
        
        # Test Case 5: Edge Hit
        # Ray passing through the edge between v1 and v2
        ray5 = Ray(@SVector([0.5, 0.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result5 = intersect_ray_triangle(ray5, v1, v2, v3)
        
        test_ray_intersection(result5, true, 1.0, @SVector([0.5, 0.0, 0.0]))
        
        # Test Case 6: Backside Hit
        # Ray from below the triangle pointing upward
        ray6 = Ray(@SVector([0.25, 0.25, -1.0]), @SVector([0.0, 0.0, 1.0]))
        result6 = intersect_ray_triangle(ray6, v1, v2, v3)
        
        test_ray_intersection(result6, true, 1.0, @SVector([0.25, 0.25, 0.0]))  # No backface culling
        
        # Test Case 7: Ray Origin on Triangle
        # Ray starting exactly on the triangle surface
        ray7 = Ray(@SVector([0.25, 0.25, 0.0]), @SVector([0.0, 0.0, -1.0]))
        result7 = intersect_ray_triangle(ray7, v1, v2, v3)
        
        @test result7.hit == false  # Numerical precision prevents self-intersection
        
        # Test Case 8: Ray Pointing Away
        # Ray behind triangle pointing away from it
        ray8 = Ray(@SVector([0.25, 0.25, -1.0]), @SVector([0.0, 0.0, -1.0]))
        result8 = intersect_ray_triangle(ray8, v1, v2, v3)
        
        @test result8.hit == false  # Ray moves away from triangle
    end

    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                   Ray-Shape Intersection Tests                    ║
    # ╚═══════════════════════════════════════════════════════════════════╝
    
    @testset "Ray-Shape Intersection (FOVSimulator ported tests)" begin
        # Create a minimal shape model with a single triangle
        
        # Triangle vertices
        nodes, faces = create_xy_triangle()  # Standard triangle on XY plane
        v1, v2, v3 = nodes[1], nodes[2], nodes[3]
        
        # Create shape model
        shape = ShapeModel(nodes, faces)
        
        # Test ray intersection with the shape
        ray = Ray(@SVector([0.25, 0.25, 1.0]), @SVector([0.0, 0.0, -1.0]))
        
        # Compute bounding box for acceleration
        bbox = compute_bounding_box(shape)
        
        # Test intersection
        result = intersect_ray_shape(ray, shape, bbox)
        
        # Verify results
        test_ray_intersection(result, true, 1.0, @SVector([0.25, 0.25, 0.0]))
        @test result.face_index == 1  # Hit the first (and only) face
    end
end
