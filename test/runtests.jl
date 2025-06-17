using Test
using AsteroidShapeModels
using StaticArrays
using LinearAlgebra
using SPICE
using Downloads
using BenchmarkTools

@testset "AsteroidShapeModels.jl" begin
    # Core functionality tests
    include("test_face_properties.jl")
    include("test_ray_intersection.jl")
    include("test_geometry_utils.jl")
    
    # Shape operations tests (volume, radii calculations)
    include("test_shape_operations.jl")
    
    # OBJ file I/O tests
    include("test_obj_io.jl")
    
    # Visibility and view factor tests
    include("test_with_face_visibility.jl")
    include("test_visibility_extended.jl")
    include("test_face_visibility_graph.jl")
    
    # Edge cases and numerical precision tests
    include("test_edge_cases.jl")
    
    # Validation tests against external tools
    include("test_ray_intersection_vs_spice.jl")
    
    # Ryugu shape model test
    include("test_ryugu_shape_model.jl")
end