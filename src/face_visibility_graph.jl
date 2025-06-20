#=
    face_visibility_graph.jl

This file implements the `FaceVisibilityGraph` data structure, which stores face-to-face
visibility relationships in a Compressed Sparse Row (CSR) format. This efficient
representation is used for computing view factors, illumination conditions, and
radiative heat transfer between faces of an asteroid shape model.

Exported Types:
- `FaceVisibilityGraph`: CSR-style data structure for face visibility

Exported Functions:
- `get_visible_face_indices`: Get indices of faces visible from a given face
- `get_view_factors`: Get view factors from a face to its visible faces
- `get_visible_face_distances`: Get distances to visible faces
- `get_visible_face_directions`: Get unit direction vectors to visible faces
- `get_visible_face_data`: Get all visibility data for a specific visible face
- `num_visible_faces`: Get number of faces visible from a given face
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                        Type Definition                            ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    FaceVisibilityGraph

Efficient visible face graph structure using CSR (Compressed Sparse Row) format.
Provides better memory efficiency and cache locality compared to adjacency list format.

# Fields
- `row_ptr`: Start index of visible face data for each face (length: nfaces + 1)
- `col_idx`: Indices of visible faces (column indices in CSR format)
- `view_factors`: View factors for each visible face pair
- `distances`: Distances between each visible face pair
- `directions`: Unit direction vectors between each visible face pair
- `nfaces`: Total number of faces
- `nnz`: Number of non-zero elements (total number of visible face pairs)

# Example
If face 1 is visible to faces 2,3 and face 2 is visible to faces 1,3,4:
- row_ptr = [1, 3, 6, 7]
- col_idx = [2, 3, 1, 3, 4, ...]
"""
struct FaceVisibilityGraph
    row_ptr::Vector{Int}
    col_idx::Vector{Int}
    view_factors::Vector{Float64}
    distances::Vector{Float64}
    directions::Vector{SVector{3, Float64}}
    nfaces::Int
    nnz::Int
    
    function FaceVisibilityGraph(
        row_ptr::Vector{Int}, 
        col_idx::Vector{Int},
        view_factors::Vector{Float64},
        distances::Vector{Float64},
        directions::Vector{SVector{3, Float64}}
    )
        nfaces = length(row_ptr) - 1
        nnz = length(col_idx)
        
        # Validity checks
        @assert row_ptr[1] == 1 "row_ptr must start with 1"
        @assert row_ptr[end] == nnz + 1 "row_ptr[end] must equal nnz + 1"
        @assert length(view_factors) == nnz "view_factors length must equal nnz"
        @assert length(distances) == nnz "distances length must equal nnz"
        @assert length(directions) == nnz "directions length must equal nnz"
        @assert all(1 .<= col_idx .<= nfaces) "col_idx must be in range [1, nfaces]"
        
        new(row_ptr, col_idx, view_factors, distances, directions, nfaces, nnz)
    end
end

"""
    FaceVisibilityGraph() -> FaceVisibilityGraph

Create an empty FaceVisibilityGraph.
"""
FaceVisibilityGraph() = FaceVisibilityGraph(Int[1], Int[], Float64[], Float64[], SVector{3, Float64}[])

"""
    FaceVisibilityGraph(nfaces::Int) -> FaceVisibilityGraph

Create an empty FaceVisibilityGraph with the specified number of faces.
"""
function FaceVisibilityGraph(nfaces::Int)
    row_ptr = ones(Int, nfaces + 1)
    FaceVisibilityGraph(row_ptr, Int[], Float64[], Float64[], SVector{3, Float64}[])
end

"""
    Base.show(io::IO, graph::FaceVisibilityGraph)

Display FaceVisibilityGraph.
"""
function Base.show(io::IO, graph::FaceVisibilityGraph)
    print(io, "FaceVisibilityGraph:\n")
    print(io, "  Number of faces: $(graph.nfaces)\n")
    print(io, "  Number of visible pairs: $(graph.nnz)\n")
    if graph.nnz > 0
        avg_visible = graph.nnz / graph.nfaces
        print(io, "  Average visible faces per face: $(round(avg_visible, digits=2))\n")
    end
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Data Access Methods                          ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    get_visible_face_indices(graph::FaceVisibilityGraph, face_id::Int) -> SubArray

Get indices of faces visible from the specified face.
"""
function get_visible_face_indices(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    start_idx = graph.row_ptr[face_id]
    end_idx = graph.row_ptr[face_id + 1] - 1
    return @view graph.col_idx[start_idx:end_idx]
end

"""
    get_view_factors(graph::FaceVisibilityGraph, face_id::Int) -> SubArray

Get view factors for the specified face.
"""
function get_view_factors(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    start_idx = graph.row_ptr[face_id]
    end_idx = graph.row_ptr[face_id + 1] - 1
    return @view graph.view_factors[start_idx:end_idx]
end

"""
    get_visible_face_distances(graph::FaceVisibilityGraph, face_id::Int) -> SubArray

Get distances to visible faces from the specified face.
"""
function get_visible_face_distances(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    start_idx = graph.row_ptr[face_id]
    end_idx = graph.row_ptr[face_id + 1] - 1
    return @view graph.distances[start_idx:end_idx]
end

"""
    get_visible_face_directions(graph::FaceVisibilityGraph, face_id::Int) -> SubArray

Get direction vectors to visible faces from the specified face.
"""
function get_visible_face_directions(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    start_idx = graph.row_ptr[face_id]
    end_idx = graph.row_ptr[face_id + 1] - 1
    return @view graph.directions[start_idx:end_idx]
end

"""
    get_visible_face_data(graph::FaceVisibilityGraph, face_id::Int, idx::Int)

Get the idx-th visible face data for the specified face.
"""
function get_visible_face_data(graph::FaceVisibilityGraph, face_id::Int, idx::Int)
    visible_faces = get_visible_face_indices(graph, face_id)
    @boundscheck 1 <= idx <= length(visible_faces) || throw(BoundsError())
    
    base_idx = graph.row_ptr[face_id] + idx - 1
    return (
        id = graph.col_idx[base_idx],
        f = graph.view_factors[base_idx],
        d = graph.distances[base_idx],
        d̂ = graph.directions[base_idx]
    )
end

"""
    num_visible_faces(graph::FaceVisibilityGraph, face_id::Int) -> Int

Get the number of visible faces for the specified face.
"""
function num_visible_faces(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    return graph.row_ptr[face_id + 1] - graph.row_ptr[face_id]
end
