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
        shape = ShapeModel(nodes, faces; with_bvh=true)
        
        # Test ray intersection with the shape
        ray = Ray(@SVector([0.25, 0.25, 1.0]), @SVector([0.0, 0.0, -1.0]))
        
        # Test intersection
        result = intersect_ray_shape(ray, shape)
        
        # Verify results
        test_ray_intersection(result, true, 1.0, @SVector([0.25, 0.25, 0.0]))
        @test result.face_index == 1  # Hit the first (and only) face
    end
    
    @testset "BVH Auto-build Test" begin
        # Test that BVH is automatically built when needed
        
        # Create shape model WITHOUT BVH
        nodes, faces = create_xy_triangle()
        shape_no_bvh = ShapeModel(nodes, faces; with_bvh=false)
        
        # Verify BVH is not built initially
        @test isnothing(shape_no_bvh.bvh)
        
        # Perform ray intersection - this should trigger BVH build
        ray = Ray(@SVector([0.25, 0.25, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result = intersect_ray_shape(ray, shape_no_bvh)
        
        # Verify BVH was built automatically
        @test !isnothing(shape_no_bvh.bvh)
        
        # Verify intersection result is correct
        test_ray_intersection(result, true, 1.0, @SVector([0.25, 0.25, 0.0]))
        @test result.face_index == 1
    end
    
    @testset "Batch Ray Intersection" begin
        # Test batch ray-shape intersection functionality
        
        # Create a simple shape model
        nodes, faces = create_xy_triangle()
        shape = ShapeModel(nodes, faces; with_bvh=true)
        
        @testset "Matrix Interface (origins/directions)" begin
            # Test with matrix interface matching ImplicitBVH.traverse_rays
            n_rays = 5
            origins = zeros(3, n_rays)
            directions = zeros(3, n_rays)
            
            # Ray 1: Hit center
            origins[:, 1] = [0.25, 0.25, 1.0]
            directions[:, 1] = [0.0, 0.0, -1.0]
            
            # Ray 2: Miss (outside triangle)
            origins[:, 2] = [2.0, 2.0, 1.0]
            directions[:, 2] = [0.0, 0.0, -1.0]
            
            # Ray 3: Hit near edge (moved slightly inside to avoid edge case)
            origins[:, 3] = [0.3, 0.1, 1.0]
            directions[:, 3] = [0.0, 0.0, -1.0]
            
            # Ray 4: Parallel (miss)
            origins[:, 4] = [0.25, 0.25, 1.0]
            directions[:, 4] = [1.0, 0.0, 0.0]
            
            # Ray 5: Hit from below
            origins[:, 5] = [0.1, 0.1, -1.0]
            directions[:, 5] = [0.0, 0.0, 1.0]
            
            # Perform batch intersection
            results = intersect_ray_shape(shape, origins, directions)
            
            # Verify results
            @test length(results) == 5
            
            # Ray 1: Center hit
            @test results[1].hit == true
            @test results[1].face_index == 1
            @test results[1].distance ≈ 1.0
            @test results[1].point ≈ SA[0.25, 0.25, 0.0]
            
            # Ray 2: Miss
            @test results[2].hit == false
            
            # Ray 3: Hit
            @test results[3].hit == true
            @test results[3].face_index == 1
            @test results[3].distance ≈ 1.0
            @test results[3].point ≈ SA[0.3, 0.1, 0.0]
            
            # Ray 4: Parallel miss
            @test results[4].hit == false
            
            # Ray 5: Hit from below
            @test results[5].hit == true
            @test results[5].face_index == 1
            @test results[5].distance ≈ 1.0
            @test results[5].point ≈ SA[0.1, 0.1, 0.0]
        end
        
        @testset "Vector of Rays" begin
            # Test with vector of Ray objects
            rays = [
                Ray(SA[0.25, 0.25, 1.0], SA[0.0, 0.0, -1.0]),  # Hit center
                Ray(SA[2.0, 2.0, 1.0],   SA[0.0, 0.0, -1.0]),  # Miss
                Ray(SA[0.1, 0.1, 1.0],   SA[0.0, 0.0, -1.0]),  # Hit
                Ray(SA[0.4, 0.2, 2.0],   SA[0.0, 0.0, -1.0]),  # Hit from farther
            ]
            
            results = intersect_ray_shape(rays, shape)
            
            @test length(results) == 4
            @test results[1].hit == true
            @test results[1].point ≈ SA[0.25, 0.25, 0.0]
            @test results[2].hit == false
            @test results[3].hit == true
            @test results[3].point ≈ SA[0.1, 0.1, 0.0]
            @test results[4].hit == true
            @test results[4].distance ≈ 2.0
        end
        
        @testset "Matrix of Rays" begin
            # Test with matrix of Ray objects (preserving shape)
            rays_mat = [
                Ray(SA[x, y, 1.0], SA[0.0, 0.0, -1.0]) 
                for x in [0.1, 0.25, 0.4], y in [0.1, 0.25]
            ]
            
            results_mat = intersect_ray_shape(rays_mat, shape)
            
            # Verify output shape matches input shape
            @test size(results_mat) == size(rays_mat)
            @test results_mat isa Matrix{RayShapeIntersectionResult}
            
            # Check specific results (all points inside triangle)
            @test results_mat[1, 1].hit == true  # (0.1, 0.1)   - inside
            @test results_mat[2, 1].hit == true  # (0.25, 0.1)  - inside
            @test results_mat[3, 1].hit == true  # (0.4, 0.1)   - inside
            @test results_mat[1, 2].hit == true  # (0.1, 0.25)  - inside
            @test results_mat[2, 2].hit == true  # (0.25, 0.25) - inside
            @test results_mat[3, 2].hit == true  # (0.4, 0.25)  - inside (0.4 + 0.25 = 0.65 < 1)
            
            # Verify all hit points have z = 0
            for result in results_mat
                if result.hit
                    @test result.point[3] ≈ 0.0
                end
            end
        end
        
        @testset "Edge Cases" begin
            # Empty rays
            empty_rays = Ray[]
            results = intersect_ray_shape(empty_rays, shape)
            @test isempty(results)
            
            # Single ray as vector
            single_ray = [Ray(SA[0.2, 0.2, 1.0], SA[0.0, 0.0, -1.0])]
            results = intersect_ray_shape(single_ray, shape)
            @test length(results) == 1
            @test results[1].hit == true
            
            # 1x1 matrix
            ray_mat_1x1 = reshape([Ray(SA[0.2, 0.2, 1.0], SA[0.0, 0.0, -1.0])], 1, 1)
            results_mat = intersect_ray_shape(ray_mat_1x1, shape)
            @test size(results_mat) == (1, 1)
            @test results_mat[1, 1].hit == true
        end
    end
end
