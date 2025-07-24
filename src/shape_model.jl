#=
    shape_model.jl

Defines the core shape model types for representing asteroid shapes.

Type hierarchy:
- `AbstractShapeModel` : Abstract base type for all shape models
    - `ShapeModel`             : Concrete type for polyhedral shapes (triangular mesh)
    - `HierarchicalShapeModel` : Concrete type for multi-scale shape with surface roughness models (defined in hierarchical_shape_model.jl)

The ShapeModel encapsulates:
- Vertex positions (nodes)
- Face connectivity (triangular faces)
- Precomputed geometric properties (centers, normals, areas)
- (Optional) Face-to-face visibility graph for thermophysical simulations
- (Optional) Maximum elevation angles of surrounding terrain for each face
- (Optional) Bounding volume hierarchy (BVH) for accelerated ray tracing
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Abstract Type Definition                     ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    AbstractShapeModel

Abstract base type for all shape models in AsteroidShapeModels.jl.

Concrete subtypes include:
- `ShapeModel`             : Standard polyhedral shape model using triangular mesh representation
- `HierarchicalShapeModel` : Multi-scale shape model with localized surface roughness models
"""
abstract type AbstractShapeModel end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                        Type Definition                            ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    ShapeModel <: AbstractShapeModel

A polyhedral shape model of an asteroid using triangular mesh representation.

# Fields
- `nodes`                 : Vector of node positions
- `faces`                 : Vector of vertex indices of faces
- `face_centers`          : Center position of each face
- `face_normals`          : Normal vector of each face
- `face_areas`            : Area of each face
- `face_visibility_graph` : `FaceVisibilityGraph` for efficient visibility queries
- `face_max_elevations`   : Maximum elevation angle of the surrounding terrain from each face [rad]
- `bvh`                   : Bounding Volume Hierarchy for accelerated ray tracing

See also: [`AbstractShapeModel`](@ref), [`HierarchicalShapeModel`](@ref)
"""
mutable struct ShapeModel <: AbstractShapeModel
    nodes        ::Vector{SVector{3, Float64}}
    faces        ::Vector{SVector{3, Int}}

    face_centers ::Vector{SVector{3, Float64}}
    face_normals ::Vector{SVector{3, Float64}}
    face_areas   ::Vector{Float64}

    face_visibility_graph ::Union{Nothing, FaceVisibilityGraph}
    face_max_elevations   ::Union{Nothing, Vector{Float64}}
    bvh                   ::Union{Nothing, ImplicitBVH.BVH}
end

"""
    ShapeModel(
        nodes::Vector{<:StaticVector{3}}, faces::Vector{<:StaticVector{3}};
        with_face_visibility=false, with_bvh=false,
    ) -> ShapeModel

Construct a ShapeModel from nodes and faces, automatically computing face properties.

# Arguments
- `nodes`: Vector of vertex positions
- `faces`: Vector of triangular face definitions (vertex indices)

# Keyword Arguments
- `with_face_visibility::Bool=false`: Whether to compute face-to-face visibility graph and face_max_elevations
- `with_bvh::Bool=false`: Whether to build BVH for accelerated ray tracing (experimental)

# Returns
- `ShapeModel`: Shape model with computed face centers, normals, areas, and optionally face visibility graph, face_max_elevations, and BVH

# Examples
```julia
# Create a simple tetrahedron
nodes = [SA[0,0,0], SA[1,0,0], SA[0,1,0], SA[0,0,1]]
faces = [SA[1,2,3], SA[1,2,4], SA[1,3,4], SA[2,3,4]]
shape = ShapeModel(nodes, faces)

# Create with visibility computation
shape = ShapeModel(nodes, faces, with_face_visibility=true)

# Create with BVH acceleration (experimental)
shape = ShapeModel(nodes, faces, with_bvh=true)
```
"""
function ShapeModel(
    nodes::Vector{<:StaticVector{3}}, faces::Vector{<:StaticVector{3}};
    with_face_visibility=false, with_bvh=false,
)
    face_centers = [face_center(nodes[face]) for face in faces]
    face_normals = [face_normal(nodes[face]) for face in faces]
    face_areas   = [face_area(nodes[face])   for face in faces]
    
    # Initialize ShapeModel without face_visibilitygraph, face_max_elevations, or bvh
    shape = ShapeModel(nodes, faces, face_centers, face_normals, face_areas, nothing, nothing, nothing)
    
    # Build face-to-face visibility graph and face_max_elevations if requested
    if with_face_visibility
        build_face_visibility_graph!(shape)
        compute_face_max_elevations!(shape)
    end
    
    # Build BVH if requested
    with_bvh && build_bvh!(shape)
    
    return shape
end

"""
    Base.show(io::IO, shape::ShapeModel)

Custom display method for ShapeModel objects.

Displays:
- Number of nodes and faces
- Volume and equivalent radius
- Maximum and minimum radii
"""
function Base.show(io::IO, shape::ShapeModel)
    print(io, "Shape model\n")
    print(io, "-----------\n")
    print(io, "Number of nodes   : $(length(shape.nodes))\n")
    print(io, "Number of faces   : $(length(shape.faces))\n")
    print(io, "Volume            : $(polyhedron_volume(shape))\n")
    print(io, "Equivalent radius : $(equivalent_radius(shape))\n")
    print(io, "Maximum radius    : $(maximum_radius(shape))\n")
    print(io, "Minimum radius    : $(minimum_radius(shape))\n")
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    BVH Construction Functions                     ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    build_bvh!(shape::ShapeModel)

Build a Bounding Volume Hierarchy (BVH) for the shape model for ray tracing.
The BVH is stored in the `shape.bvh` field.

!!! note
    As of v0.4.0, BVH must be pre-built before calling `intersect_ray_shape`.
    Use either `with_bvh=true` when loading or call this function explicitly.

# Arguments
- `shape`: The shape model to build the BVH for

# Returns
- Nothing (modifies `shape` in-place)

# Performance
- Building time: O(n log n) where n is the number of faces
- Ray intersection speedup: ~50x compared to previous implementations

# When to use
- **Required** before calling `intersect_ray_shape` (as of v0.4.0)
- **Required** for `shape2` argument in `apply_eclipse_shadowing!` (as of v0.4.0)
- When loading a shape without `with_bvh=true`
- Alternative to `with_bvh=true` in `load_shape_obj` for existing shapes

# Example
```julia
# Load shape without BVH
shape = load_shape_obj("path/to/shape.obj"; scale=1000)

# Build BVH before ray intersection (required in v0.4.0)
build_bvh!(shape)

# Now ray intersection can be performed
ray = Ray(SA[1000.0, 0.0, 0.0], SA[-1.0, 0.0, 0.0])
result = intersect_ray_shape(ray, shape)

# Or load with BVH directly
shape = load_shape_obj("path/to/shape.obj"; scale=1000, with_bvh=true)
```

# Notes
This function creates bounding boxes for each triangular face and constructs
an implicit BVH tree structure for efficient ray-shape intersection queries.
The BVH uses the ImplicitBVH.jl package which provides cache-efficient traversal.

See also: [`load_shape_obj`](@ref) with `with_bvh=true`, [`intersect_ray_shape`](@ref), [`apply_eclipse_shadowing!`](@ref)
"""
function build_bvh!(shape::ShapeModel)
    # Create bounding boxes for each face
    bboxes = ImplicitBVH.BBox{Float64}[]
    
    for i in eachindex(shape.faces)
        vs = get_face_nodes(shape, i)  # (v1, v2, v3)
        push!(bboxes, ImplicitBVH.BBox(vs))
    end
    
    # Build the BVH
    shape.bvh = ImplicitBVH.BVH(bboxes, ImplicitBVH.BBox{Float64}, UInt32)
end
