#=
    face_properties.jl

This file provides functions to calculate geometric properties of triangular faces,
including face centers, normal vectors, and areas. These properties are fundamental
for various computations in asteroid shape modeling, such as visibility analysis,
radiative heat transfer calculations, and illumination modeling.

Exported Functions:
- `face_center`: Calculate the center of a triangular face
- `face_normal`: Calculate the unit normal vector of a triangular face
- `face_area`: Calculate the area of a triangular face
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                         Face Center                               ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    face_center(vs::StaticVector{3, <:StaticVector{3}}) -> StaticVector{3}
    face_center(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) -> StaticVector{3}

Calculate the center (centroid) of a triangular face.

# Arguments
- `vs`: A static vector containing three vertices of the triangle
- `v1`, `v2`, `v3`: Three vertices of the triangle

# Returns
- `StaticVector{3}`: The center point of the triangle, computed as the arithmetic mean of the three vertices

# Examples
```julia
v1 = SA[1.0, 0.0, 0.0]
v2 = SA[0.0, 1.0, 0.0]
v3 = SA[0.0, 0.0, 1.0]
center = face_center(v1, v2, v3)  # Returns SA[1/3, 1/3, 1/3]
```
"""
face_center(vs::StaticVector{3, <:StaticVector{3}}) = face_center(vs...)
face_center(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) = (v1 + v2 + v3) / 3

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                         Face Normal                               ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    face_normal(vs::StaticVector{3, <:StaticVector{3}}) -> StaticVector{3}
    face_normal(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) -> StaticVector{3}

Calculate the unit normal vector of a triangular face.

# Arguments
- `vs`: A static vector containing three vertices of the triangle
- `v1`, `v2`, `v3`: Three vertices of the triangle in counter-clockwise order

# Returns
- `StaticVector{3}`: The unit normal vector pointing outward from the face (following right-hand rule)

# Notes
The normal direction follows the right-hand rule based on the vertex ordering.
For a counter-clockwise vertex ordering when viewed from outside, the normal points outward.

# Examples
```julia
v1 = SA[1.0, 0.0, 0.0]
v2 = SA[0.0, 1.0, 0.0]
v3 = SA[0.0, 0.0, 0.0]
normal = face_normal(v1, v2, v3)  # Returns SA[0.0, 0.0, 1.0]
```
"""
face_normal(vs::StaticVector{3, <:StaticVector{3}}) = face_normal(vs...)
face_normal(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) = normalize((v2 - v1) × (v3 - v2))

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                          Face Area                                ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    face_area(vs::StaticVector{3, <:StaticVector{3}}) -> Real
    face_area(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) -> Real

Calculate the area of a triangular face.

# Arguments
- `vs`: A static vector containing three vertices of the triangle
- `v1`, `v2`, `v3`: Three vertices of the triangle

# Returns
- `Real`: The area of the triangle

# Notes
The area is computed using the cross product formula: `area = ||(v2 - v1) × (v3 - v2)|| / 2`

# Examples
```julia
# Unit right triangle
v1 = SA[0.0, 0.0, 0.0]
v2 = SA[1.0, 0.0, 0.0]
v3 = SA[0.0, 1.0, 0.0]
area = face_area(v1, v2, v3)  # Returns 0.5
```
"""
face_area(vs::StaticVector{3, <:StaticVector{3}}) = face_area(vs...)
face_area(v1::StaticVector{3}, v2::StaticVector{3}, v3::StaticVector{3}) = norm((v2 - v1) × (v3 - v2)) / 2

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Face Vertex Extraction                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    get_face_vertices(nodes, face) -> (v1, v2, v3)

Extract three vertices of a triangular face from a node array.

# Arguments
- `nodes`: Array of node positions
- `face`: Array of three node indices defining the triangular face

# Returns
- Tuple of three vertices (v1, v2, v3)

# Examples
```julia
nodes = [SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0], SA[0.0, 1.0, 0.0]]
face = [1, 2, 3]
v1, v2, v3 = get_face_vertices(nodes, face)
```
"""
@inline function get_face_vertices(nodes::AbstractVector, face::AbstractVector{<:Integer})
    return nodes[face[1]], nodes[face[2]], nodes[face[3]]
end

# Forward declaration for ShapeModel version - implementation in shape_operations.jl
function get_face_vertices end
