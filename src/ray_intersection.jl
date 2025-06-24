#=
    ray_intersection.jl

This file implements ray-shape intersection algorithms for asteroid shape models.
It includes the Möller-Trumbore algorithm for ray-triangle intersection,
bounding box calculations for acceleration, and functions for testing
intersections between rays and complete shape models.

Exported Functions:
- `compute_bounding_box`: Compute the axis-aligned bounding box of a shape
- `intersect_ray_bounding_box`: Test ray-bounding box intersection
- `intersect_ray_triangle`: Test ray-triangle intersection using Möller-Trumbore algorithm
- `intersect_ray_shape`: Find the closest intersection between a ray and a shape model
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Bounding Box Operations                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    compute_bounding_box(shape::ShapeModel) -> BoundingBox

Compute the bounding box of a shape model.

# Arguments
- `shape`: Shape model

# Returns
- `BoundingBox` object representing the bounding box
"""
function compute_bounding_box(shape::ShapeModel)
    isempty(shape.nodes) && error("Shape has no nodes")
    
    min_point = SVector{3}(minimum(node[i] for node in shape.nodes) for i in 1:3)
    max_point = SVector{3}(maximum(node[i] for node in shape.nodes) for i in 1:3)
    
    return BoundingBox(min_point, max_point)
end

"""
    intersect_ray_bounding_box(ray::Ray, bbox::BoundingBox) -> Bool

Perform intersection test between a ray and a bounding box.

# Arguments
- `ray`: Ray
- `bbox`: Bounding box

# Returns
- `true` if intersection occurs, `false` otherwise
"""
function intersect_ray_bounding_box(ray::Ray, bbox::BoundingBox)
    t_min = -Inf
    t_max = Inf
    
    # Intersection test for each dimension (x, y, z)
    for dim in 1:3
        if abs(ray.direction[dim]) < 1e-8
            # Ray is parallel to this axis
            if ray.origin[dim] < bbox.min_point[dim] || ray.origin[dim] > bbox.max_point[dim]
                return false
            end
        else
            # Ray intersects this axis
            t1 = (bbox.min_point[dim] - ray.origin[dim]) / ray.direction[dim]
            t2 = (bbox.max_point[dim] - ray.origin[dim]) / ray.direction[dim]
            
            t1, t2 = minmax(t1, t2)
            
            t_min = max(t_min, t1)
            t_max = min(t_max, t2)
            
            if t_min > t_max
                return false
            end
        end
    end
    
    return t_max >= 0.0
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║               Ray-Triangle Intersection (Möller-Trumbore)         ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    intersect_ray_triangle(ray::Ray, v1::AbstractVector{<:Real}, v2::AbstractVector{<:Real}, v3::AbstractVector{<:Real}) -> RayTriangleIntersectionResult

Perform ray-triangle intersection test using the Möller–Trumbore algorithm.

# Arguments
- `ray`: Ray
- `v1`: Triangle vertex 1
- `v2`: Triangle vertex 2
- `v3`: Triangle vertex 3

# Returns
- `RayTriangleIntersectionResult` object containing the intersection test result
"""
function intersect_ray_triangle(ray::Ray, v1::AbstractVector{<:Real}, v2::AbstractVector{<:Real}, v3::AbstractVector{<:Real})
    e1 = v2 - v1
    e2 = v3 - v1
    
    p = cross(ray.direction, e2)
    
    det = dot(e1, p)
    
    if abs(det) < 1e-8
        return NO_INTERSECTION_RAY_TRIANGLE
    end
    
    inv_det = 1.0 / det
    
    t = ray.origin - v1
    
    u = dot(t, p) * inv_det
    
    if u < 0.0 || u > 1.0
        return NO_INTERSECTION_RAY_TRIANGLE
    end
    
    q = cross(t, e1)
    
    v = dot(ray.direction, q) * inv_det
    
    if v < 0.0 || u + v > 1.0
        return NO_INTERSECTION_RAY_TRIANGLE
    end
    
    distance = dot(e2, q) * inv_det
    
    if distance > 0.0
        point = ray.origin + distance * ray.direction
        return RayTriangleIntersectionResult(true, distance, point)
    end
    
    return NO_INTERSECTION_RAY_TRIANGLE
end

"""
    intersect_ray_triangle(ray::Ray, shape::ShapeModel, face_id::Integer) -> RayTriangleIntersectionResult

Perform ray-triangle intersection test for a specific face in a shape model.

# Arguments
- `ray`: Ray
- `shape`: Shape model containing the triangle
- `face_id`: Index of the face to test

# Returns
- `RayTriangleIntersectionResult` object containing the intersection test result

# Notes
This is a convenience function that delegates to the more general `intersect_ray_triangle` with nodes and faces.
"""
@inline function intersect_ray_triangle(ray::Ray, shape::ShapeModel, face_id::Integer)
    return intersect_ray_triangle(ray, shape.nodes, shape.faces, face_id)
end

"""
    intersect_ray_triangle(ray::Ray, nodes::AbstractVector, faces::AbstractVector, face_id::Integer) -> RayTriangleIntersectionResult

Perform ray-triangle intersection test for a specific face given nodes and faces arrays.

# Arguments
- `ray`: Ray
- `nodes`: Array of node positions
- `faces`: Array of face definitions (each face is an array of node indices)
- `face_id`: Index of the face to test

# Returns
- `RayTriangleIntersectionResult` object containing the intersection test result
"""
@inline function intersect_ray_triangle(ray::Ray, nodes::AbstractVector, faces::AbstractVector, face_id::Integer)
    face = faces[face_id]
    v1, v2, v3 = get_face_vertices(nodes, face)
    return intersect_ray_triangle(ray, v1, v2, v3)
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    Ray-Shape Model Intersection                   ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    intersect_ray_shape(ray::Ray, shape::ShapeModel, bbox::BoundingBox) -> RayShapeIntersectionResult

Perform accelerated ray-shape intersection test using bounding box optimization.
Uses the Möller–Trumbore algorithm for ray-triangle mesh intersection.

# Arguments
- `ray`: Ray
- `shape`: Shape model
- `bbox`: Bounding box of the shape model

# Returns
- `RayShapeIntersectionResult` object containing the intersection test result
"""
function intersect_ray_shape(ray::Ray, shape::ShapeModel, bbox::BoundingBox)
    # Use BVH if available, otherwise fall back to bounding box check
    if isnothing(shape.bvh)
        if !intersect_ray_bounding_box(ray, bbox)
            return NO_INTERSECTION_RAY_SHAPE
        end
        # Linear search through all faces
        return _intersect_ray_shape_linear(ray, shape)
    else
        # BVH-accelerated intersection
        return _intersect_ray_shape_bvh(ray, shape)
    end
end

# Linear search implementation (original algorithm)
function _intersect_ray_shape_linear(ray::Ray, shape::ShapeModel)
    min_distance   = Inf
    closest_point  = SVector{3, Float64}(0.0, 0.0, 0.0)
    hit_face_index = 0
    hit_any        = false
    
    for i in eachindex(shape.faces)
        # Backface culling
        n̂ = shape.face_normals[i]
        dot(ray.direction, n̂) ≥ 0 && continue

        # Visibility check from observer
        c = shape.face_centers[i]
        dot(c - ray.origin, n̂) ≥ 0 && continue
        
        result = intersect_ray_triangle(ray, shape, i)
        
        if result.hit && result.distance < min_distance
            min_distance   = result.distance
            closest_point  = result.point
            hit_face_index = i
            hit_any        = true
        end
    end
    
    if hit_any
        return RayShapeIntersectionResult(true, min_distance, closest_point, hit_face_index)
    else
        return NO_INTERSECTION_RAY_SHAPE
    end
end

# BVH-accelerated implementation
function _intersect_ray_shape_bvh(ray::Ray, shape::ShapeModel)
    min_distance   = Inf
    closest_point  = SVector{3, Float64}(0.0, 0.0, 0.0)
    hit_face_index = 0
    hit_any        = false
    
    # Use ImplicitBVH to traverse and find candidate triangles
    # Note: traverse_rays expects arrays, so we create single-element arrays
    origins = reshape([ray.origin[1], ray.origin[2], ray.origin[3]], 3, 1)
    directions = reshape([ray.direction[1], ray.direction[2], ray.direction[3]], 3, 1)
    
    traversal = ImplicitBVH.traverse_rays(shape.bvh, origins, directions)
    
    # Extract contacts from traversal
    for contact in traversal.contacts
        i = Int(contact[1])  # The first element is the leaf/face index
        face = shape.faces[i]
        
        # Backface culling
        n̂ = shape.face_normals[i]
        dot(ray.direction, n̂) ≥ 0 && continue

        # Visibility check from observer
        c = shape.face_centers[i]
        dot(c - ray.origin, n̂) ≥ 0 && continue
        
        v1 = shape.nodes[face[1]]
        v2 = shape.nodes[face[2]]
        v3 = shape.nodes[face[3]]
        
        result = intersect_ray_triangle(ray, v1, v2, v3)
        
        if result.hit && result.distance < min_distance
            min_distance   = result.distance
            closest_point  = result.point
            hit_face_index = i
            hit_any        = true
        end
    end
    
    if hit_any
        return RayShapeIntersectionResult(true, min_distance, closest_point, hit_face_index)
    else
        return NO_INTERSECTION_RAY_SHAPE
    end
end
