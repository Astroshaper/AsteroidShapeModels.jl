#= ====================================================================
                Edge Cases and Numerical Precision Tests
====================================================================
This file tests edge cases and numerical stability:
- Degenerate triangles (collinear vertices, zero area)
- Extreme scale differences (very large/small coordinates)
- Ray intersection edge cases (parallel rays, vertex/edge hits)
- Volume calculation for non-closed and inverted shapes
- Numerical stability for cross products and normalizations
=# 

@testset "Edge Cases and Numerical Precision Tests" begin
    
    @testset "Degenerate Triangles" begin
        @testset "Zero-area triangle (collinear vertices)" begin
            # All vertices on a line
            v1 = SA[0.0, 0.0, 0.0]
            v2 = SA[1.0, 0.0, 0.0]
            v3 = SA[2.0, 0.0, 0.0]
            
            # Face area should be zero
            area = face_area(v1, v2, v3)
            @test area ≈ 0.0 atol=1e-10
            
            # Normal vector computation might fail or return arbitrary direction
            # Check that it doesn't throw
            normal = face_normal(v1, v2, v3)
            @test length(normal) == 3
            
            # Center should still be computable
            center = face_center(v1, v2, v3)
            @test center ≈ SA[1.0, 0.0, 0.0]
        end
        
        @testset "Triangle with duplicate vertices" begin
            v1 = SA[1.0, 0.0, 0.0]
            v2 = SA[1.0, 0.0, 0.0]  # Same as v1
            v3 = SA[0.0, 1.0, 0.0]
            
            area = face_area(v1, v2, v3)
            @test area ≈ 0.0 atol=1e-10
            
            # Test with all vertices the same
            v_same = SA[1.0, 2.0, 3.0]
            area_same = face_area(v_same, v_same, v_same)
            @test area_same ≈ 0.0 atol=1e-10
            
            center_same = face_center(v_same, v_same, v_same)
            @test center_same ≈ v_same
        end
        
        @testset "Nearly collinear vertices" begin
            # Almost collinear (numerical precision test)
            v1 = SA[0.0, 0.0, 0.0]
            v2 = SA[1.0, 1e-15, 0.0]  # Tiny deviation
            v3 = SA[2.0, 2e-15, 0.0]
            
            area = face_area(v1, v2, v3)
            @test area ≈ 0.0 atol=1e-14
        end
    end
    
    @testset "Extreme Scale Differences" begin
        @testset "Very large coordinates" begin
            scale = 1e10
            v1 = SA[0.0, 0.0, 0.0] * scale
            v2 = SA[1.0, 0.0, 0.0] * scale
            v3 = SA[0.0, 1.0, 0.0] * scale
            
            area = face_area(v1, v2, v3)
            @test area ≈ 0.5 * scale^2 rtol=1e-10
            
            center = face_center(v1, v2, v3)
            @test center ≈ SA[1/3, 1/3, 0.0] * scale rtol=1e-10
        end
        
        @testset "Very small coordinates" begin
            scale = 1e-10
            v1 = SA[0.0, 0.0, 0.0] * scale
            v2 = SA[1.0, 0.0, 0.0] * scale
            v3 = SA[0.0, 1.0, 0.0] * scale
            
            area = face_area(v1, v2, v3)
            @test area ≈ 0.5 * scale^2 rtol=1e-10
        end
        
        @testset "Mixed scales" begin
            # Large differences in coordinate magnitudes
            v1 = SA[1e-10, 0.0, 0.0]
            v2 = SA[0.0, 1e10, 0.0]
            v3 = SA[0.0, 0.0, 1.0]
            
            # Should still compute without overflow/underflow
            area = face_area(v1, v2, v3)
            @test isfinite(area)
            @test area > 0
            
            normal = face_normal(v1, v2, v3)
            @test norm(normal) ≈ 1.0 rtol=1e-10
        end
    end
    
    @testset "Ray Intersection Edge Cases" begin
        @testset "Ray parallel to triangle" begin
            # Triangle in xy-plane
            v1 = SA[0.0, 0.0, 0.0]
            v2 = SA[1.0, 0.0, 0.0]
            v3 = SA[0.0, 1.0, 0.0]
            
            # Ray parallel to triangle (in xy-plane)
            ray_dir = SA[1.0, 0.0, 0.0]
            ray_origin = SA[0.0, 0.0, 0.0]
            
            # Should not intersect (ray is in the plane)
            ray = Ray(ray_origin, ray_dir)
            @test intersect_ray_triangle(ray, v1, v2, v3).hit == false
        end
        
        @testset "Ray through triangle edge" begin
            v1 = SA[0.0, 0.0, 0.0]
            v2 = SA[1.0, 0.0, 0.0]
            v3 = SA[0.0, 1.0, 0.0]
            
            # Ray through midpoint of edge v1-v2 (0.5, 0.0, 0.0)
            # The ray origin is at (0, 0, -0.5)
            ray_dir = SA[0.5, 0.0, 0.5]
            ray_origin = SA[0.0, 0.0, -0.5]
            # Should hit on edge
            ray = Ray(ray_origin, ray_dir)
            @test intersect_ray_triangle(ray, v1, v2, v3).hit == true
        end
        
        @testset "Ray through triangle vertex" begin
            v1 = SA[0.0, 0.0, 0.0]
            v2 = SA[1.0, 0.0, 0.0]
            v3 = SA[0.0, 1.0, 0.0]
            
            # Ray through vertex v1 from below
            ray_dir = SA[0.0, 0.0, 1.0]
            ray_origin = SA[0.0, 0.0, -1.0]
            # Should hit on vertex
            ray = Ray(ray_origin, ray_dir)
            @test intersect_ray_triangle(ray, v1, v2, v3).hit == true
        end
        
        @testset "Nearly parallel ray" begin
            v1 = SA[0.0, 0.0, 0.0]
            v2 = SA[1.0, 0.0, 0.0]
            v3 = SA[0.0, 1.0, 0.0]
            
            # Ray almost parallel to triangle
            ray_dir = SA[1.0, 0.0, 1e-10]  # Tiny z component
            ray = Ray(SA[0.0, 0.0, 0.0], ray_dir)
            # Result depends on numerical precision - just verify it doesn't crash
            result = intersect_ray_triangle(ray, v1, v2, v3)
            @test isa(result, RayTriangleIntersectionResult)
        end
    end
    
    @testset "Volume Calculation Edge Cases" begin
        @testset "Non-closed shape" begin
            # Single triangle (not closed)
            nodes = [
                SA[0.0, 0.0, 0.0],
                SA[1.0, 0.0, 0.0],
                SA[0.0, 1.0, 0.0]
            ]
            faces = [SA[1, 2, 3]]
            
            volume = polyhedron_volume(nodes, faces)
            @test volume ≈ 0.0 atol=1e-10
        end
        
        @testset "Inside-out shape" begin
            # Tetrahedron with inverted normals
            nodes = [
                SA[0.0, 0.0, 0.0],
                SA[1.0, 0.0, 0.0],
                SA[0.5, sqrt(3)/2, 0.0],
                SA[0.5, sqrt(3)/6, sqrt(6)/3]
            ]
            
            # Faces with reversed orientation
            faces = [
                SA[1, 3, 2],  # Reversed
                SA[1, 4, 2],  # Reversed
                SA[2, 4, 3],  # Reversed
                SA[3, 4, 1]   # Reversed
            ]
            
            volume = polyhedron_volume(nodes, faces)
            # Volume should be negative for inside-out shape
            @test volume < 0
        end
    end
    
    @testset "Visibility Edge Cases" begin
        @testset "Self-viewing face" begin
            # A face should not view itself
            c = SA[0.0, 0.0, 0.0]
            n = SA[0.0, 0.0, 1.0]
            area = 1.0
            
            # Same face viewing itself
            f, d, d_hat = view_factor(c, c, n, n, area)
            @test d ≈ 0.0
            # View factor might be Inf or NaN due to division by zero
        end
        
        @testset "Opposite normals perfect alignment" begin
            c1 = SA[0.0, 0.0, 0.0]
            c2 = SA[0.0, 0.0, 1.0]
            n1 = SA[0.0, 0.0, 1.0]
            n2 = SA[0.0, 0.0, -1.0]
            area = 1.0
            
            f, d, d_hat = view_factor(c1, c2, n1, n2, area)
            @test f ≈ 1/π atol=1e-10
            @test d ≈ 1.0
            @test d_hat ≈ SA[0.0, 0.0, 1.0]
        end
    end
    
    @testset "Grid Edge Cases" begin
        @testset "1x1 grid (single cell)" begin
            xs = [0.0, 1.0]
            ys = [0.0, 1.0]
            zs = [0.0 0.0; 0.0 0.0]
            
            nodes, faces = grid_to_faces(xs, ys, zs)
            
            @test length(nodes) == 4
            @test length(faces) == 2  # Two triangles per cell
        end
        
        @testset "Degenerate grid (zero area cells)" begin
            # Grid with zero width
            xs = [0.0, 0.0]  # Same x coordinates
            ys = [0.0, 1.0]
            zs = [0.0 0.0; 0.0 0.0]
            
            nodes, faces = grid_to_faces(xs, ys, zs)
            
            # Should still create structure, but triangles have zero area
            @test length(nodes) == 4
            @test length(faces) == 2
            
            # Check that faces have zero area
            for face in faces
                area = face_area(nodes[face]...)
                @test area ≈ 0.0 atol=1e-10
            end
        end
    end
    
    @testset "Numerical Stability" begin
        @testset "Cross product numerical stability" begin
            # Nearly parallel vectors
            v1 = SA[1.0, 0.0, 0.0]
            v2 = SA[1.0, 1e-15, 0.0]
            
            # Cross product should be stable
            cross_prod = v1 × v2
            @test isfinite(norm(cross_prod))
            @test norm(cross_prod) ≈ 1e-15 atol=1e-20
        end
        
        @testset "Normalization edge cases" begin
            # Zero vector normalization (used in face_normal)
            zero_vec = SA[0.0, 0.0, 0.0]
            # normalize will return NaN for zero vector
            normalized = normalize(zero_vec)
            @test all(isnan, normalized)
        end
        
        @testset "Distance calculations" begin
            # Very close points
            p1 = SA[0.0, 0.0, 0.0]
            p2 = SA[1e-15, 0.0, 0.0]
            
            dist = norm(p2 - p1)
            @test dist ≈ 1e-15 atol=1e-20
            
            # Very far points
            p3 = SA[1e15, 0.0, 0.0]
            dist_far = norm(p3 - p1)
            @test dist_far ≈ 1e15 rtol=1e-10
        end
    end
end
