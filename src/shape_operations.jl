#=
    shape_operations.jl

This file provides high-level functions for shape model operations including
loading shape models from various sources, computing geometric properties
such as volume and radii, and converting between different representations.

Exported Functions:
- `load_shape_obj`    : Load a shape model from an OBJ file
- `load_shape_grid`   : Convert a regular grid to a shape model
- `grid_to_faces`     : Convert grid data to triangular faces
- `polyhedron_volume` : Calculate the volume of a polyhedron
- `equivalent_radius` : Calculate the radius of an equivalent sphere
- `maximum_radius`    : Find the maximum distance from origin
- `minimum_radius`    : Find the minimum distance from origin
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                         Shape Loading                             ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    load_shape_obj(shapepath;
        scale = 1.0,
        with_face_visibility = false,
        with_bvh = false,
    ) -> ShapeModel

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
shape = load_shape_obj("path/to/shape.obj")

# Load with scaling and visibility computation
shape = load_shape_obj("path/to/shape_km.obj"; scale=1000)

# Load with face visibility graph and BVH construction
shape = load_shape_obj("path/to/shape_km.obj"; scale=1000, with_face_visibility=true, with_bvh=true)
```

See also: [`load_shape_grid`](@ref), [`load_obj`](@ref)
"""
function load_shape_obj(shapepath;
    scale = 1.0,
    with_face_visibility = false,
    with_bvh = false,
)::ShapeModel

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
    load_shape_grid(xs, ys, zs;
        scale = 1.0,
        with_face_visibility = false,
        with_bvh = false,
    ) -> ShapeModel

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
shape = load_shape_grid(xs, ys, zs; scale=1000, with_face_visibility=true)

# With BVH acceleration (experimental)
shape = load_shape_grid(xs, ys, zs; with_bvh=true)
```

See also: [`load_shape_obj`](@ref), [`grid_to_faces`](@ref)
"""
function load_shape_grid(xs::AbstractVector, ys::AbstractVector, zs::AbstractMatrix;
    scale = 1.0,
    with_face_visibility = false,
    with_bvh = false,
)::ShapeModel

    nodes, faces = grid_to_faces(xs, ys, zs)
    nodes .*= scale

    return ShapeModel(nodes, faces; with_face_visibility, with_bvh)
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                       Staggered Lattice                           ║
# ╚═══════════════════════════════════════════════════════════════════╝

# Triangulate the strip between two x-sorted node rows (indices into `xy`), appending the
# triangles to `faces` with counterclockwise orientation (+z normals; `bottom` has the
# smaller y). At each step the pointer whose next diagonal is shorter advances, which keeps
# the triangles as close to equilateral as the rows allow.
function _triangulate_rows!(faces, xy, bottom::Vector{Int}, top::Vector{Int})
    i, j = 1, 1
    while i < length(bottom) || j < length(top)
        advance_bottom = if j == length(top)
            true
        elseif i == length(bottom)
            false
        else
            norm(xy[bottom[i+1]] - xy[top[j]]) ≤ norm(xy[top[j+1]] - xy[bottom[i]])
        end
        if advance_bottom
            push!(faces, SA[bottom[i], bottom[i+1], top[j]])
            i += 1
        else
            push!(faces, SA[bottom[i], top[j+1], top[j]])
            j += 1
        end
    end
    return nothing
end

# Nodes (2D) and faces of a staggered lattice on the unit square with `n` intervals in x:
# `m = round(2n/√3)` rows spaced `1/m` (near-equilateral triangles of side `1/n`), every
# other row shifted by half a pitch, with extra nodes at x = 0 and 1 on shifted rows so the
# lattice fills the square exactly (half-width right triangles at the left/right edges).
function _staggered_lattice_faces(n::Integer)
    m = max(1, round(Int, 2n / √3))  # number of rows (intervals) in y

    xy   = SVector{2, Float64}[]
    rows = Vector{Int}[]
    for j in 0:m
        y = j / m
        row = Int[]
        if iseven(j)
            for k in 0:n
                push!(xy, SA[k / n, y]); push!(row, length(xy))
            end
        else
            push!(xy, SA[0.0, y]); push!(row, length(xy))
            for k in 0:n-1
                push!(xy, SA[(2k + 1) / 2n, y]); push!(row, length(xy))
            end
            push!(xy, SA[1.0, y]); push!(row, length(xy))
        end
        push!(rows, row)
    end

    faces = SVector{3, Int}[]
    for j in 1:m
        _triangulate_rows!(faces, xy, rows[j], rows[j+1])
    end

    return xy, faces
end

"""
    load_shape_lattice(z, n::Integer;
        scale = 1.0,
        with_face_visibility = false,
        with_bvh = false,
    ) -> ShapeModel
    load_shape_lattice(n::Integer; ...) -> ShapeModel   # flat (z ≡ 0)

Create a shape model on a staggered lattice covering the unit square `[0,1] × [0,1]`,
with the height function `z(x, y)` evaluated at every node.

Unlike the regular grid of [`load_shape_grid`](@ref), whose cells split into right
isosceles triangles with all diagonals in the same direction, the staggered lattice
consists of near-equilateral triangles: `n` intervals in x, `m = round(2n/√3)` rows
spaced `1/m ≈ (√3/2)/n`, with every other row shifted by half a pitch. Shifted rows
carry extra nodes at `x = 0` and `x = 1`, so the lattice fills the unit square exactly,
at the cost of half-width right triangles along the left and right edges. The lattice
has `m(2n + 1)` faces with +z-oriented normals, like `load_shape_grid`.

Use it for statistical surface patches (roughness models), where the elongated
triangles and uniform diagonal direction of a regular grid could bias
direction-dependent quantities.

# Arguments
- `z` : Height function `(x, y) -> z`, evaluated at the lattice nodes. Omit for a flat patch.
- `n::Integer` : Number of intervals in the x-direction (≥ 1)

# Keyword Arguments
- `scale::Real=1.0`                  : Scale factor to apply to all coordinates
- `with_face_visibility::Bool=false` : Whether to build the face-to-face visibility graph
- `with_bvh::Bool=false`             : Whether to build BVH for ray tracing

# Returns
- `ShapeModel`: Shape model with computed geometric properties

# Example
```julia
# A crater patch on a staggered lattice (cf. create_shape_crater(...; lattice=:staggered))
r, h = 0.4, 0.1
shape = load_shape_lattice((x, y) -> AsteroidShapeModels.concave_spherical_segment_depth(r, h, 0.5, 0.5, x, y), 16)

# A flat staggered patch
flat = load_shape_lattice(16)
```

See also: [`load_shape_grid`](@ref), [`create_shape_crater`](@ref)
"""
function load_shape_lattice(z, n::Integer;
    scale = 1.0,
    with_face_visibility = false,
    with_bvh = false,
)::ShapeModel
    n ≥ 1 || throw(ArgumentError("n must be at least 1, got $n"))

    xy, faces = _staggered_lattice_faces(n)
    nodes = [SVector(p[1], p[2], float(z(p[1], p[2]))) for p in xy]
    nodes .*= scale

    return ShapeModel(nodes, faces; with_face_visibility, with_bvh)
end

load_shape_lattice(n::Integer; kwargs...) = load_shape_lattice((x, y) -> 0.0, n; kwargs...)

"""
    refine_midpoint(nodes, faces) -> (new_nodes, new_faces)

Refine a triangular mesh by splitting every triangle into four at its edge midpoints
(1 → 4 subdivision). Edge midpoints are shared between adjacent faces, so the refined
mesh has `length(nodes) + n_edges` nodes and `4 length(faces)` faces, and the face
orientation is preserved. Internal function (not exported); the basis for the random
midpoint displacement of fractal surfaces.

# Arguments
- `nodes` : Vector of node positions (3-vectors)
- `faces` : Vector of triangular face definitions (vertex indices)

# Returns
- `new_nodes::Vector{SVector{3, Float64}}` : Refined node positions
- `new_faces::Vector{SVector{3, Int}}`     : Refined face definitions
"""
function refine_midpoint(nodes::AbstractVector{<:StaticVector{3}}, faces::AbstractVector{<:StaticVector{3}})
    new_nodes = SVector{3, Float64}[SVector{3, Float64}(v) for v in nodes]
    midpoints = Dict{Tuple{Int, Int}, Int}()

    midpoint(i, j) = get!(midpoints, minmax(i, j)) do
        push!(new_nodes, (new_nodes[i] + new_nodes[j]) / 2)
        length(new_nodes)
    end

    new_faces = SVector{3, Int}[]
    for face in faces
        a, b, c = face
        ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
        push!(new_faces, SA[a, ab, ca], SA[ab, b, bc], SA[ca, bc, c], SA[ab, bc, ca])
    end

    return new_nodes, new_faces
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
