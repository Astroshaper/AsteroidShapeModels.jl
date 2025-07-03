#=
    runtests.jl

Main test runner for AsteroidShapeModels.jl package.
This file orchestrates all test suites to ensure the package functionality
is working correctly across different components.

Test Categories:
- Face properties calculations
- OBJ file I/O operations
- Ray-shape intersection algorithms
- Face visibility graph
- Shape operations and metrics
- Visibility analysis
- Edge cases and error handling
- Integration tests with SPICE
- Performance benchmarks
=#

using AsteroidShapeModels
using BenchmarkTools
using Downloads
using LinearAlgebra
using Random
using SPICE
using StaticArrays
using Statistics
using Test

# Include test helper functions
include("test_helpers.jl")

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
    
    # Comprehensive BVH tests (ray intersection, isilluminated, visibility graph)
    include("test_bvh_comprehensive.jl")
end