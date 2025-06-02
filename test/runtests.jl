using Test
using AsteroidShapeModels
using StaticArrays
using LinearAlgebra
using SPICE
using Downloads

@testset "AsteroidShapeModels.jl" begin
    @testset "Face properties" begin
        v1 = @SVector [0.0, 0.0, 0.0]
        v2 = @SVector [1.0, 0.0, 0.0]
        v3 = @SVector [0.0, 1.0, 0.0]
        
        center = face_center(v1, v2, v3)
        @test center ≈ @SVector [1/3, 1/3, 0.0]
        
        normal = face_normal(v1, v2, v3)
        @test normal ≈ @SVector [0.0, 0.0, 1.0]
        
        area = face_area(v1, v2, v3)
        @test area ≈ 0.5
    end
    
    @testset "Ray intersection" begin
        ray = Ray([0.0, 0.0, 1.0], [0.0, 0.0, -1.0])
        
        v1 = @SVector [0.0, 0.0, 0.0]
        v2 = @SVector [1.0, 0.0, 0.0]
        v3 = @SVector [0.0, 1.0, 0.0]
        
        result = intersect_ray_triangle(ray, v1, v2, v3)
        @test result.hit == true
        @test result.distance ≈ 1.0
        @test result.point ≈ @SVector [0.0, 0.0, 0.0]
    end
    
    @testset "Simple raycast" begin
        A = @SVector [0.0, 0.0, 0.0]
        B = @SVector [1.0, 0.0, 0.0]
        C = @SVector [0.0, 1.0, 0.0]
        R = @SVector [0.0, 0.0, -1.0]
        O = @SVector [0.1, 0.1, 1.0]  # Downward ray from a point above the triangle
        
        @test raycast(A, B, C, R, O) == true
    end

    @testset "Ray-Triangle Intersection (FOVSimulator ported tests)" begin
        # Single triangle definition
        # This triangle is on the xy plane
        v1 = @SVector [0.0, 0.0, 0.0]  # Origin
        v2 = @SVector [1.0, 0.0, 0.0]  # Point on x-axis
        v3 = @SVector [0.0, 1.0, 0.0]  # Point on y-axis
        
        # Test case 1: Ray that intersects the triangle
        ray1 = Ray(@SVector([0.25, 0.25, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result1 = intersect_ray_triangle(ray1, v1, v2, v3)
        
        @test result1.hit == true
        @test result1.distance ≈ 1.0
        @test result1.point ≈ @SVector([0.25, 0.25, 0.0])
        
        # Test case 2: Ray that doesn't intersect the triangle (passes outside)
        ray2 = Ray(@SVector([2.0, 2.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result2 = intersect_ray_triangle(ray2, v1, v2, v3)
        
        @test result2.hit == false
        
        # Test case 3: Ray that doesn't intersect the triangle (parallel to triangle)
        ray3 = Ray(@SVector([0.5, 0.5, 1.0]), @SVector([1.0, 0.0, 0.0]))
        result3 = intersect_ray_triangle(ray3, v1, v2, v3)
        
        @test result3.hit == false
        
        # Test case 4: Ray that passes through a vertex
        ray4 = Ray(@SVector([0.0, 0.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result4 = intersect_ray_triangle(ray4, v1, v2, v3)
        
        @test result4.hit == true
        @test result4.distance ≈ 1.0
        @test result4.point ≈ @SVector([0.0, 0.0, 0.0])
        
        # Test case 5: Ray that passes through an edge
        ray5 = Ray(@SVector([0.5, 0.0, 1.0]), @SVector([0.0, 0.0, -1.0]))
        result5 = intersect_ray_triangle(ray5, v1, v2, v3)
        
        @test result5.hit == true
        @test result5.distance ≈ 1.0
        @test result5.point ≈ @SVector([0.5, 0.0, 0.0])
        
        # Test case 6: Ray from the back side of the triangle (backface culling)
        ray6 = Ray(@SVector([0.25, 0.25, -1.0]), @SVector([0.0, 0.0, 1.0]))
        result6 = intersect_ray_triangle(ray6, v1, v2, v3)
        
        @test result6.hit == true  # No backface culling in basic ray-triangle test
        @test result6.distance ≈ 1.0
        @test result6.point ≈ @SVector([0.25, 0.25, 0.0])
        
        # Test case 7: Ray origin on the triangle
        ray7 = Ray(@SVector([0.25, 0.25, 0.0]), @SVector([0.0, 0.0, -1.0]))
        result7 = intersect_ray_triangle(ray7, v1, v2, v3)
        
        @test result7.hit == false  # Due to numerical precision, no intersection when origin is on triangle
        
        # Test case 8: Ray origin behind triangle pointing away
        ray8 = Ray(@SVector([0.25, 0.25, -1.0]), @SVector([0.0, 0.0, -1.0]))
        result8 = intersect_ray_triangle(ray8, v1, v2, v3)
        
        @test result8.hit == false  # No intersection when ray moves away from triangle
    end

    @testset "Ray-Shape Intersection (FOVSimulator ported tests)" begin
        # Single triangle definition
        # This triangle is on the xy plane
        v1 = @SVector [0.0, 0.0, 0.0]  # Origin
        v2 = @SVector [1.0, 0.0, 0.0]  # Point on x-axis
        v3 = @SVector [0.0, 1.0, 0.0]  # Point on y-axis

        nodes = [v1, v2, v3]
        faces = [@SVector([1, 2, 3])]  # Vertex indices start from 1
        
        face_centers  = [face_center(nodes[face]) for face in faces]
        face_normals  = [face_normal(nodes[face]) for face in faces]
        face_areas    = [face_area(nodes[face])   for face in faces]
        visiblefacets = [VisibleFacet[] for _ in faces]

        shape = ShapeModel(nodes, faces, face_centers, face_normals, face_areas, visiblefacets)
        
        # Define ray
        ray = Ray(@SVector([0.25, 0.25, 1.0]), @SVector([0.0, 0.0, -1.0]))
        
        # Compute bounding box
        bbox = compute_bounding_box(shape)
        
        # Intersection test
        result = intersect_ray_shape(ray, shape, bbox)
        
        # Tests
        @test result.hit == true
        @test result.distance ≈ 1.0
        @test result.point ≈ @SVector([0.25, 0.25, 0.0])
        @test result.face_index == 1
    end

    @testset "Geometry Utility Functions (FOVSimulator ported tests)" begin
        # Test angle functions
        @test angle_deg([1, 0, 0], [ 0, 1, 0]) ≈ 90
        @test angle_deg([1, 0, 0], [ 1, 0, 0]) ≈ 0
        @test angle_deg([1, 0, 0], [-1, 0, 0]) ≈ 180

        @test angle_rad([1, 0, 0], [ 0, 1, 0]) ≈ π/2
        @test angle_rad([1, 0, 0], [ 1, 0, 0]) ≈ 0
        @test angle_rad([1, 0, 0], [-1, 0, 0]) ≈ π

        # Test solar geometry functions
        sun = [1, 0, 0]
        tgt = [0, 0, 0]
        obs = [0, 1, 0]

        @test solar_phase_angle(sun, tgt, obs) ≈ deg2rad(90)
        @test solar_elongation_angle(sun, obs, tgt) ≈ deg2rad(45)

        # Test edge cases
        @test angle_deg([1, 1, 0], [1, 1, 0]) ≈ 0 atol=1e-5  # Same vector
        @test angle_deg([1, 0, 0], [0, 0, 1]) ≈ 90           # Perpendicular vectors
        
        # Test with different vector magnitudes
        @test angle_deg([2, 0, 0], [0, 3, 0]) ≈ 90           # Perpendicular vectors
        @test angle_deg([5, 0, 0], [5, 0, 0]) ≈ 0 atol=1e-5  # Same vector
    end

    # Ray intersection validation using real asteroid shape models and SPICE
    include("ray_intersection_vs_spice.jl")
end