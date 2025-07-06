#=
    ray_intersection.jl

This file implements ray-shape intersection algorithms for asteroid shape models.
It includes the Möller-Trumbore algorithm for ray-triangle intersection with
BVH (Bounding Volume Hierarchy) acceleration for efficient computation.

Key Features:
- Ray-triangle intersection using the Möller-Trumbore algorithm
- BVH-accelerated ray-shape intersection (via `ImplicitBVH.jl`)
- Batch ray processing for vectors and matrices of rays
- No backface culling (triangles are hit from both sides)

Exported Functions:
- `intersect_ray_triangle`: Test ray-triangle intersection using Möller-Trumbore algorithm
- `intersect_ray_shape`: Find ray-shape intersections (single ray or batch processing)
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║               Ray-Triangle Intersection (Möller-Trumbore)         ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    intersect_ray_triangle(ray::Ray, v1::AbstractVector{<:Real}, v2::AbstractVector{<:Real}, v3::AbstractVector{<:Real}) -> RayTriangleIntersectionResult

Perform ray-triangle intersection test using the Möller–Trumbore algorithm.

# Arguments
- `ray`: Ray with origin and direction
- `v1`: Triangle vertex 1
- `v2`: Triangle vertex 2
- `v3`: Triangle vertex 3

# Returns
- `RayTriangleIntersectionResult` object containing the intersection test result

# Algorithm Details
This implementation has the following characteristics:
- **No backface culling**: Triangles are hit from both sides (front and back)
- **Forward rays only**: Only intersections in the ray direction are detected (distance > 0)
- **No self-intersection**: Rays starting exactly on the triangle surface typically miss due to numerical precision

# Example
```julia
# Ray from above hits triangle on XY plane
ray = Ray(SA[0.5, 0.5, 1.0], SA[0.0, 0.0, -1.0])
v1, v2, v3 = SA[0.0, 0.0, 0.0], SA[1.0, 0.0, 0.0], SA[0.0, 1.0, 0.0]
result = intersect_ray_triangle(ray, v1, v2, v3)
# result.hit == true, result.distance ≈ 1.0

# Ray from below also hits (no backface culling)
ray_below = Ray(SA[0.5, 0.5, -1.0], SA[0.0, 0.0, 1.0])
result = intersect_ray_triangle(ray_below, v1, v2, v3)
# result.hit == true

# Ray pointing away misses (backward intersection rejected)
ray_away = Ray(SA[0.5, 0.5, 1.0], SA[0.0, 0.0, 1.0])
result = intersect_ray_triangle(ray_away, v1, v2, v3)
# result.hit == false
```
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
    intersect_ray_triangle(ray::Ray, shape::ShapeModel, face_idx::Integer) -> RayTriangleIntersectionResult

Perform ray-triangle intersection test for a specific face in a shape model.

# Arguments
- `ray`      : Ray with origin and direction
- `shape`    : Shape model containing the triangle
- `face_idx` : Index of the face to test (1-based)

# Returns
- `RayTriangleIntersectionResult` object containing the intersection test result

# Algorithm Details
This function uses the same Möller-Trumbore algorithm as the base implementation:
- No backface culling (triangles are hit from both sides)
- Forward rays only (distance > 0)
- Inlined for performance

# Example
```julia
shape = load_shape_obj("asteroid.obj")
ray = Ray(SA[0.0, 0.0, 100.0], SA[0.0, 0.0, -1.0])
result = intersect_ray_triangle(ray, shape, 1)  # Test first face
```
"""
@inline function intersect_ray_triangle(ray::Ray, shape::ShapeModel, face_idx::Integer)
    return intersect_ray_triangle(ray, shape.nodes, shape.faces, face_idx)
end

"""
    intersect_ray_triangle(ray::Ray, nodes::AbstractVector, faces::AbstractVector, face_idx::Integer) -> RayTriangleIntersectionResult

Perform ray-triangle intersection test for a specific face given nodes and faces arrays.

# Arguments
- `ray`      : Ray with origin and direction
- `nodes`    : Array of node positions (3D vectors)
- `faces`    : Array of face definitions (each face is an array of 3 node indices)
- `face_idx` : Index of the face to test (1-based)

# Returns
- `RayTriangleIntersectionResult` object containing the intersection test result

# Algorithm Details
This function uses the same Möller-Trumbore algorithm as the base implementation:
- No backface culling (triangles are hit from both sides)
- Forward rays only (distance > 0)
- Inlined for performance

# Notes
This is a lower-level interface useful when working directly with node and face arrays
without a full `ShapeModel` structure.
"""
@inline function intersect_ray_triangle(ray::Ray, nodes::AbstractVector, faces::AbstractVector, face_idx::Integer)
    v1, v2, v3 = get_face_nodes(nodes, faces, face_idx)
    return intersect_ray_triangle(ray, v1, v2, v3)
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    Ray-Shape Model Intersection                   ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    intersect_ray_shape(shape::ShapeModel, origins::AbstractMatrix{<:Real}, directions::AbstractMatrix{<:Real}) -> Vector{RayShapeIntersectionResult}

Perform batch ray-shape intersection tests using the same interface as `ImplicitBVH.traverse_rays`.

This is the core implementation that all other `intersect_ray_shape` methods delegate to.

# Arguments
- `shape`      : Shape model (must have BVH built via `build_bvh!`)
- `origins`    : 3×N matrix where each column is a ray origin
- `directions` : 3×N matrix where each column is a ray direction

# Returns
- Vector of `RayShapeIntersectionResult` objects, one for each input ray

# Throws
- `ArgumentError` if BVH is not built. Call `build_bvh!(shape)` before using this function.

# Notes
- This function provides a convenient interface that matches `ImplicitBVH.traverse_rays` parameters
- BVH must be pre-built using `build_bvh!(shape)` or by creating the shape with `with_bvh=true`
- All rays are processed in a single batch for efficiency

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
    # Require BVH to be built before ray intersection
    isnothing(shape.bvh) && throw(ArgumentError("BVH must be built before ray intersection. Call build_bvh!(shape) first."))
    
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
    intersect_ray_shape(ray::Ray, shape::ShapeModel) -> RayShapeIntersectionResult

Perform ray-shape intersection test using BVH acceleration.
Uses the Möller–Trumbore algorithm for ray-triangle mesh intersection.

# Arguments
- `ray`   : Ray with origin and direction
- `shape` : Shape model (must have BVH built via `build_bvh!`)

# Returns
- `RayShapeIntersectionResult` object containing the intersection test result

# Throws
- `ArgumentError` if BVH is not built. Call `build_bvh!(shape)` before using this function.

# Notes
- BVH must be pre-built using `build_bvh!(shape)` or by creating the shape with `with_bvh=true`
- To pre-build BVH, use `load_shape_obj("path/to/shape.obj"; with_bvh=true)`
- Or for an existing `ShapeModel`: `build_bvh!(shape)`

# Example
```julia
ray = Ray(SA[0.0, 0.0, 1000.0], SA[0.0, 0.0, -1.0])
result = intersect_ray_shape(ray, shape)

if result.hit
    println("Hit face \$(result.face_idx) at distance \$(result.distance)")
end
```
"""
function intersect_ray_shape(ray::Ray, shape::ShapeModel)::RayShapeIntersectionResult
    # Convert single ray to matrix format and delegate to batch function
    origins = reshape(ray.origin, 3, 1)
    directions = reshape(ray.direction, 3, 1)
    
    # Call the batch function
    results = intersect_ray_shape(shape, origins, directions)
    
    # Return the single result
    return results[1]
end

"""
    intersect_ray_shape(rays::AbstractVector{Ray}, shape::ShapeModel) -> Vector{RayShapeIntersectionResult}

Perform batch ray-shape intersection tests for multiple rays.

# Arguments
- `rays`  : Vector of Ray objects
- `shape` : Shape model (must have BVH built via `build_bvh!`)

# Returns
- Vector of `RayShapeIntersectionResult` objects, one for each input ray

# Throws
- `ArgumentError` if BVH is not built. Call `build_bvh!(shape)` before using this function.

# Example
```julia
# Create a vector of rays
rays = [Ray(SA[x, 0.0, 1000.0], SA[0.0, 0.0, -1.0]) for x in -500:100:500]
results = intersect_ray_shape(rays, shape)

# Count hits
n_hits = count(r -> r.hit, results)
println("\$n_hits out of \$(length(rays)) rays hit the shape")
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

"""
    intersect_ray_shape(rays::AbstractMatrix{Ray}, shape::ShapeModel) -> Matrix{RayShapeIntersectionResult}

Perform batch ray-shape intersection tests for a matrix of rays.
The output shape matches the input shape, preserving spatial arrangement.

# Arguments
- `rays`  : Matrix of Ray objects
- `shape` : Shape model (must have BVH built via `build_bvh!`)

# Returns
- Matrix of `RayShapeIntersectionResult` objects with the same size as input

# Throws
- `ArgumentError` if BVH is not built. Call `build_bvh!(shape)` before using this function.

# Example
```julia
# Create a matrix of rays
rays = [Ray(SA[x, y, 1000.0], SA[0.0, 0.0, -1.0]) for x in -500:100:500, y in -500:100:500]
results = intersect_ray_shape(rays, shape)

# Process results while preserving grid structure
for i in 1:size(results, 1), j in 1:size(results, 2)
    if results[i, j].hit
        println("Ray at (\$i, \$j) hit at \$(results[i, j].point)")
    end
end
```
"""
function intersect_ray_shape(rays::AbstractMatrix{Ray}, shape::ShapeModel)::Matrix{RayShapeIntersectionResult}
    # Flatten rays-matrix to vector for batch processing
    rays_flat = vec(rays)
    
    # Get results as vector
    results_flat = intersect_ray_shape(rays_flat, shape)
    
    # Reshape to match input shape
    return reshape(results_flat, size(rays))
end
