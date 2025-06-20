#=
    types.jl

Core type definitions for `AsteroidShapeModels.jl`.
This file contains fundamental data structures used throughout the package:
- `VisibleFace`: Internal type for temporary visibility data storage
- `Ray`: Represents a ray in 3D space for intersection tests
- `BoundingBox`: Axis-aligned bounding box for acceleration structures
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
- `id` : Index of the interfacing face
- `f`  : View factor from face i to j
- `d`  : Distance from face i to j
- `d̂`  : Normal vector from face i to j

Note: This is an internal type and not exported.
"""
struct VisibleFace
    id::Int64
    f ::Float64
    d ::Float64
    d̂ ::SVector{3, Float64}
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

"""
    BoundingBox

Structure representing a bounding box for shape models.

# Fields
- `min_point` : Minimum point of the bounding box (minimum x, y, z values)
- `max_point` : Maximum point of the bounding box (maximum x, y, z values)
"""
struct BoundingBox
    min_point::SVector{3, Float64}
    max_point::SVector{3, Float64}
end

"""
    Base.show(io::IO, bbox::BoundingBox)

Custom display method for BoundingBox objects.

Displays minimum and maximum corner points.
"""
function Base.show(io::IO, bbox::BoundingBox)
    print(io, "BoundingBox:\n")
    print(io, "    ∘ min_point = $(bbox.min_point)\n")
    print(io, "    ∘ max_point = $(bbox.max_point)\n")
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
- `hit`        : true if intersection exists, false otherwise
- `distance`   : Distance from ray origin to intersection point
- `point`      : Coordinates of the intersection point
- `face_index` : Index of the intersected face
"""
struct RayShapeIntersectionResult
    hit::Bool
    distance::Float64
    point::SVector{3, Float64}
    face_index::Int
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
        print(io, "    ∘ hit        = $(result.hit)\n")
        print(io, "    ∘ distance   = $(result.distance)\n")
        print(io, "    ∘ point      = $(result.point)\n")
        print(io, "    ∘ face_index = $(result.face_index)\n")
    else
        print(io, "Ray-Shape Intersection:\n")
        print(io, "    ∘ hit = $(result.hit)\n")
    end
end
