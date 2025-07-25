#=
    shape_operations.jl

This file provides high-level functions for shape model operations including
loading shape models from various sources, computing geometric properties
such as volume and radii, and converting between different representations.

Exported Functions:
- `load_shape_obj`: Load a shape model from an OBJ file
- `load_shape_grid`: Convert a regular grid to a shape model
- `grid_to_faces`: Convert grid data to triangular faces
- `polyhedron_volume`: Calculate the volume of a polyhedron
- `equivalent_radius`: Calculate the radius of an equivalent sphere
- `maximum_radius`: Find the maximum distance from origin
- `minimum_radius`: Find the minimum distance from origin
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                         Shape Loading                             ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    load_shape_obj(shapepath; scale=1.0, with_face_visibility=false, with_bvh=false) -> ShapeModel

Load a shape model from a Wavefront OBJ file.

# Arguments
- `shapepath::String`: Path to a Wavefront OBJ file

# Keyword Arguments
- `scale::Real=1.0`                  : Scale factor for node coordinates (e.g., 1000 to convert km to m)
- `with_face_visibility::Bool=false` : Whether to build face-to-face visibility graph for illumination and thermophysical modeling
- `with_bvh::Bool=false`             : Whether to build BVH for ray tracing (required for `intersect_ray_shape` and `apply_eclipse_shadowing!`)

# Returns
- `ShapeModel`: Loaded shape model with computed geometric properties

# Examples
```julia
# Load a shape model
shape = load_shape_obj("asteroid.obj")

# Load with scaling and visibility computation
shape = load_shape_obj("asteroid_km.obj"; scale=1000, with_face_visibility=true)

# Load with all features for comprehensive analysis
shape = load_shape_obj("asteroid.obj"; scale=1000, with_face_visibility=true, with_bvh=true)
```

See also: [`load_shape_grid`](@ref), [`load_obj`](@ref)
"""
function load_shape_obj(shapepath; scale=1.0, with_face_visibility=false, with_bvh=false)
    nodes, faces = load_obj(shapepath; scale)
    return ShapeModel(nodes, faces; with_face_visibility, with_bvh)
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                        Grid Operations                            ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    grid_to_faces(xs::AbstractVector, ys::AbstractVector, zs::AbstractMatrix) -> nodes, faces

Convert a regular grid (x, y) and corresponding z-coordinates to triangular facets.

    | ⧹| ⧹| ⧹|
j+1 ・--C--D--・
    |⧹ |⧹ |⧹ |
    | ⧹| ⧹| ⧹|
j   ・--A--B--・
    |⧹ |⧹ |⧹ |
       i  i+1

# Arguments
- `xs::AbstractVector`: x-coordinates of grid points (should be sorted)
- `ys::AbstractVector`: y-coordinates of grid points (should be sorted)
- `zs::AbstractMatrix`: z-coordinates of grid points where `zs[i,j]` corresponds to `(xs[i], ys[j])`

# Returns
- `nodes::Vector{SVector{3,Float64}}`: Array of 3D vertex positions
- `faces::Vector{SVector{3,Int}}`: Array of triangular face definitions (1-indexed)

# Notes
Each grid cell is divided into two triangles. The vertices are numbered
sequentially row by row (j varies slowest).

# Examples
```julia
# Create a simple 3x3 grid
xs = [0.0, 1.0, 2.0]
ys = [0.0, 1.0, 2.0]
zs = [i + j for i in 1:3, j in 1:3]  # z = x + y
nodes, faces = grid_to_faces(xs, ys, zs)
```

See also: [`load_shape_grid`](@ref)
"""
function grid_to_faces(xs::AbstractVector, ys::AbstractVector, zs::AbstractMatrix)
    nodes = SVector{3, Float64}[]
    faces = SVector{3, Int}[]

    for j in eachindex(ys)
        for i in eachindex(xs)
            push!(nodes, @SVector [xs[i], ys[j], zs[i, j]])
        end
    end

    for j in eachindex(ys)[begin:end-1]
        for i in eachindex(xs)[begin:end-1]
            ABC = @SVector [i + (j-1)*length(xs), i+1 + (j-1)*length(xs), i + j*length(xs)]
            DCB = @SVector [i+1 + j*length(xs), i + j*length(xs), i+1 + (j-1)*length(xs)]

            push!(faces, ABC, DCB)
        end
    end

    return nodes, faces
end

"""
    load_shape_grid(xs, ys, zs; scale=1.0, with_face_visibility=false, with_bvh=false) -> ShapeModel

Convert a regular grid (x, y) with z-values to a shape model.

# Arguments
- `xs::AbstractVector`: x-coordinates of grid points
- `ys::AbstractVector`: y-coordinates of grid points
- `zs::AbstractMatrix`: z-coordinates of grid points where `zs[i,j]` corresponds to `(xs[i], ys[j])`

# Keyword Arguments
- `scale::Real=1.0`                  : Scale factor to apply to all coordinates
- `with_face_visibility::Bool=false` : Whether to build face-to-face visibility graph for illumination and thermophysical modeling
- `with_bvh::Bool=false`             : Whether to build BVH for ray tracing (required for `intersect_ray_shape` and `apply_eclipse_shadowing!`)

# Returns
- `ShapeModel`: Shape model with computed geometric properties

# Examples
```julia
# Create a shape from elevation data
xs = range(-10, 10, length=50)
ys = range(-10, 10, length=50)
zs = [exp(-(x^2 + y^2)/10) for x in xs, y in ys]  # Gaussian surface
shape = load_shape_grid(xs, ys, zs)

# With scaling and visibility
shape = load_shape_grid(xs, ys, zs, scale=1000, with_face_visibility=true)

# With BVH acceleration (experimental)
shape = load_shape_grid(xs, ys, zs; with_bvh=true)
```

See also: [`load_shape_obj`](@ref), [`grid_to_faces`](@ref)
"""
function load_shape_grid(xs::AbstractVector, ys::AbstractVector, zs::AbstractMatrix; scale=1.0, with_face_visibility=false, with_bvh=false)
    nodes, faces = grid_to_faces(xs, ys, zs)
    nodes .*= scale
    
    return ShapeModel(nodes, faces; with_face_visibility, with_bvh)
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Geometric Properties                         ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    polyhedron_volume(nodes, faces) -> Float64
    polyhedron_volume(shape::ShapeModel) -> Float64

Calculate the volume of a polyhedron using the divergence theorem.

# Arguments
- `nodes`: Array of vertex positions
- `faces`: Array of triangular face definitions (vertex indices)
- `shape::ShapeModel`: A shape model containing nodes and faces

# Returns
- `Float64`: Volume of the polyhedron

# Notes
The volume is computed using the formula: `V = (1/6) * Σ (A × B) · C`
where A, B, C are the vertices of each triangular face.
The shape must be a closed polyhedron with consistently oriented faces.

# Examples
```julia
# Unit cube
nodes = [SA[0,0,0], SA[1,0,0], SA[1,1,0], SA[0,1,0],
         SA[0,0,1], SA[1,0,1], SA[1,1,1], SA[0,1,1]]
faces = [SA[1,2,3], SA[1,3,4], ...]  # Define all 12 triangular faces
vol = polyhedron_volume(nodes, faces)  # Returns 1.0
```
"""
function polyhedron_volume(nodes, faces)
    volume = 0.
    for face in faces
        A, B, C = nodes[face]
        volume += (A × B) ⋅ C / 6
    end
    volume
end

polyhedron_volume(shape::ShapeModel) = polyhedron_volume(shape.nodes, shape.faces)

"""
    equivalent_radius(VOLUME::Real) -> Float64
    equivalent_radius(shape::ShapeModel) -> Float64

Calculate the radius of a sphere with the same volume as the given volume or shape.

# Arguments
- `VOLUME::Real`: Volume of the object
- `shape::ShapeModel`: A shape model to calculate volume from

# Returns
- `Float64`: Radius of the equivalent sphere

# Notes
The equivalent radius is calculated as: `r = (3V/4π)^(1/3)`

# Examples
```julia
# Sphere with radius 2
volume = 4π/3 * 2^3
r_eq = equivalent_radius(volume)  # Returns 2.0

# From shape model
shape = load_shape_obj("asteroid.obj")
r_eq = equivalent_radius(shape)
```
"""
equivalent_radius(VOLUME::Real) = (3VOLUME/4π)^(1/3)
equivalent_radius(shape::ShapeModel) = equivalent_radius(polyhedron_volume(shape))

"""
    maximum_radius(nodes) -> Float64
    maximum_radius(shape::ShapeModel) -> Float64

Calculate the maximum distance from the origin to any vertex.

# Arguments
- `nodes`: Array of vertex positions
- `shape::ShapeModel`: A shape model containing nodes

# Returns
- `Float64`: Maximum distance from origin to any vertex

# Notes
This represents the radius of the smallest sphere centered at the origin
that contains all vertices of the shape.

# Examples
```julia
nodes = [SA[1,0,0], SA[0,2,0], SA[0,0,3]]
r_max = maximum_radius(nodes)  # Returns 3.0
```
"""
maximum_radius(nodes) = maximum(norm, nodes)
maximum_radius(shape::ShapeModel) = maximum_radius(shape.nodes)

"""
    minimum_radius(nodes) -> Float64
    minimum_radius(shape::ShapeModel) -> Float64

Calculate the minimum distance from the origin to any vertex.

# Arguments
- `nodes`: Array of vertex positions
- `shape::ShapeModel`: A shape model containing nodes

# Returns
- `Float64`: Minimum distance from origin to any vertex

# Notes
This represents the radius of the largest sphere centered at the origin
that fits entirely inside the convex hull of the vertices.

# Examples
```julia
nodes = [SA[1,0,0], SA[0,2,0], SA[0,0,3]]
r_min = minimum_radius(nodes)  # Returns 1.0
```
"""
minimum_radius(nodes) = minimum(norm, nodes)
minimum_radius(shape::ShapeModel) = minimum_radius(shape.nodes)

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    Face Vertex Extraction (ShapeModel)            ║
# ╚═══════════════════════════════════════════════════════════════════╝

# Implementation of get_face_nodes for ShapeModel (declared in face_properties.jl)
"""
    get_face_nodes(shape::ShapeModel, face_idx::Integer) -> (v1, v2, v3)

Extract three nodes of a triangular face from a shape model.

# Arguments
- `shape`    : Shape model containing nodes and faces
- `face_idx` : Index of the face in the shape model

# Returns
- Tuple of three nodes (v1, v2, v3)

# Examples
```julia
# Assuming shape is a loaded ShapeModel
v1, v2, v3 = get_face_nodes(shape, 1)  # Get nodes of the first face
```

See also: [`get_face_nodes(nodes, faces, face_idx)`](@ref)
"""
@inline function AsteroidShapeModels.get_face_nodes(shape::ShapeModel, face_idx::Integer)
    return get_face_nodes(shape.nodes, shape.faces, face_idx)
end
