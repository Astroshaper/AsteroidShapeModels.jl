#=
    obj_io.jl

This file provides functions for loading 3D shape models from Wavefront OBJ files.
OBJ is a widely used file format for 3D geometry that stores vertex positions and
face connectivity information. This module handles the parsing and conversion of
OBJ data into the internal representation used by AsteroidShapeModels.jl.

Exported Functions:
- `load_obj`: Load vertices and faces from an OBJ file
- `isobj`: Check if a file has the OBJ file extension
=#

"""
    isobj(filepath::String) -> Bool

Check if a file has the OBJ file extension.

# Arguments
- `filepath::String`: Path to the file to check

# Returns
- `Bool`: `true` if the file has `.obj` extension, `false` otherwise

# Examples
```julia
isobj("model.obj")    # Returns true
isobj("model.stl")    # Returns false
isobj("model.OBJ")    # Returns false (case-sensitive)
```
"""
function isobj(filepath)
    base, ext = splitext(filepath)
    return ext == ".obj"
end

"""
    load_obj(shapepath::String; scale=1) -> nodes, faces

Load a 3D shape model from an OBJ file.

# Arguments
- `shapepath::String`: Path to the OBJ file

# Keyword Arguments
- `scale::Real=1`: Scale factor to apply to all vertex coordinates. For example, use `scale=1000` to convert from kilometers to meters

# Returns
- `nodes::Vector{SVector{3,Float64}}`: Array of vertex positions
- `faces::Vector{SVector{3,Int64}}`: Array of triangular face definitions (1-indexed vertex indices)

# Examples
```julia
# Load shape model in meters
nodes, faces = load_obj("asteroid.obj")

# Load shape model and convert from km to m
nodes, faces = load_obj("asteroid_km.obj", scale=1000)

# Get the number of nodes and faces
num_nodes = length(nodes)
num_faces = length(faces)
println("Loaded model with $num_nodes vertices and $num_faces faces.")

# Access individual nodes and faces
first_node = nodes[1]  # SVector{3, Float64}
first_face = faces[1]  # SVector{3, Int} with node indices
```

# Notes
This function uses the FileIO/MeshIO packages to load OBJ files.
Only triangular faces are supported.
"""
function load_obj(shapepath::String; scale=1)
    mesh = load(shapepath)
    nodes = Vector{SVector{3, Float64}}(GeometryBasics.coordinates(mesh))
    faces = [SVector{3,Int}(convert.(Int, face)) for face in GeometryBasics.faces(mesh)]

    nodes *= scale  # if scale is 1000, converted [km] to [m]

    return nodes, faces
end
