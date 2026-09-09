#=
    test_roughness.jl

Tests for surface roughness geometry functions:
- crater_curvature_radius: curvature radius formula
- concave_spherical_segment: z-depth at a point and full grid generation
- create_shape_crater: ShapeModel construction from crater geometry
- projected_area, rms_slope: roughness statistics (Rozitis & Green 2011)
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

        @testset "No roughness by default" begin
            crater = create_shape_crater(0.4, 0.1)
            @test crater.roughness === nothing
            @test has_roughness(crater) == false
        end
    end

    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                      Roughness statistics                         ║
    # ╚═══════════════════════════════════════════════════════════════════╝

    @testset "projected_area" begin
        # Flat unit square: projected area == 1
        xs = LinRange(0, 1, 17)
        ys = LinRange(0, 1, 17)
        zs = zeros(17, 17)
        flat = load_shape_grid(xs, ys, zs)
        @test projected_area(flat) ≈ 1.0

        # Crater patch on the unit square: z-projection still covers the unit
        # square exactly, so the projected area is unchanged.
        crater = create_shape_crater(0.4, 0.1; Nx=64, Ny=64)
        @test projected_area(crater) ≈ 1.0
    end

    @testset "rms_slope" begin
        # Flat surface has zero RMS slope
        xs = LinRange(0, 1, 17)
        ys = LinRange(0, 1, 17)
        zs = zeros(17, 17)
        flat = load_shape_grid(xs, ys, zs)
        @test rms_slope(flat) ≈ 0.0 atol=1e-12

        # Shallow crater (r=0.4, h=0.1)
        crater_shallow = create_shape_crater(0.4, 0.1; Nx=64, Ny=64)
        @test rad2deg(rms_slope(crater_shallow)) ≈ 13.7 atol=0.2

        # Hemispherical crater (r=0.4, h=0.4), whole patch including flat apron
        crater_hemi = create_shape_crater(0.4, 0.4; Nx=64, Ny=64)
        θ_patch = rms_slope(crater_hemi)
        @test rad2deg(θ_patch) ≈ 36.5 atol=0.2

        # Cratered part alone: divide by √(projected areal coverage of the
        # sloped part). Analytically the coverage is π r², but on a discrete
        # grid the rim discretization makes it slightly larger, so compute it
        # from the flat faces. Compare with Rozitis & Green (2011), Table 1:
        # 90° crater → 49.1–50.0°.
        A_flat = sum(a for (n̂, a) in zip(crater_hemi.face_normals, crater_hemi.face_areas) if n̂[3] > 1 - 1e-12)
        θ_crater = θ_patch / √(1 - A_flat)
        @test rad2deg(θ_crater) ≈ 50.3 atol=0.3
    end
end
