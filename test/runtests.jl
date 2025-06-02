using Test
using AsteroidShapeModels
using StaticArrays
using LinearAlgebra
using SPICE
using Downloads

@testset "AsteroidShapeModels.jl" begin
    # Core functionality tests
    include("test_face_properties.jl")
    include("test_ray_intersection.jl")
    include("test_geometry_utils.jl")
    
    # Validation tests against external tools
    include("test_ray_intersection_vs_spice.jl")
    
    # Visibility and view factor tests
    include("test_find_visiblefacets.jl")
end