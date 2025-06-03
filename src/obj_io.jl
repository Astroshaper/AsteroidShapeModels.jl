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
    loadobj(shapepath::String; scale=1, message=true) -> nodes, faces

Load a 3D shape model from an OBJ file.

# Arguments
- `shapepath::String`: Path to the OBJ file

# Keyword Arguments
- `scale::Real=1`: Scale factor to apply to all vertex coordinates. For example, use `scale=1000` to convert from kilometers to meters
- `message::Bool=true`: Whether to print loading information

# Returns
- `nodes::Vector{SVector{3,Float64}}`: Array of vertex positions
- `faces::Vector{SVector{3,Int64}}`: Array of triangular face definitions (1-indexed vertex indices)

# Examples
```julia
# Load shape model in meters
nodes, faces = loadobj("asteroid.obj")

# Load shape model and convert from km to m
nodes, faces = loadobj("asteroid_km.obj", scale=1000)

# Load without printing messages
nodes, faces = loadobj("asteroid.obj", message=false)
```

# Notes
This function uses the FileIO/MeshIO packages to load OBJ files.
Only triangular faces are supported.
"""
function loadobj(shapepath::String; scale=1, message=true)

    nodes = SVector{3,Float64}[]
    faces = SVector{3,Int64}[]

    mesh = load(shapepath)
    nodes = Vector{SVector{3, Float64}}(GeometryBasics.coordinates(mesh))
    faces = [SVector{3,Int}(convert.(Int, face)) for face in GeometryBasics.faces(mesh)]

    nodes *= scale  # if scale is 1000, converted [km] to [m]

    if message == true
        println("+-----------------------------+")
        println("|        Load OBJ file        |")
        println("+-----------------------------+")
        println(" Nodes: ", length(nodes))
        println(" Faces: ", length(faces))
    end

    return nodes, faces
end
