#=
    test_helpers.jl

Common helper functions for AsteroidShapeModels.jl tests.
This file provides reusable utilities for creating test shapes,
managing temporary files, and performing common assertions.
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Common Shape Generators                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    create_xy_triangle() -> (nodes, faces)

Create a unit right triangle in the XY plane.

# Returns
- `nodes`: Array of 3 vertex positions
- `faces`: Array of 1 triangular face definition
"""
function create_xy_triangle()
    nodes = [
        SA[0.0, 0.0, 0.0],  # Origin
        SA[1.0, 0.0, 0.0],  # Point on x-axis
        SA[0.0, 1.0, 0.0],  # Point on y-axis
    ]
    faces = [
        SA[1, 2, 3],
    ]
    return nodes, faces
end

"""
    create_regular_tetrahedron() -> (nodes, faces)

Create a regular tetrahedron with unit edge length.

# Returns
- `nodes`: Array of 4 vertex positions
- `faces`: Array of 4 triangular face definitions
"""
function create_regular_tetrahedron()
    nodes = [
        SA[0.0, 0.0, 0.0],
        SA[1.0, 0.0, 0.0],
        SA[0.5, sqrt(3)/2, 0.0],
        SA[0.5, sqrt(3)/6, sqrt(6)/3],
    ]
    faces = [
        SA[1, 2, 3],  # Base
        SA[1, 2, 4],  # Side 1
        SA[2, 3, 4],  # Side 2
        SA[3, 1, 4],  # Side 3
    ]
    return nodes, faces
end

"""
    create_unit_cube() -> (nodes, faces)

Create a unit cube with corners at (0,0,0) and (1,1,1).

# Returns
- `nodes`: Array of 8 vertex positions
- `faces`: Array of 12 triangular faces (2 per cube face)
"""
function create_unit_cube()
    nodes = [
        SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0],
        SA[1.0, 1.0, 0.0], SA[0.0, 1.0, 0.0],
        SA[0.0, 0.0, 1.0], SA[1.0, 0.0, 1.0],
        SA[1.0, 1.0, 1.0], SA[0.0, 1.0, 1.0],
    ]
    faces = [
        SA[1, 3, 2], SA[1, 4, 3],  # Bottom face (z=0)
        SA[5, 6, 7], SA[5, 7, 8],  # Top face    (z=1)
        SA[1, 2, 6], SA[1, 6, 5],  # Front face  (y=0)
        SA[4, 8, 7], SA[4, 7, 3],  # Back face   (y=1)
        SA[1, 5, 8], SA[1, 8, 4],  # Left face   (x=0)
        SA[2, 3, 7], SA[2, 7, 6],  # Right face  (x=1)
    ]
    return nodes, faces
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                       Validation Helpers                          ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    validate_shape_model(nodes, faces) -> NamedTuple

Validate the structure of a shape model.

# Arguments
- `nodes`: Array of node positions
- `faces`: Array of face definitions

# Returns
NamedTuple with fields:
- `valid_indices`: Whether all face indices are valid
- `valid_dimensions`: Whether all nodes are 3D vectors
- `all_triangular`: Whether all faces are triangles
- `invalid_face_indices`: Array of invalid face indices
- `wrong_dim_nodes`: Indices of nodes with wrong dimensions
- `non_triangular_faces`: Indices of non-triangular faces
"""
function validate_shape_model(nodes, faces)
    # Check face indices validity
    invalid_indices = Int[]
    for (i, face) in enumerate(faces)
        if !all(1 ≤ idx ≤ length(nodes) for idx in face)
            push!(invalid_indices, i)
        end
    end
    
    # Check node dimensions
    nodes_with_wrong_dim = findall(node -> length(node) != 3, nodes)
    
    # Check face triangularity
    non_triangular_faces = findall(face -> length(face) != 3, faces)
    
    return (
        valid_indices = isempty(invalid_indices),
        valid_dimensions = isempty(nodes_with_wrong_dim),
        all_triangular = isempty(non_triangular_faces),
        invalid_face_indices = invalid_indices,
        wrong_dim_nodes = nodes_with_wrong_dim,
        non_triangular_faces = non_triangular_faces
    )
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                       Assertion Helpers                           ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    test_ray_intersection(result, expected_hit, expected_distance, expected_point; atol=1e-10)

Test ray intersection results with expected values.

# Arguments
- `result`: RayTriangleIntersectionResult or RayShapeIntersectionResult
- `expected_hit`: Expected hit status
- `expected_distance`: Expected distance (if hit)
- `expected_point`: Expected intersection point (if hit)
- `atol`: Absolute tolerance for floating point comparisons
"""
function test_ray_intersection(result, expected_hit, expected_distance, expected_point; atol=1e-10)
    @test result.hit == expected_hit
    if expected_hit
        @test result.distance ≈ expected_distance atol=atol
        @test result.point ≈ expected_point atol=atol
    end
end

"""
    @test_approx_eq_atol(actual, expected, atol)

Test approximate equality with absolute tolerance.
Convenience macro for common pattern `@test a ≈ b atol=tol`.
"""
macro test_approx_eq_atol(actual, expected, atol)
    quote
        @test $(esc(actual)) ≈ $(esc(expected)) atol=$(esc(atol))
    end
end

# Default tolerance for geometric calculations
const DEFAULT_ATOL = 1e-10
