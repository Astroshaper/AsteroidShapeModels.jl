# ====================================================================
#                    Ray Intersection Tests
# ====================================================================
# This file tests the ray-triangle and ray-shape intersection algorithms
# used for visibility calculations and surface analysis.

@testset "Ray intersection tests" begin
    
    # ----------------------------------------------------------------
    #                   Basic Ray Intersection
    # ----------------------------------------------------------------

    @testset "Basic ray intersection" begin
        # Test a simple downward ray hitting a triangle on the XY plane
        #
        #    Ray origin (0,0,1)
        #         |
        #         v
        #     ----△---- (XY plane at z=0)
        
        ray = Ray([0.0, 0.0, 1.0], [0.0, 0.0, -1.0])
        
        # Triangle vertices on XY plane
        v1 = @SVector [0.0, 0.0, 0.0]
        v2 = @SVector [1.0, 0.0, 0.0]
        v3 = @SVector [0.0, 1.0, 0.0]
        
        result = intersect_ray_triangle(ray, v1, v2, v3)
        @test result.hit == true
        @test result.distance ≈ 1.0
        @test result.point ≈ @SVector [0.0, 0.0, 0.0]
    end
    
    # ----------------------------------------------------------------
    #                      Simple Raycast
    # ----------------------------------------------------------------

    @testset "Simple raycast" begin
        # Test the simplified raycast function
        # This function returns only hit/miss without detailed intersection info
        
        A = @SVector [0.0, 0.0, 0.0]
        B = @SVector [1.0, 0.0, 0.0]
        C = @SVector [0.0, 1.0, 0.0]
        R = @SVector [0.0, 0.0, -1.0]  # Ray direction (downward)
        O = @SVector [0.1, 0.1, 1.0]   # Ray origin above the triangle
        
        @test raycast(A, B, C, R, O) == true
    end

    # ----------------------------------------------------------------
    #        Comprehensive Ray-Triangle Tests (FOVSimulator)
    # ----------------------------------------------------------------

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
        
        v1 = @SVector [0.0, 0.0, 0.0]  # Origin
        v2 = @SVector [1.0, 0.0, 0.0]  # Point on x-axis
        v3 = @SVector [0.0, 1.0, 0.0]  # Point on y-axis
        
        # ====== Test Case 1: Direct Hit ======
        # Ray from (0.25, 0.25, 1) pointing down should hit the triangle
        ray1 = Ray(@SVector([0.25, 0.25, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result1 = intersect_ray_triangle(ray1, v1, v2, v3)
        
        @test result1.hit == true
        @test result1.distance ≈ 1.0
        @test result1.point ≈ @SVector([0.25, 0.25, 0.0])
        
        # ====== Test Case 2: Complete Miss ======
        # Ray from (2, 2, 1) is outside the triangle bounds
        ray2 = Ray(@SVector([2.0, 2.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result2 = intersect_ray_triangle(ray2, v1, v2, v3)
        
        @test result2.hit == false
        
        # ====== Test Case 3: Parallel Ray ======
        # Ray parallel to the triangle plane should not intersect
        ray3 = Ray(@SVector([0.5, 0.5, 1.0]), @SVector([1.0, 0.0, 0.0]))
        result3 = intersect_ray_triangle(ray3, v1, v2, v3)
        
        @test result3.hit == false
        
        # ====== Test Case 4: Vertex Hit ======
        # Ray passing exactly through vertex v1 at origin
        ray4 = Ray(@SVector([0.0, 0.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result4 = intersect_ray_triangle(ray4, v1, v2, v3)
        
        @test result4.hit == true
        @test result4.distance ≈ 1.0
        @test result4.point ≈ @SVector([0.0, 0.0, 0.0])
        
        # ====== Test Case 5: Edge Hit ======
        # Ray passing through the edge between v1 and v2
        ray5 = Ray(@SVector([0.5, 0.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result5 = intersect_ray_triangle(ray5, v1, v2, v3)
        
        @test result5.hit == true
        @test result5.distance ≈ 1.0
        @test result5.point ≈ @SVector([0.5, 0.0, 0.0])
        
        # ====== Test Case 6: Backside Hit ======
        # Ray from below the triangle pointing upward
        ray6 = Ray(@SVector([0.25, 0.25, -1.0]), @SVector([0.0, 0.0, 1.0]))
        result6 = intersect_ray_triangle(ray6, v1, v2, v3)
        
        @test result6.hit == true  # No backface culling
        @test result6.distance ≈ 1.0
        @test result6.point ≈ @SVector([0.25, 0.25, 0.0])
        
        # ====== Test Case 7: Ray Origin on Triangle ======
        # Ray starting exactly on the triangle surface
        ray7 = Ray(@SVector([0.25, 0.25, 0.0]), @SVector([0.0, 0.0, -1.0]))
        result7 = intersect_ray_triangle(ray7, v1, v2, v3)
        
        @test result7.hit == false  # Numerical precision prevents self-intersection
        
        # ====== Test Case 8: Ray Pointing Away ======
        # Ray behind triangle pointing away from it
        ray8 = Ray(@SVector([0.25, 0.25, -1.0]), @SVector([0.0, 0.0, -1.0]))
        result8 = intersect_ray_triangle(ray8, v1, v2, v3)
        
        @test result8.hit == false  # Ray moves away from triangle
    end

    # ----------------------------------------------------------------
    #              Ray-Shape Intersection Tests
    # ----------------------------------------------------------------
    
    @testset "Ray-Shape Intersection (FOVSimulator ported tests)" begin
        # Create a minimal shape model with a single triangle
        
        # Triangle vertices
        v1 = @SVector [0.0, 0.0, 0.0]  # Origin
        v2 = @SVector [1.0, 0.0, 0.0]  # Point on x-axis
        v3 = @SVector [0.0, 1.0, 0.0]  # Point on y-axis

        # Build shape model
        nodes = [v1, v2, v3]
        faces = [@SVector([1, 2, 3])]  # Single face with vertex indices
        
        # Create shape model
        shape = ShapeModel(nodes, faces)
        
        # Test ray intersection with the shape
        ray = Ray(@SVector([0.25, 0.25, 1.0]), @SVector([0.0, 0.0, -1.0]))
        
        # Compute bounding box for acceleration
        bbox = compute_bounding_box(shape)
        
        # Test intersection
        result = intersect_ray_shape(ray, shape, bbox)
        
        # Verify results
        @test result.hit == true
        @test result.distance ≈ 1.0
        @test result.point ≈ @SVector([0.25, 0.25, 0.0])
        @test result.face_index == 1  # Hit the first (and only) face
    end
end
