#=
    test_surface_roughness.jl

Unit tests for surface roughness management on `ShapeModel` (`SurfaceRoughness`).
Tests cover:
- Roughness data construction and initialization
- Roughness model management
- Local coordinate system computation
- Coordinate transformations
=#

@testset "SurfaceRoughness" begin
    msg = """\n
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                     Test: SurfaceRoughness                        ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """
    println(msg)

    @testset "Smooth ShapeModel (no roughness)" begin
        tetra_nodes, tetra_faces = create_regular_tetrahedron()
        shape = ShapeModel(tetra_nodes, tetra_faces)

        # A freshly constructed ShapeModel has no roughness data
        @test shape.roughness === nothing
        @test has_roughness(shape) == false
        @test all(!has_roughness_model(shape, i) for i in 1:4)
        @test get_roughness_model(shape, 1) === nothing

        # Scale/transform queries require roughness data
        @test_throws ArgumentError get_roughness_model_scale(shape, 1)
        @test_throws ArgumentError get_roughness_model_transform(shape, 1)
    end

    @testset "Roughness Model Management" begin
        tetra_nodes, tetra_faces = create_regular_tetrahedron()
        shape = ShapeModel(tetra_nodes, tetra_faces)

        # Create a simple roughness model (2x2 grid)
        roughness_nodes = [
            SA[0.0, 0.0, 0.0],
            SA[1.0, 0.0, 0.0],
            SA[0.0, 1.0, 0.0],
            SA[1.0, 1.0, 0.0]
        ]
        roughness_faces = [
            SA[1, 2, 3],
            SA[2, 4, 3]
        ]
        roughness_model = ShapeModel(roughness_nodes, roughness_faces)

        @testset "add_roughness_models! - single face" begin
            # Add to single face; shape.roughness is constructed on first call
            add_roughness_models!(shape, roughness_model, 1, scale=0.1)

            @test has_roughness(shape) == true
            @test shape.roughness isa SurfaceRoughness{ShapeModel}
            @test length(shape.roughness.face_roughness_indices) == 4
            @test length(shape.roughness.face_roughness_transforms) == 4
            @test length(shape.roughness.roughness_models) == 1

            @test has_roughness_model(shape, 1) == true
            @test has_roughness_model(shape, 2) == false
            @test get_roughness_model(shape, 1) === roughness_model
            @test get_roughness_model(shape, 2) === nothing
            @test get_roughness_model_scale(shape, 1) ≈ 0.1
            @test get_roughness_model_scale(shape, 2) ≈ 1.0  # Default scale for faces without roughness
            @test get_roughness_model_transform(shape, 1) != AsteroidShapeModels.IDENTITY_AFFINE_MAP
            @test get_roughness_model_transform(shape, 2) == AsteroidShapeModels.IDENTITY_AFFINE_MAP  # Default transform
        end

        @testset "add_roughness_models! - multiple faces" begin
            # Add to multiple faces
            add_roughness_models!(shape, roughness_model, 2, scale=0.05)
            add_roughness_models!(shape, roughness_model, 3, scale=0.05)

            @test has_roughness_model(shape, 2) == true
            @test has_roughness_model(shape, 3) == true
            @test get_roughness_model_scale(shape, 2) ≈ 0.05
            @test get_roughness_model_scale(shape, 3) ≈ 0.05

            # The same model instance is shared, not duplicated
            @test length(shape.roughness.roughness_models) == 1
        end

        @testset "clear_roughness_models!" begin
            # Clear specific face
            clear_roughness_models!(shape, 1)
            @test has_roughness_model(shape, 1) == false
            @test has_roughness_model(shape, 2) == true

            # Clear all faces; roughness data is reset to nothing
            clear_roughness_models!(shape)
            @test shape.roughness === nothing
            @test has_roughness(shape) == false
            @test all(!has_roughness_model(shape, i) for i in 1:4)
        end

        @testset "clear_roughness_models! - face-wise clearing resets to nothing" begin
            add_roughness_models!(shape, roughness_model, 1, scale=0.1)
            add_roughness_models!(shape, roughness_model, 2, scale=0.1)

            clear_roughness_models!(shape, 1)
            @test has_roughness(shape) == true

            # Clearing the last face with roughness resets shape.roughness to nothing
            clear_roughness_models!(shape, 2)
            @test shape.roughness === nothing

            # Clearing a face on a smooth shape is a no-op
            clear_roughness_models!(shape, 1)
            @test shape.roughness === nothing
        end

        @testset "add_roughness_models! - all faces" begin
            add_roughness_models!(shape, roughness_model; scale=0.1)

            @test has_roughness(shape) == true
            @test all(has_roughness_model(shape, i) for i in 1:4)
            @test all(get_roughness_model(shape, i) === roughness_model for i in 1:4)
            @test length(shape.roughness.roughness_models) == 1

            clear_roughness_models!(shape)
        end

        @testset "add_roughness_models! - error handling" begin
            # Test invalid face indices
            @test_throws BoundsError add_roughness_models!(shape, roughness_model, 0)
            @test_throws BoundsError add_roughness_models!(shape, roughness_model, 5)
            @test_throws BoundsError add_roughness_models!(shape, roughness_model, -1)

            # Test invalid scale
            @test_throws ArgumentError add_roughness_models!(shape, roughness_model, 1, scale=-0.1)
            @test_throws ArgumentError add_roughness_models!(shape, roughness_model, 1, scale=0.0)
        end

        @testset "Nested roughness is not supported" begin
            # A roughness model that itself has roughness is rejected
            rough_rough = ShapeModel(roughness_nodes, roughness_faces)
            add_roughness_models!(rough_rough, ShapeModel(roughness_nodes, roughness_faces), 1, scale=0.1)

            @test_throws ArgumentError add_roughness_models!(shape, rough_rough; scale=0.1)
            @test_throws ArgumentError add_roughness_models!(shape, rough_rough, 1; scale=0.1)
        end
    end

    @testset "Coordinate Transformations" begin
        tetra_nodes, tetra_faces = create_regular_tetrahedron()
        shape = ShapeModel(tetra_nodes, tetra_faces)

        roughness_model = ShapeModel(
            [SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0], SA[0.0, 1.0, 0.0], SA[1.0, 1.0, 0.0]],
            [SA[1, 2, 3], SA[2, 4, 3]],
        )
        add_roughness_models!(shape, roughness_model, 1, scale=0.1)

        @testset "Point transformations" begin
            face_center_global = shape.face_centers[1]
            face_center_local  = transform_point_global_to_local(shape, 1, face_center_global)

            # Face center maps to UV center (0.5, 0.5, 0.0)
            @test face_center_local ≈ [0.5, 0.5, 0.0]

            # Round-trip: face center
            @test transform_point_local_to_global(shape, 1, face_center_local) ≈ face_center_global

            # Round-trip: arbitrary point
            p_global = SVector(0.2, 0.3, 0.4)
            p_local  = transform_point_global_to_local(shape, 1, p_global)
            @test transform_point_local_to_global(shape, 1, p_local) ≈ p_global

            # Point offset along face normal: z-component reflects elevation / scale
            face_normal_global = shape.face_normals[1]
            offset  = 0.1
            p_global = face_center_global + offset * face_normal_global
            p_local  = transform_point_global_to_local(shape, 1, p_global)
            scale    = get_roughness_model_scale(shape, 1)
            @test p_local ≈ [0.5, 0.5, offset / scale]
        end

        @testset "Geometric vector transformations" begin
            scale              = get_roughness_model_scale(shape, 1)
            face_normal_global = shape.face_normals[1]
            face_normal_local  = transform_geometric_vector_global_to_local(shape, 1, face_normal_global)

            # Face normal should point in +z in local coordinates (scaled by 1/scale)
            @test abs(face_normal_local[1]) < 1e-10
            @test abs(face_normal_local[2]) < 1e-10
            @test face_normal_local[3] ≈ 1.0 / scale

            # Round-trip
            @test transform_geometric_vector_local_to_global(shape, 1, face_normal_local) ≈ face_normal_global

            # Length is scaled
            v_global = normalize(SVector(1.0, 2.0, 3.0))
            v_local  = transform_geometric_vector_global_to_local(shape, 1, v_global)
            @test norm(v_local) ≈ norm(v_global) / scale
        end

        @testset "Physical vector transformations" begin
            # Magnitude is preserved (rotation only, no scaling)
            v_global = SVector(1.0, 2.0, 3.0)
            v_local  = transform_physical_vector_global_to_local(shape, 1, v_global)
            @test norm(v_local) ≈ norm(v_global)

            # Round-trip
            @test transform_physical_vector_local_to_global(shape, 1, v_local) ≈ v_global
        end

        @testset "Transformations without roughness model" begin
            @test_throws ArgumentError transform_point_global_to_local(shape, 4, SVector(0.0, 0.0, 0.0))
            @test_throws ArgumentError transform_point_local_to_global(shape, 4, SVector(0.0, 0.0, 0.0))
            @test_throws ArgumentError transform_geometric_vector_global_to_local(shape, 4, SVector(1.0, 0.0, 0.0))
            @test_throws ArgumentError transform_geometric_vector_local_to_global(shape, 4, SVector(1.0, 0.0, 0.0))
            @test_throws ArgumentError transform_physical_vector_global_to_local(shape, 4, SVector(1.0, 0.0, 0.0))
            @test_throws ArgumentError transform_physical_vector_local_to_global(shape, 4, SVector(1.0, 0.0, 0.0))
        end
    end

    @testset "Local Coordinate System" begin
        # Use helper function to create cube for testing different face orientations
        cube_nodes, cube_faces = create_unit_cube()
        shape = ShapeModel(cube_nodes, cube_faces)

        @testset "Coordinate system properties" begin
            for face_idx in eachindex(cube_faces)
                origin, e_x, e_y, e_z = AsteroidShapeModels.compute_local_coordinate_system(shape, face_idx)

                # Origin should be at face center
                @test origin ≈ shape.face_centers[face_idx]

                # Coordinate system should be orthonormal
                @test norm(e_x) ≈ 1.0
                @test norm(e_y) ≈ 1.0
                @test norm(e_z) ≈ 1.0
                @test abs(dot(e_x, e_y)) < 1e-10
                @test abs(dot(e_x, e_z)) < 1e-10
                @test abs(dot(e_y, e_z)) < 1e-10

                # e_z should align with face normal
                @test e_z ≈ shape.face_normals[face_idx]

                # Right-handed system
                @test cross(e_x, e_y) ≈ e_z
            end
        end

        @testset "North alignment for horizontal faces" begin
            # Find faces that are roughly horizontal (normal pointing up or down)
            for face_idx in eachindex(cube_faces)
                n̂ = shape.face_normals[face_idx]
                if abs(n̂[3]) > 0.99  # Nearly horizontal plane
                    origin, e_x, e_y, e_z = AsteroidShapeModels.compute_local_coordinate_system(shape, face_idx)

                    # e_x should point east (±x direction; sign flips for downward faces)
                    @test abs(e_x[1]) > 0.9
                    @test abs(e_x[2]) < 0.1
                    @test abs(e_x[3]) < 0.1

                    # e_y should point north (positive y-direction in global frame)
                    @test abs(e_y[1]) < 0.1
                    @test e_y[2] > 0.9
                    @test abs(e_y[3]) < 0.1
                end
            end
        end
    end

    @testset "compute_face_roughness_transform" begin
        tetra_nodes, tetra_faces = create_regular_tetrahedron()
        shape = ShapeModel(tetra_nodes, tetra_faces)

        # Test transform computation
        transform = AsteroidShapeModels.compute_face_roughness_transform(shape, 1, scale=0.1)

        @test transform isa AsteroidShapeModels.AFFINE_MAP_TYPE

        # Test that face center maps to (0.5, 0.5, 0.0)
        face_center_global = shape.face_centers[1]
        local_center = transform(face_center_global)
        @test local_center[1] ≈ 0.5 atol=1e-10
        @test local_center[2] ≈ 0.5 atol=1e-10
        @test local_center[3] ≈ 0.0 atol=1e-10

        # Test with different scale
        transform_large = AsteroidShapeModels.compute_face_roughness_transform(shape, 1, scale=1.0)
        transform_small = AsteroidShapeModels.compute_face_roughness_transform(shape, 1, scale=0.01)

        # Same global point should map to same local UV coordinates
        test_point = face_center_global + SVector(0.01, 0.01, 0.01)
        local_large = transform_large(test_point)
        local_small = transform_small(test_point)

        # UV coordinates should be different due to scale
        @test !isapprox(local_large, local_small)
    end

    @testset "show with roughness" begin
        tetra_nodes, tetra_faces = create_regular_tetrahedron()
        shape = ShapeModel(tetra_nodes, tetra_faces)

        # No roughness line for a smooth shape
        @test !occursin("Surface roughness", sprint(show, shape))

        roughness_model = ShapeModel(
            [SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0], SA[0.0, 1.0, 0.0], SA[1.0, 1.0, 0.0]],
            [SA[1, 2, 3], SA[2, 4, 3]],
        )
        add_roughness_models!(shape, roughness_model, 1, scale=0.1)
        add_roughness_models!(shape, roughness_model, 2, scale=0.1)

        # Shared model counted once; faces with roughness counted separately
        @test occursin("Surface roughness : 1 model(s) on 2 face(s)", sprint(show, shape))
    end
end
