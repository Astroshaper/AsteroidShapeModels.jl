"""
    struct VisibleFacet

Index of an interfacing facet and its view factor

# Fields
- `id` : Index of the interfacing facet
- `f`  : View factor from facet i to j
- `d`  : Distance from facet i to j
- `d̂`  : Normal vector from facet i to j
"""
struct VisibleFacet
    id::Int64
    f ::Float64
    d ::Float64
    d̂ ::SVector{3, Float64}
end

"""
    ShapeModel

A polyhedral shape model of an asteroid.

# Fields
- `nodes`         : Vector of node positions
- `faces`         : Vector of vertex indices of faces
- `face_centers`  : Center position of each face
- `face_normals`  : Normal vector of each face
- `face_areas`    : Area of of each face
- `visiblefacets` : Vector of vector of `VisibleFacet`
"""
mutable struct ShapeModel
    nodes        ::Vector{SVector{3, Float64}}
    faces        ::Vector{SVector{3, Int}}

    face_centers ::Vector{SVector{3, Float64}}
    face_normals ::Vector{SVector{3, Float64}}
    face_areas   ::Vector{Float64}

    visiblefacets::Vector{Vector{VisibleFacet}}
end

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

function Base.show(io::IO, bbox::BoundingBox)
    print(io, "BoundingBox:\n")
    print(io, "    ∘ min_point = $(bbox.min_point)\n")
    print(io, "    ∘ max_point = $(bbox.max_point)\n")
end

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
