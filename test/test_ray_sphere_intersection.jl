#=
    test_ray_sphere_intersection.jl

Unit tests for ray-sphere intersection functionality.
Tests the intersect_ray_sphere function with various scenarios including
edge cases and degenerate cases.
=#

@testset "Ray-Sphere Intersection" begin
    # Test 1: Ray hits sphere (basic case)
    @testset "Basic intersection" begin
        ray_origin    = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(1.0, 0.0, 0.0)
        sphere_center = SVector(5.0, 0.0, 0.0)
        sphere_radius = 2.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == true
        @test result.distance1 ≈ 3.0
        @test result.distance2 ≈ 7.0
        @test result.point1 ≈ SVector(3.0, 0.0, 0.0)
        @test result.point2 ≈ SVector(7.0, 0.0, 0.0)
    end
    
    # Test 2: Ray misses sphere
    @testset "No intersection" begin
        ray_origin    = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(1.0, 0.0, 0.0)
        sphere_center = SVector(5.0, 5.0, 0.0)
        sphere_radius = 2.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == false
        @test isnan(result.distance1)
        @test isnan(result.distance2)
        @test all(isnan.(result.point1))
        @test all(isnan.(result.point2))
    end
    
    # Test 3: Ray origin inside sphere
    @testset "Ray origin inside sphere" begin
        ray_origin    = SVector(5.0, 0.0, 0.0)  # Inside the sphere
        ray_direction = SVector(1.0, 0.0, 0.0)
        sphere_center = SVector(5.0, 0.0, 0.0)
        sphere_radius = 2.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == true
        @test result.distance1 < 0  # Behind the ray origin
        @test result.distance2 > 0  # In front of the ray origin
        @test result.distance2 ≈ 2.0
    end
    
    # Test 4: Ray tangent to sphere
    @testset "Tangent ray" begin
        ray_origin    = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(1.0, 0.0, 0.0)
        sphere_center = SVector(5.0, 2.0, 0.0)  # Sphere touching the ray
        sphere_radius = 2.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == true
        @test result.distance1 ≈ result.distance2  # Single touch point
        @test result.distance1 ≈ 5.0
        @test result.point1 ≈ result.point2
    end
    
    # Test 5: Sphere behind ray
    @testset "Sphere behind ray" begin
        ray_origin    = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(1.0, 0.0, 0.0)
        sphere_center = SVector(-5.0, 0.0, 0.0)  # Behind the ray
        sphere_radius = 2.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == false
        @test isnan(result.distance1)
        @test isnan(result.distance2)
    end
    
    # Test 6: Zero radius sphere
    @testset "Zero radius sphere" begin
        ray_origin    = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(1.0, 0.0, 0.0)
        sphere_center = SVector(5.0, 0.0, 0.0)
        sphere_radius = 0.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == false
    end
    
    # Test 7: Zero direction vector
    @testset "Zero direction vector" begin
        ray_origin    = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(0.0, 0.0, 0.0)  # Invalid direction
        sphere_center = SVector(5.0, 0.0, 0.0)
        sphere_radius = 2.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == false
    end
    
    # Test 8: Ray and Sphere objects
    @testset "Ray and Sphere objects" begin
        ray = Ray([0.0, 0.0, 0.0], [1.0, 0.0, 0.0])
        sphere = Sphere([5.0, 0.0, 0.0], 2.0)
        
        result = intersect_ray_sphere(ray, sphere)
        
        @test result.hit == true
        @test result.distance1 ≈ 3.0
        @test result.distance2 ≈ 7.0
    end
    
    # Test 9: Non-normalized ray direction
    @testset "Non-normalized ray direction" begin
        ray_origin = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(2.0, 0.0, 0.0)  # Not normalized
        sphere_center = SVector(5.0, 0.0, 0.0)
        sphere_radius = 2.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == true
        @test result.distance1 ≈ 3.0  # Should still work correctly
        @test result.distance2 ≈ 7.0
    end
    
    # Test 10: Large sphere enclosing ray origin
    @testset "Large sphere enclosing origin" begin
        ray_origin    = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(1.0, 0.0, 0.0)
        sphere_center = SVector(0.0, 0.0, 0.0)
        sphere_radius = 10.0
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        @test result.hit == true
        @test result.distance1 < 0  # Behind origin
        @test result.distance2 > 0  # In front
        @test result.distance2 ≈ 10.0
    end
    
    # Test 11: Numerical precision test
    @testset "Numerical precision" begin
        # Very small sphere
        ray_origin    = SVector(0.0, 0.0, 0.0)
        ray_direction = SVector(1.0, 0.0, 0.0)
        sphere_center = SVector(1e-10, 0.0, 0.0)
        sphere_radius = 1e-12
        
        result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
        
        # Should handle small numbers correctly
        @test result.hit == true
        @test result.distance1 > 0
        @test result.distance2 > result.distance1
    end
end

@testset "Sphere Type" begin
    # Test 1: Valid sphere creation
    @testset "Valid sphere" begin
        sphere = Sphere([1.0, 2.0, 3.0], 5.0)
        @test sphere.center ≈ SVector(1.0, 2.0, 3.0)
        @test sphere.radius ≈ 5.0
    end
    
    # Test 2: Zero radius sphere
    @testset "Zero radius" begin
        sphere = Sphere([0.0, 0.0, 0.0], 0.0)
        @test sphere.radius == 0.0
    end
    
    # Test 3: Negative radius should throw error
    @testset "Negative radius" begin
        @test_throws ArgumentError Sphere([0.0, 0.0, 0.0], -1.0)
    end
    
    # Test 4: Type conversion
    @testset "Type conversion" begin
        sphere = Sphere([1, 2, 3], 5)  # Integer inputs
        @test sphere.center isa SVector{3, Float64}
        @test sphere.radius isa Float64
    end
end
