#=
    test_hierarchical_shape_model.jl

Unit tests for HierarchicalShapeModel and its associated functions.
Tests cover:
- Type construction and initialization
- Roughness model management
- Coordinate transformations
- Local coordinate system computation
=#

@testset "HierarchicalShapeModel" begin
    msg = """\n
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                   Test: HierarchicalShapeModel                    ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """
    println(msg)
    
    # Use helper function to create test shapes
    tetra_nodes, tetra_faces = create_regular_tetrahedron()
    base_shape = ShapeModel(tetra_nodes, tetra_faces)
    
    @testset "Construction and Basic Properties" begin
        # Test basic construction
        hier_shape = HierarchicalShapeModel(base_shape)
        
        @test hier_shape isa HierarchicalShapeModel
        @test hier_shape isa AbstractShapeModel
        @test hier_shape.global_shape === base_shape
        @test length(hier_shape.face_roughness_indices) == 4
        @test length(hier_shape.face_roughness_scales) == 4
        @test length(hier_shape.face_roughness_transforms) == 4
        @test length(hier_shape.roughness_models) == 0
        
        # All indices should be 0 initially (no roughness)
        @test all(==(0), hier_shape.face_roughness_indices)
        @test all(==(1.0), hier_shape.face_roughness_scales)
        @test all(==(AsteroidShapeModels.IDENTITY_AFFINE_MAP), hier_shape.face_roughness_transforms)
        
        # Test property access through global_shape
        @test hier_shape.global_shape.face_centers[1] == base_shape.face_centers[1]
        @test hier_shape.global_shape.face_normals[1] == base_shape.face_normals[1]
        @test hier_shape.global_shape.face_areas[1] == base_shape.face_areas[1]
    end
    
    @testset "Roughness Model Management" begin
        hier_shape = HierarchicalShapeModel(base_shape)
        
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
            # Add to single face
            add_roughness_models!(hier_shape, roughness_model, 1, scale=0.1)
            
            @test has_roughness_model(hier_shape, 1) == true
            @test has_roughness_model(hier_shape, 2) == false
            @test get_roughness_model(hier_shape, 1) === roughness_model
            @test get_roughness_model(hier_shape, 2) === nothing
            @test get_roughness_model_scale(hier_shape, 1) == 0.1
            @test get_roughness_model_scale(hier_shape, 2) == 1.0  # Default scale for faces without roughness
            @test get_roughness_model_transform(hier_shape, 1) != AsteroidShapeModels.IDENTITY_AFFINE_MAP
            @test get_roughness_model_transform(hier_shape, 2) == AsteroidShapeModels.IDENTITY_AFFINE_MAP  # Default transform
        end
        
        @testset "add_roughness_models! - multiple faces" begin
            # Add to multiple faces
            add_roughness_models!(hier_shape, roughness_model, 2, scale=0.05)
            add_roughness_models!(hier_shape, roughness_model, 3, scale=0.05)
            
            @test has_roughness_model(hier_shape, 2) == true
            @test has_roughness_model(hier_shape, 3) == true
            @test get_roughness_model_scale(hier_shape, 2) == 0.05
            @test get_roughness_model_scale(hier_shape, 3) == 0.05
        end
        
        @testset "clear_roughness_models!" begin
            # Clear specific face
            clear_roughness_models!(hier_shape, 1)
            @test has_roughness_model(hier_shape, 1) == false
            @test has_roughness_model(hier_shape, 2) == true
            
            # Clear all faces
            clear_roughness_models!(hier_shape)
            @test all(!has_roughness_model(hier_shape, i) for i in 1:4)
        end
        
        @testset "add_roughness_models! - error handling" begin
            # Test invalid face indices
            @test_throws BoundsError add_roughness_models!(hier_shape, roughness_model, 0)
            @test_throws BoundsError add_roughness_models!(hier_shape, roughness_model, 5)
            @test_throws BoundsError add_roughness_models!(hier_shape, roughness_model, -1)
            
            # Test invalid scale
            @test_throws ArgumentError add_roughness_models!(hier_shape, roughness_model, 1, scale=-0.1)
            @test_throws ArgumentError add_roughness_models!(hier_shape, roughness_model, 1, scale=0.0)
        end
    end
    
    @testset "Coordinate Transformations" begin
        hier_shape = HierarchicalShapeModel(base_shape)
        
        # Create roughness model and add to face 1
        roughness_model = ShapeModel(
            [SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0], SA[0.0, 1.0, 0.0], SA[1.0, 1.0, 0.0]],
            [SA[1, 2, 3], SA[2, 4, 3]],
        )
        add_roughness_models!(hier_shape, roughness_model, 1, scale=0.1)
        
        @testset "Point transformations" begin
            # Test point at face center
            face_center_global = hier_shape.global_shape.face_centers[1]
            face_center_local = transform_point_global_to_local(hier_shape, 1, face_center_global)
            
            # Face center should map to (0.5, 0.5, 0.0) in local coordinates
            @test face_center_local ≈ [0.5, 0.5, 0.0]
            
            # Test round-trip transformation of face-1's center
            @test transform_point_local_to_global(hier_shape, 1, face_center_local) ≈ face_center_global
            
            # Test round-trip transformation of arbitrary point
            p_global = SVector(0.2, 0.3, 0.4)
            p_local = transform_point_global_to_local(hier_shape, 1, p_global)
            @test transform_point_local_to_global(hier_shape, 1, p_local) ≈ p_global

            # Test point slightly offset along face normal
            face_center_global = hier_shape.global_shape.face_centers[1]
            face_normal_global = hier_shape.global_shape.face_normals[1]
            offset = 0.1
            p_global = face_center_global + offset * face_normal_global
            p_local = transform_point_global_to_local(hier_shape, 1, p_global)
            # x,y stay at UV center; z reflects elevation scaled by 1/scale
            scale = get_roughness_model_scale(hier_shape, 1)
            @test p_local ≈ [0.5, 0.5, offset / scale]
        end
        
        @testset "Geometric vector transformations" begin
            # Test with face normal
            face_normal_global = hier_shape.global_shape.face_normals[1]
            local_normal = transform_geometric_vector_global_to_local(hier_shape, 1, face_normal_global)
            
            # Face normal should point in +z direction in local coordinates
            @test abs(local_normal[1]) < 1e-10
            @test abs(local_normal[2]) < 1e-10
            @test local_normal[3] ≈ 1.0
            
            # Test round-trip
            global_normal_back = transform_geometric_vector_local_to_global(hier_shape, 1, local_normal)
            @test global_normal_back ≈ face_normal_global
            
            # Test that length is preserved
            test_vec = normalize(SVector(1.0, 2.0, 3.0))
            local_vec = transform_geometric_vector_global_to_local(hier_shape, 1, test_vec)
            @test norm(local_vec) ≈ norm(test_vec)
        end
        
        @testset "Physical vector transformations" begin
            # Physical vectors should scale with the roughness scale
            test_phys_vec = SVector(1.0, 0.0, 0.0)
            local_phys = transform_physical_vector_global_to_local(hier_shape, 1, test_phys_vec)
            
            # Should be scaled by 1/scale = 1/0.1 = 10
            @test norm(local_phys) ≈ 10.0 * norm(test_phys_vec)
            
            # Test round-trip
            global_phys_back = transform_physical_vector_local_to_global(hier_shape, 1, local_phys)
            @test global_phys_back ≈ test_phys_vec
        end
        
        @testset "Transformations without roughness model" begin
            # Test face without roughness model - should throw ArgumentError
            @test_throws ArgumentError transform_point_global_to_local(hier_shape, 4, SVector(0.0, 0.0, 0.0))
            @test_throws ArgumentError transform_geometric_vector_global_to_local(hier_shape, 4, SVector(1.0, 0.0, 0.0))
            @test_throws ArgumentError transform_physical_vector_global_to_local(hier_shape, 4, SVector(1.0, 0.0, 0.0))
            @test_throws ArgumentError transform_point_local_to_global(hier_shape, 4, SVector(0.0, 0.0, 0.0))
            @test_throws ArgumentError transform_geometric_vector_local_to_global(hier_shape, 4, SVector(1.0, 0.0, 0.0))
            @test_throws ArgumentError transform_physical_vector_local_to_global(hier_shape, 4, SVector(1.0, 0.0, 0.0))
        end
    end
    
    @testset "Local Coordinate System" begin
        # Use helper function to create cube for testing different face orientations
        cube_nodes, cube_faces = create_unit_cube()
        cube_shape = ShapeModel(cube_nodes, cube_faces)
        hier_cube = HierarchicalShapeModel(cube_shape)
        
        @testset "Coordinate system properties" begin
            for face_idx in 1:size(cube_faces, 2)
                origin, e_x, e_y, e_z = AsteroidShapeModels.compute_local_coordinate_system(hier_cube, face_idx)
                
                # Origin should be at face center
                @test origin ≈ cube_shape.face_centers[face_idx]
                
                # Coordinate system should be orthonormal
                @test norm(e_x) ≈ 1.0
                @test norm(e_y) ≈ 1.0
                @test norm(e_z) ≈ 1.0
                @test abs(dot(e_x, e_y)) < 1e-10
                @test abs(dot(e_x, e_z)) < 1e-10
                @test abs(dot(e_y, e_z)) < 1e-10
                
                # e_z should align with face normal
                @test e_z ≈ cube_shape.face_normals[face_idx]
                
                # Right-handed system
                @test cross(e_x, e_y) ≈ e_z
            end
        end
        
        @testset "North alignment for horizontal faces" begin
            # Find faces that are roughly horizontal (normal pointing up or down)
            for face_idx in 1:size(cube_faces, 2)
                normal = cube_shape.face_normals[face_idx]
                if abs(normal[3]) > 0.9  # Nearly horizontal
                    origin, e_x, e_y, e_z = AsteroidShapeModels.compute_local_coordinate_system(hier_cube, face_idx)
                    
                    # e_x should point north (positive y direction in global frame)
                    @test e_x[2] > 0.9
                    @test abs(e_x[1]) < 0.1
                    @test abs(e_x[3]) < 0.1
                end
            end
        end
    end
    
    @testset "compute_face_roughness_transform" begin
        hier_shape = HierarchicalShapeModel(base_shape)
        
        # Test transform computation
        transform = AsteroidShapeModels.compute_face_roughness_transform(hier_shape, 1, scale=0.1)
        
        @test transform isa AsteroidShapeModels.AFFINE_MAP_TYPE
        
        # Test that face center maps to (0.5, 0.5, 0.0)
        face_center_global = hier_shape.global_shape.face_centers[1]
        local_center = transform(face_center_global)
        @test local_center[1] ≈ 0.5 atol=1e-10
        @test local_center[2] ≈ 0.5 atol=1e-10
        @test local_center[3] ≈ 0.0 atol=1e-10
        
        # Test with different scale
        transform_large = AsteroidShapeModels.compute_face_roughness_transform(hier_shape, 1, scale=1.0)
        transform_small = AsteroidShapeModels.compute_face_roughness_transform(hier_shape, 1, scale=0.01)
        
        # Same global point should map to same local UV coordinates
        test_point = face_center_global + SVector(0.01, 0.01, 0.01)
        local_large = transform_large(test_point)
        local_small = transform_small(test_point)
        
        # UV coordinates should be different due to scale
        @test !isapprox(local_large, local_small)
    end
    
    @testset "Integration with ShapeModel interface" begin
        # Create base shape with BVH for ray intersection tests
        base_shape_with_bvh = ShapeModel(tetra_nodes, tetra_faces, with_bvh=true)
        hier_shape = HierarchicalShapeModel(base_shape_with_bvh)
        
        # Test that HierarchicalShapeModel works with existing functions
        @test equivalent_radius(hier_shape) ≈ equivalent_radius(base_shape_with_bvh)
        @test maximum_radius(hier_shape) ≈ maximum_radius(base_shape_with_bvh)
        @test minimum_radius(hier_shape) ≈ minimum_radius(base_shape_with_bvh)
        @test polyhedron_volume(hier_shape) ≈ polyhedron_volume(base_shape_with_bvh)
        
        # Test ray intersection
        ray = Ray(SVector(2.0, 0.0, 0.0), SVector(-1.0, 0.0, 0.0))
        result_hier = intersect_ray_shape(ray, hier_shape)
        result_base = intersect_ray_shape(ray, base_shape_with_bvh)
        @test result_hier.hit == result_base.hit
        if result_hier.hit
            @test result_hier.distance ≈ result_base.distance
            @test result_hier.point ≈ result_base.point
            @test result_hier.face_idx == result_base.face_idx
        end
    end
end
