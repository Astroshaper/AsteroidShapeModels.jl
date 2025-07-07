#=
    types.jl

Core type definitions for `AsteroidShapeModels.jl`.
This file contains fundamental data structures used throughout the package:
- `VisibleFace`: Internal type for temporary visibility data storage
- `Ray`: Represents a ray in 3D space for intersection tests
- `RayTriangleIntersectionResult`: Result of ray-triangle intersection test
- `RayShapeIntersectionResult`: Result of ray-shape intersection test
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                          Core Types                               ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    struct VisibleFace

Internal type for storing face-to-face visibility data during graph construction.
This type is used temporarily in `build_face_visibility_graph!` before converting
to the CSR format `FaceVisibilityGraph`.

# Fields
- `face_idx`    : Index of the interfacing face
- `view_factor` : View factor from face i to j
- `distance`    : Distance from face i to j
- `direction`   : Unit direction vector from face i to j

Note: This is an internal type and not exported.
"""
struct VisibleFace
    face_idx    ::Int64
    view_factor ::Float64
    distance    ::Float64
    direction   ::SVector{3, Float64}
end

"""
    Ray

Structure representing a ray in 3D space.

# Fields
- `origin`    : Ray origin point
- `direction` : Ray direction vector (normalized)
"""
struct Ray
    origin::SVector{3, Float64}
    direction::SVector{3, Float64}
    
    function Ray(origin::AbstractVector{<:Real}, direction::AbstractVector{<:Real})
        dir_normalized = normalize(direction)
        return new(SVector{3, Float64}(origin), SVector{3, Float64}(dir_normalized))
    end
end

"""
    Base.show(io::IO, ray::Ray)

Custom display method for Ray objects.

Displays origin and direction vectors.
"""
function Base.show(io::IO, ray::Ray)
    print(io, "Ray:\n")
    print(io, "    ∘ origin    = $(ray.origin)\n")
    print(io, "    ∘ direction = $(ray.direction)\n")
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Intersection Result Types                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    RayTriangleIntersectionResult

Structure representing the result of ray-triangle intersection test.

# Fields
- `hit`      : true if intersection exists, false otherwise
- `distance` : Distance from ray origin to intersection point
- `point`    : Coordinates of the intersection point
"""
struct RayTriangleIntersectionResult
    hit::Bool
    distance::Float64
    point::SVector{3, Float64}
end

const NO_INTERSECTION_RAY_TRIANGLE = RayTriangleIntersectionResult(false, NaN, SVector(NaN, NaN, NaN))

"""
    Base.show(io::IO, result::RayTriangleIntersectionResult)

Custom display method for `RayTriangleIntersectionResult` objects.

Displays hit status and intersection details if hit occurred.
"""
function Base.show(io::IO, result::RayTriangleIntersectionResult)
    if result.hit
        print(io, "Ray-Triangle Intersection:\n")
        print(io, "    ∘ hit      = $(result.hit)\n")
        print(io, "    ∘ distance = $(result.distance)\n")
        print(io, "    ∘ point    = $(result.point)\n")
    else
        print(io, "Ray-Triangle Intersection:\n")
        print(io, "    ∘ hit = $(result.hit)\n")
    end
end

"""
    RayShapeIntersectionResult

Structure representing the result of ray-shape intersection test.

# Fields
- `hit`      : true if intersection exists, false otherwise
- `distance` : Distance from ray origin to intersection point
- `point`    : Coordinates of the intersection point
- `face_idx` : Index of the intersected face
"""
struct RayShapeIntersectionResult
    hit::Bool
    distance::Float64
    point::SVector{3, Float64}
    face_idx::Int
end

const NO_INTERSECTION_RAY_SHAPE = RayShapeIntersectionResult(false, NaN, SVector(NaN, NaN, NaN), 0)

"""
    Base.show(io::IO, result::RayShapeIntersectionResult)

Custom display method for `RayShapeIntersectionResult` objects.

Displays hit status and intersection details including face index if hit occurred.
"""
function Base.show(io::IO, result::RayShapeIntersectionResult)
    if result.hit
        print(io, "Ray-Shape Intersection:\n")
        print(io, "    ∘ hit      = $(result.hit)\n")
        print(io, "    ∘ distance = $(result.distance)\n")
        print(io, "    ∘ point    = $(result.point)\n")
        print(io, "    ∘ face_idx = $(result.face_idx)\n")
    else
        print(io, "Ray-Shape Intersection:\n")
        print(io, "    ∘ hit = $(result.hit)\n")
    end
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                     Visibility Graph Type                         ║
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
