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

"""
    ShapeModel(nodes::Vector{<:StaticVector{3}}, faces::Vector{<:StaticVector{3}}; find_visible_facets=false) -> ShapeModel

Construct a ShapeModel from nodes and faces, automatically computing face properties.

# Arguments
- `nodes`: Vector of vertex positions
- `faces`: Vector of triangular face definitions (vertex indices)

# Keyword Arguments
- `find_visible_facets::Bool=false`: Whether to compute face-to-face visibility

# Returns
- `ShapeModel`: Shape model with computed face centers, normals, areas, and optionally populated visiblefacets

# Examples
```julia
# Create a simple tetrahedron
nodes = [SA[0,0,0], SA[1,0,0], SA[0,1,0], SA[0,0,1]]
faces = [SA[1,2,3], SA[1,2,4], SA[1,3,4], SA[2,3,4]]
shape = ShapeModel(nodes, faces)

# Create with visibility computation
shape = ShapeModel(nodes, faces, find_visible_facets=true)
```
"""
function ShapeModel(nodes::Vector{<:StaticVector{3}}, faces::Vector{<:StaticVector{3}}; find_visible_facets=false)
    face_centers = [face_center(nodes[face]) for face in faces]
    face_normals = [face_normal(nodes[face]) for face in faces]
    face_areas   = [face_area(nodes[face])   for face in faces]
    visiblefacets = [VisibleFacet[] for _ in faces]
    
    shape = ShapeModel(nodes, faces, face_centers, face_normals, face_areas, visiblefacets)
    find_visible_facets && find_visiblefacets!(shape)
    
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
