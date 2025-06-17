# ShapeModel type definition - depends on FaceVisibilityGraph

"""
    ShapeModel

A polyhedral shape model of an asteroid.

# Fields
- `nodes`         : Vector of node positions
- `faces`         : Vector of vertex indices of faces
- `face_centers`  : Center position of each face
- `face_normals`  : Normal vector of each face
- `face_areas`    : Area of of each face
- `face_visibility_graph` : `FaceVisibilityGraph` for efficient visibility queries
"""
mutable struct ShapeModel
    nodes        ::Vector{SVector{3, Float64}}
    faces        ::Vector{SVector{3, Int}}

    face_centers ::Vector{SVector{3, Float64}}
    face_normals ::Vector{SVector{3, Float64}}
    face_areas   ::Vector{Float64}

    face_visibility_graph::Union{FaceVisibilityGraph, Nothing}
end

"""
    ShapeModel(nodes::Vector{<:StaticVector{3}}, faces::Vector{<:StaticVector{3}}; find_visible_facets=false) -> ShapeModel

Construct a ShapeModel from nodes and faces, automatically computing face properties.

# Arguments
- `nodes`: Vector of vertex positions
- `faces`: Vector of triangular face definitions (vertex indices)

# Keyword Arguments
- `with_face_visibility::Bool=false`: Whether to compute face-to-face visibility

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
```
"""
function ShapeModel(nodes::Vector{<:StaticVector{3}}, faces::Vector{<:StaticVector{3}}; with_face_visibility=false)
    face_centers = [face_center(nodes[face]) for face in faces]
    face_normals = [face_normal(nodes[face]) for face in faces]
    face_areas   = [face_area(nodes[face])   for face in faces]
    
    # Initialize with no visibility graph
    face_visibility_graph = nothing
    
    shape = ShapeModel(nodes, faces, face_centers, face_normals, face_areas, face_visibility_graph)
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
