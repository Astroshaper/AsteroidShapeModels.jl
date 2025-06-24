#=
    shape_model.jl

Defines the core `ShapeModel` type for representing polyhedral asteroid shapes.
This type encapsulates:
- Vertex positions (nodes)
- Face connectivity (triangular faces)
- Precomputed geometric properties (centers, normals, areas)
- Optional face-to-face visibility graph for thermal and radiative calculations
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                        Type Definition                            ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    ShapeModel

A polyhedral shape model of an asteroid.

# Fields
- `nodes`                 : Vector of node positions
- `faces`                 : Vector of vertex indices of faces
- `face_centers`          : Center position of each face
- `face_normals`          : Normal vector of each face
- `face_areas`            : Area of of each face
- `face_visibility_graph` : `FaceVisibilityGraph` for efficient visibility queries
- `bvh`                   : Bounding Volume Hierarchy for accelerated ray tracing
"""
mutable struct ShapeModel
    nodes        ::Vector{SVector{3, Float64}}
    faces        ::Vector{SVector{3, Int}}

    face_centers ::Vector{SVector{3, Float64}}
    face_normals ::Vector{SVector{3, Float64}}
    face_areas   ::Vector{Float64}

    face_visibility_graph ::Union{Nothing, FaceVisibilityGraph}
    bvh                   ::Union{Nothing, ImplicitBVH.BVH}
end

"""
    ShapeModel(nodes::Vector{<:StaticVector{3}}, faces::Vector{<:StaticVector{3}}; with_face_visibility=false, with_bvh=false) -> ShapeModel

Construct a ShapeModel from nodes and faces, automatically computing face properties.

# Arguments
- `nodes`: Vector of vertex positions
- `faces`: Vector of triangular face definitions (vertex indices)

# Keyword Arguments
- `with_face_visibility::Bool=false`: Whether to compute face-to-face visibility graph
- `with_bvh::Bool=false`: Whether to build BVH for accelerated ray tracing (experimental)

# Returns
- `ShapeModel`: Shape model with computed face centers, normals, areas, and optionally face visibility graph

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
function ShapeModel(nodes::Vector{<:StaticVector{3}}, faces::Vector{<:StaticVector{3}}; with_face_visibility=false, with_bvh=false)
    face_centers = [face_center(nodes[face]) for face in faces]
    face_normals = [face_normal(nodes[face]) for face in faces]
    face_areas   = [face_area(nodes[face])   for face in faces]
    
    # Initialize with no visibility graph
    face_visibility_graph = nothing
    
    # Initialize with no BVH
    bvh = nothing
    
    shape = ShapeModel(nodes, faces, face_centers, face_normals, face_areas, face_visibility_graph, bvh)
    
    # Build BVH for ray tracing acceleration if requested
    with_bvh && build_bvh!(shape)
    
    with_face_visibility && build_face_visibility_graph!(shape)
    
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

Build a Bounding Volume Hierarchy (BVH) for the shape model to accelerate ray tracing.
The BVH is stored in the `shape.bvh` field.

# Arguments
- `shape`: The shape model to build the BVH for

# Notes
This function creates bounding boxes for each triangular face and constructs
an implicit BVH tree structure for efficient ray-shape intersection queries.
"""
function build_bvh!(shape::ShapeModel)
    # Create bounding boxes for each face
    bboxes = ImplicitBVH.BBox{Float64}[]
    
    for face in shape.faces
        v1 = shape.nodes[face[1]]
        v2 = shape.nodes[face[2]]
        v3 = shape.nodes[face[3]]
        
        # Find min and max coordinates for the triangle
        min_point = SVector{3}(
            min(v1[1], v2[1], v3[1]),
            min(v1[2], v2[2], v3[2]),
            min(v1[3], v2[3], v3[3]),
        )
        max_point = SVector{3}(
            max(v1[1], v2[1], v3[1]),
            max(v1[2], v2[2], v3[2]),
            max(v1[3], v2[3], v3[3]),
        )
        
        push!(bboxes, ImplicitBVH.BBox(min_point, max_point))
    end
    
    # Build the BVH
    shape.bvh = ImplicitBVH.BVH(bboxes, ImplicitBVH.BBox{Float64}, UInt32)
end
