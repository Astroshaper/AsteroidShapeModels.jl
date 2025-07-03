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
    intersect_ray_shape(ray::Ray, shape::ShapeModel) -> RayShapeIntersectionResult

Perform ray-shape intersection test using BVH acceleration when available.
Uses the Möller–Trumbore algorithm for ray-triangle mesh intersection.

# Arguments
- `ray`: Ray
- `shape`: Shape model

# Returns
- `RayShapeIntersectionResult` object containing the intersection test result

# Notes
This function automatically builds BVH if not already present for better performance.
To pre-build BVH, use the `load_shape_obj` function with `with_bvh=true`.
For example:
```julia
shape = load_shape_obj("path/to/shape.obj"; scale=1000, with_bvh=true)

# For an existing `ShapeModel` object:
build_bvh!(shape)
```
"""
function intersect_ray_shape(ray::Ray, shape::ShapeModel)::RayShapeIntersectionResult
    # Create single-element arrays for the input ray
    origins    = reshape(ray.origin, 3, 1)
    directions = reshape(ray.direction, 3, 1)
    
    # Use batch processing function
    results = intersect_ray_shape(shape, origins, directions)
    
    # Return the single result
    return results[1]
end

"""
    intersect_ray_shape(shape::ShapeModel, origins::AbstractMatrix{<:Real}, directions::AbstractMatrix{<:Real}) -> Vector{RayShapeIntersectionResult}

Perform batch ray-shape intersection tests using the same interface as `ImplicitBVH.traverse_rays`.

# Arguments
- `shape`      : Shape model with BVH
- `origins`    : 3×N matrix where each column is a ray origin
- `directions` : 3×N matrix where each column is a ray direction

# Returns
- Vector of `RayShapeIntersectionResult` objects, one for each input ray

# Notes
This function provides a convenient interface that matches `ImplicitBVH.traverse_rays` parameters.
The BVH is automatically built if not already present.

# Example
```julia
# Create ray data
n_rays = 100
origins = rand(3, n_rays) .* 1000  # Random origins
directions = normalize.(eachcol(rand(3, n_rays) .- 0.5))  # Random directions

# Convert directions back to matrix
directions = hcat(directions...)

# Perform batch intersection
results = intersect_ray_shape(shape, origins, directions)
```
"""
function intersect_ray_shape(shape::ShapeModel, origins::AbstractMatrix{<:Real}, directions::AbstractMatrix{<:Real})::Vector{RayShapeIntersectionResult}
    # Build BVH if not already built
    isnothing(shape.bvh) && build_bvh!(shape)
    
    # Validate input dimensions
    size(origins, 1) == 3 || throw(ArgumentError("`origins` must have 3 rows."))
    size(directions, 1) == 3 || throw(ArgumentError("`directions` must have 3 rows."))
    size(origins, 2) == size(directions, 2) || throw(ArgumentError("`origins` and `directions` must have the same number of columns."))

    # Perform batch traversal
    traversal = ImplicitBVH.traverse_rays(shape.bvh, origins, directions)
    
    # Initialize intersection results
    n_rays = size(origins, 2)
    results = fill(NO_INTERSECTION_RAY_SHAPE, n_rays)
    min_distances = fill(Inf, n_rays)  # For tracking closest hit for each ray
    
    # Process all contacts
    for contact in traversal.contacts
        face_idx = Int(contact[1])
        ray_idx = Int(contact[2])
        
        # Create Ray object for intersection test
        ray_origin = SVector{3, Float64}(origins[:, ray_idx])
        ray_direction = SVector{3, Float64}(directions[:, ray_idx])
        ray = Ray(ray_origin, ray_direction)
        
        result = intersect_ray_triangle(ray, shape, face_idx)
        
        if result.hit && result.distance < min_distances[ray_idx]
            min_distances[ray_idx] = result.distance
            results[ray_idx] = RayShapeIntersectionResult(true, result.distance, result.point, face_idx)
        end
    end
    
    return results
end

"""
    intersect_ray_shape(rays::AbstractVector{Ray}, shape::ShapeModel) -> Vector{RayShapeIntersectionResult}
    intersect_ray_shape(rays::AbstractMatrix{Ray}, shape::ShapeModel) -> Matrix{RayShapeIntersectionResult}

Perform batch ray-shape intersection tests for multiple rays.

# Arguments
- `rays`  : Vector or Matrix of Ray objects
- `shape` : Shape model

# Returns
- If `rays` is a Vector: Vector of `RayShapeIntersectionResult` objects
- If `rays` is a Matrix: Matrix of `RayShapeIntersectionResult` objects with the same size

# Notes
The output shape matches the input shape, making it convenient for processing
structured ray grids while preserving their spatial arrangement.

# Example
```julia
# Vector of rays - returns Vector
rays_vec = [Ray(SA[x, 0.0, 1000.0], SA[0.0, 0.0, -1.0]) for x in -500:100:500]
results_vec = intersect_ray_shape(rays_vec, shape)  # Vector

# Matrix of rays - returns Matrix  
rays_mat = [Ray(SA[x, y, 1000.0], SA[0.0, 0.0, -1.0]) for x in -500:100:500, y in -500:100:500]
results_mat = intersect_ray_shape(rays_mat, shape)  # Matrix with same size

# Process matrix results while preserving structure
for i in 1:size(results_mat, 1), j in 1:size(results_mat, 2)
    if results_mat[i, j].hit
        println("Ray at (\$i, \$j) hit face \$(results_mat[i, j].face_index)")
    end
end
```
"""
function intersect_ray_shape(rays::AbstractVector{Ray}, shape::ShapeModel)::Vector{RayShapeIntersectionResult}
    n_rays = length(rays)
    
    # Convert rays to matrix format for ImplicitBVH.traverse_rays
    origins = zeros(Float64, 3, n_rays)
    directions = zeros(Float64, 3, n_rays)
    
    for (i, ray) in enumerate(rays)
        origins[:, i] = ray.origin
        directions[:, i] = ray.direction
    end
    
    # Delegate to matrix-based function
    return intersect_ray_shape(shape, origins, directions)
end

function intersect_ray_shape(rays::AbstractMatrix{Ray}, shape::ShapeModel)::Matrix{RayShapeIntersectionResult}
    # Flatten rays-matrix to vector for batch processing
    rays_flat = vec(rays)
    
    # Get results as vector
    results_flat = intersect_ray_shape(rays_flat, shape)
    
    # Reshape to match input shape
    return reshape(results_flat, size(rays))
end
