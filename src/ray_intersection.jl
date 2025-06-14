################################################################
#                           Raycast
################################################################

"""
    raycast(A, B, C, R) -> Bool

Perform ray-triangle intersection test using a simplified Möller–Trumbore algorithm.

# Arguments
- `A::StaticVector{3}`: 1st vertex of the triangle
- `B::StaticVector{3}`: 2nd vertex of the triangle
- `C::StaticVector{3}`: 3rd vertex of the triangle
- `R::StaticVector{3}`: Ray direction vector (from origin)

# Returns
- `Bool`: `true` if the ray intersects the triangle, `false` otherwise

# Algorithm
Uses the Möller–Trumbore ray-triangle intersection algorithm:
1. Computes edge vectors E1 = B - A, E2 = C - A
2. Calculates barycentric coordinates (u, v) and ray parameter t
3. Tests if intersection point lies within triangle bounds

# Notes
- Ray origin is assumed to be at (0, 0, 0)
- Returns true only if t > 0 (intersection in positive ray direction)
- Triangle vertices should be in counter-clockwise order for consistent results
"""
function raycast(A::StaticVector{3}, B::StaticVector{3}, C::StaticVector{3}, R::StaticVector{3})
    E1 = B - A
    E2 = C - A
    T  = - A

    P = R × E2
    Q = T × E1
    
    P_dot_E1 = P ⋅ E1
        
    u = (P ⋅ T)  / P_dot_E1
    v = (Q ⋅ R)  / P_dot_E1
    t = (Q ⋅ E2) / P_dot_E1

    return 0 ≤ u ≤ 1 && 0 ≤ v ≤ 1 && 0 ≤ u + v ≤ 1 && t > 0
end

"""
    raycast(A, B, C, R, O) -> Bool

Intersection detection between ray R and triangle ABC.
Use when the starting point of the ray is an arbitrary point `O`.
"""
raycast(A::StaticVector{3}, B::StaticVector{3}, C::StaticVector{3}, R::StaticVector{3}, O::StaticVector{3}) = raycast(A - O, B - O, C - O, R)

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
    
    # Intersection test in x-direction
    if abs(ray.direction[1]) < 1e-8
        if ray.origin[1] < bbox.min_point[1] || ray.origin[1] > bbox.max_point[1]
            return false
        end
    else
        t1 = (bbox.min_point[1] - ray.origin[1]) / ray.direction[1]
        t2 = (bbox.max_point[1] - ray.origin[1]) / ray.direction[1]
        
        t1, t2 = minmax(t1, t2)
        
        t_min = max(t_min, t1)
        t_max = min(t_max, t2)
        
        if t_min > t_max
            return false
        end
    end
    
    # Intersection test in y-direction
    if abs(ray.direction[2]) < 1e-8
        if ray.origin[2] < bbox.min_point[2] || ray.origin[2] > bbox.max_point[2]
            return false
        end
    else
        t1 = (bbox.min_point[2] - ray.origin[2]) / ray.direction[2]
        t2 = (bbox.max_point[2] - ray.origin[2]) / ray.direction[2]
        
        if t1 > t2
            t1, t2 = t2, t1
        end
        
        t_min = max(t_min, t1)
        t_max = min(t_max, t2)
        
        if t_min > t_max
            return false
        end
    end
    
    # Intersection test in z-direction
    if abs(ray.direction[3]) < 1e-8
        if ray.origin[3] < bbox.min_point[3] || ray.origin[3] > bbox.max_point[3]
            return false
        end
    else
        t1 = (bbox.min_point[3] - ray.origin[3]) / ray.direction[3]
        t2 = (bbox.max_point[3] - ray.origin[3]) / ray.direction[3]
        
        if t1 > t2
            t1, t2 = t2, t1
        end
        
        t_min = max(t_min, t1)
        t_max = min(t_max, t2)
        
        if t_min > t_max
            return false
        end
    end
    
    return t_max >= 0.0
end

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
    if !intersect_ray_bounding_box(ray, bbox)
        return NO_INTERSECTION_RAY_SHAPE
    end
    
    min_distance   = Inf
    closest_point  = SVector{3, Float64}(0.0, 0.0, 0.0)
    hit_face_index = 0
    hit_any        = false
    
    for (i, face) in enumerate(shape.faces)
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
