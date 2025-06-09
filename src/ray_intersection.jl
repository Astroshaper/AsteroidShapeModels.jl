"""
    compute_bounding_box(shape::ShapeModel) -> BoundingBox

Compute the bounding box of a shape model.

# Arguments
- `shape`: Shape model

# Returns
- `BoundingBox` object representing the bounding box
"""
function compute_bounding_box(shape::ShapeModel)
    min_x, min_y, min_z =  Inf,  Inf,  Inf
    max_x, max_y, max_z = -Inf, -Inf, -Inf
    
    for node in shape.nodes
        min_x = min(min_x, node[1])
        min_y = min(min_y, node[2])
        min_z = min(min_z, node[3])
        
        max_x = max(max_x, node[1])
        max_y = max(max_y, node[2])
        max_z = max(max_z, node[3])
    end
    
    min_point = SVector{3, Float64}(min_x, min_y, min_z)
    max_point = SVector{3, Float64}(max_x, max_y, max_z)
    
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
        
        if t1 > t2
            t1, t2 = t2, t1
        end
        
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
    closest_point  = @SVector zeros(3)
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
