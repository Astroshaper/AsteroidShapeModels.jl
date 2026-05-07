#= ====================================================================
                 Ryugu Shape Model Correctness Test
====================================================================
Correctness tests using a realistic asteroid shape model:
- Shape loading and basic properties
- Face geometry validity
- Ray-shape intersection
- Visibility graph statistics
- Shape metrics
- Uses the Ryugu test model (2976 nodes, 5932 faces)
=#

@testset "Ryugu Shape Model Performance Test" begin
    msg = """\n
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    |           Test: Ryugu Shape Model Performance          |
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    """
    println(msg)

    path_shape = joinpath("shape", "ryugu_test.obj")

    shape     = load_shape_obj(path_shape; with_face_visibility=false, with_bvh=true)
    shape_vis = load_shape_obj(path_shape; with_face_visibility=true,  with_bvh=true)

    @testset "Shape loading" begin
        @test length(shape.nodes) == 2976
        @test length(shape.faces) == 5932
        @test length(shape.face_normals) == 5932
        @test length(shape.face_areas)   == 5932
        @test length(shape.face_centers) == 5932
    end

    @testset "Face geometry" begin
        # All face normals should be unit vectors
        @test all(n -> norm(n) ≈ 1.0, shape.face_normals)

        # All face areas should be positive
        @test all(a -> a > 0.0, shape.face_areas)
    end

    @testset "Ray intersection" begin
        # Ray from above should hit the shape
        ray_hit  = Ray(SA[0.0, 0.0, 1000.0], SA[0.0, 0.0, -1.0])
        result   = intersect_ray_shape(ray_hit, shape)
        @test result.hit == true
        @test result.distance > 0.0

        # Ray pointing away should miss
        ray_miss = Ray(SA[0.0, 0.0, 1000.0], SA[0.0, 0.0, 1.0])
        result2  = intersect_ray_shape(ray_miss, shape)
        @test result2.hit == false
    end

    @testset "Visibility graph" begin
        @test shape_vis.face_visibility_graph.nnz > 0
        avg_visible = shape_vis.face_visibility_graph.nnz / length(shape_vis.faces)
        @test avg_visible > 0.0
    end

    @testset "Shape metrics" begin
        @test polyhedron_volume(shape) > 0.0
        @test equivalent_radius(shape) > 0.0
        @test maximum_radius(shape)    ≥ minimum_radius(shape)
    end

    @testset "Illumination" begin
        view_dir = SA[1.0, 0.0, 0.0]
        # At least some faces should be illuminated
        n_illuminated = count(i -> isilluminated(shape_vis, view_dir, i; with_self_shadowing=true),
                              eachindex(shape_vis.faces))
        @test 0 < n_illuminated < length(shape_vis.faces)
    end
end