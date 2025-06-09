using Test
using AsteroidShapeModels
using StaticArrays
using LinearAlgebra

@testset "Raycast migration validation" begin
    # Define test triangles and rays
    triangles = [
        # Triangle in XY plane
        (SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0], SA[0.0, 1.0, 0.0]),
        # Triangle in XZ plane
        (SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0], SA[0.0, 0.0, 1.0]),
        # Triangle in YZ plane
        (SA[0.0, 0.0, 0.0], SA[0.0, 1.0, 0.0], SA[0.0, 0.0, 1.0]),
        # Tilted triangle
        (SA[0.0, 0.0, 0.0], SA[1.0, 1.0, 0.0], SA[0.0, 1.0, 1.0]),
    ]
    
    # Test cases with ray origins and directions
    test_cases = [
        # Ray from above hitting triangle
        (origin=SA[0.1, 0.1, 1.0], direction=SA[0.0, 0.0, -1.0]),
        # Ray from below missing triangle
        (origin=SA[-0.1, -0.1, -1.0], direction=SA[0.0, 0.0, 1.0]),
        # Ray parallel to triangle
        (origin=SA[0.0, 0.0, 0.0], direction=SA[1.0, 0.0, 0.0]),
        # Ray at angle
        (origin=SA[-1.0, -1.0, -1.0], direction=normalize(SA[1.0, 1.0, 1.0])),
        # Ray from side
        (origin=SA[2.0, 0.5, 0.5], direction=SA[-1.0, 0.0, 0.0]),
        # Ray from very close
        (origin=SA[0.1, 0.1, 0.01], direction=SA[0.0, 0.0, -1.0]),
    ]
    
    @testset "Compare raycast with intersect_ray_triangle" begin
        for (i, (A, B, C)) in enumerate(triangles)
            for (j, tc) in enumerate(test_cases)
                # Test raycast with origin at (0,0,0)
                if tc.origin == SA[0.0, 0.0, 0.0]
                    raycast_result = raycast(A, B, C, tc.direction)
                    
                    # Create Ray object for intersect_ray_triangle
                    ray = Ray(tc.origin, tc.direction)
                    intersect_result = intersect_ray_triangle(ray, A, B, C)
                    
                    @test raycast_result == intersect_result.hit broken=false
                end
                
                # Test raycast with custom origin
                raycast_result = raycast(A, B, C, tc.direction, tc.origin)
                
                # Create Ray object for intersect_ray_triangle
                ray = Ray(tc.origin, tc.direction)
                intersect_result = intersect_ray_triangle(ray, A, B, C)
                
                @test raycast_result == intersect_result.hit broken=false
                
                # If both detect intersection, verify the intersection point
                if raycast_result && intersect_result.hit
                    # For raycast, we need to compute the intersection point manually
                    # Using the same algorithm as raycast but extracting the t parameter
                    E1 = B - A
                    E2 = C - A
                    T = tc.origin - A
                    
                    P = tc.direction × E2
                    Q = T × E1
                    
                    P_dot_E1 = P ⋅ E1
                    t = (Q ⋅ E2) / P_dot_E1
                    
                    raycast_point = tc.origin + t * tc.direction
                    
                    # Check that the intersection points are approximately equal
                    @test isapprox(raycast_point, intersect_result.point, atol=1e-10)
                end
            end
        end
    end
    
    @testset "Edge cases validation" begin
        # Ray through edge
        v1 = SA[0.0, 0.0, 0.0]
        v2 = SA[1.0, 0.0, 0.0]
        v3 = SA[0.0, 1.0, 0.0]
        
        # Ray passing exactly through edge v1-v2
        ray_origin = SA[0.5, 0.0, -1.0]
        ray_dir = SA[0.0, 0.0, 1.0]
        
        raycast_result = raycast(v1, v2, v3, ray_dir, ray_origin)
        ray = Ray(ray_origin, ray_dir)
        intersect_result = intersect_ray_triangle(ray, v1, v2, v3)
        
        @test raycast_result == intersect_result.hit
        
        # Ray passing exactly through vertex
        ray_origin = SA[0.0, 0.0, -1.0]
        ray_dir = SA[0.0, 0.0, 1.0]
        
        raycast_result = raycast(v1, v2, v3, ray_dir, ray_origin)
        ray = Ray(ray_origin, ray_dir)
        intersect_result = intersect_ray_triangle(ray, v1, v2, v3)
        
        @test raycast_result == intersect_result.hit
        
        # Nearly parallel ray
        ray_origin = SA[0.0, 0.0, 0.0]
        ray_dir = SA[1.0, 0.0, 1e-10]
        
        raycast_result = raycast(v1, v2, v3, ray_dir)
        ray = Ray(ray_origin, ray_dir)
        intersect_result = intersect_ray_triangle(ray, v1, v2, v3)
        
        @test raycast_result == intersect_result.hit
    end
    
    @testset "Real-world usage patterns" begin
        # Pattern 1: Visibility check between face centers (from visibility.jl)
        shape = load_shape_obj(joinpath(@__DIR__, "shape", "icosahedron.obj"))
        
        for i in 1:length(shape.faces)
            for j in 1:length(shape.faces)
                if i != j
                    ci = shape.face_centers[i]
                    cj = shape.face_centers[j]
                    Rij = normalize(cj - ci)
                    
                    # Test occlusion by all other faces
                    for k in 1:length(shape.faces)
                        if k != i && k != j
                            face = shape.faces[k]
                            A, B, C = shape.nodes[face[1]], shape.nodes[face[2]], shape.nodes[face[3]]
                            
                            # Compare results
                            raycast_result = raycast(A, B, C, Rij, ci)
                            ray = Ray(ci, Rij)
                            intersect_result = intersect_ray_triangle(ray, A, B, C)
                            
                            @test raycast_result == intersect_result.hit
                        end
                    end
                end
            end
        end
        
        # Pattern 2: Illumination check (from visibility.jl)
        sun_direction = normalize(SA[1.0, 1.0, 1.0])
        
        for i in 1:length(shape.faces)
            ci = shape.face_centers[i]
            
            # Check if any face blocks the sun
            for j in 1:length(shape.faces)
                if i != j
                    face = shape.faces[j]
                    A, B, C = shape.nodes[face[1]], shape.nodes[face[2]], shape.nodes[face[3]]
                    
                    raycast_result = raycast(A, B, C, sun_direction, ci)
                    ray = Ray(ci, sun_direction)
                    intersect_result = intersect_ray_triangle(ray, A, B, C)
                    
                    @test raycast_result == intersect_result.hit
                end
            end
        end
    end
end