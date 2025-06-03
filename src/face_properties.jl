################################################################
#                      Face properties
################################################################

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
