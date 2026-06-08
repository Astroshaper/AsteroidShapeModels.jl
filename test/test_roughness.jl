#=
    test_roughness.jl

Tests for surface roughness geometry functions:
- crater_curvature_radius: curvature radius formula
- concave_spherical_segment: z-depth at a point and full grid generation
- create_shape_crater: ShapeModel construction from crater geometry
=#

@testset "Roughness" begin

    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                   crater_curvature_radius                         ║
    # ╚═══════════════════════════════════════════════════════════════════╝

    @testset "crater_curvature_radius" begin
        @test crater_curvature_radius(100.0, 10.0) ≈ (100^2 + 10^2) / (2 * 10)
        @test crater_curvature_radius(100.0, 50.0) ≈ 125.0
        # Hemisphere: h == r → R == r
        @test crater_curvature_radius(1.0, 1.0) ≈ 1.0
    end

    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                  concave_spherical_segment                        ║
    # ╚═══════════════════════════════════════════════════════════════════╝

    @testset "concave_spherical_segment (point)" begin
        r, h = 0.4, 0.1

        # Center should be at maximum depth -h
        @test concave_spherical_segment(r, h, 0.5, 0.5, 0.5, 0.5) ≈ -h

        # Edge of crater (distance == r) should be 0
        @test concave_spherical_segment(r, h, 0.5, 0.5, 0.5 + r, 0.5) ≈ 0.0 atol=1e-10

        # Outside crater should be 0
        @test concave_spherical_segment(r, h, 0.5, 0.5, 1.0, 1.0) == 0.0
    end

    @testset "concave_spherical_segment (grid)" begin
        r, h = 0.4, 0.1
        Nx, Ny = 16, 16
        xs, ys, zs = concave_spherical_segment(r, h; Nx, Ny)

        @test length(xs) == Nx + 1
        @test length(ys) == Ny + 1
        @test size(zs) == (Nx + 1, Ny + 1)

        # All z values are ≤ 0 (crater only digs in)
        @test all(z -> z ≤ 0.0, zs)

        # Minimum z should equal -h (at the center)
        @test minimum(zs) ≈ -h atol=1e-10
    end

    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                      create_shape_crater                          ║
    # ╚═══════════════════════════════════════════════════════════════════╝

    @testset "create_shape_crater" begin
        @testset "Returns ShapeModel" begin
            crater = create_shape_crater(0.4, 0.1)
            @test crater isa ShapeModel
        end

        @testset "Face count matches grid resolution" begin
            Nx, Ny = 16, 16
            crater = create_shape_crater(0.4, 0.1; Nx, Ny)
            # grid_to_faces produces 2 triangles per grid cell
            @test length(crater.faces) == 2 * Nx * Ny
        end

        @testset "Scale factor is applied" begin
            scale = 100.0
            crater_unscaled = create_shape_crater(0.4, 0.1)
            crater_scaled   = create_shape_crater(0.4, 0.1; scale)
            @test all(n2 ≈ n1 * scale for (n1, n2) in zip(crater_unscaled.nodes, crater_scaled.nodes))
        end

        @testset "with_face_visibility" begin
            crater = create_shape_crater(0.4, 0.1; Nx=8, Ny=8, with_face_visibility=true)
            @test crater.face_visibility_graph !== nothing
        end

        @testset "as_hierarchical" begin
            crater = create_shape_crater(0.4, 0.1; as_hierarchical=true)
            @test crater isa HierarchicalShapeModel
        end
    end
end
