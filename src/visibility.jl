#=
    visibility.jl

This file implements face-to-face visibility calculations for asteroid shape models.
It includes functions for computing view factors between faces, building visibility
graphs, and determining illumination conditions. These calculations are essential
for thermal modeling, radiative heat transfer analysis, and understanding the
surface energy balance of asteroids.

Exported Functions:
- `view_factor`: Calculate the view factor between two triangular faces
- `build_face_visibility_graph!`: Build the face-to-face visibility graph
- `isilluminated_pseudo_convex`: Check face illumination using pseudo-convex model
- `isilluminated_with_self_shadowing`: Check face illumination with self-shadowing
- `update_illumination_pseudo_convex!`: Batch update illumination (pseudo-convex)
- `update_illumination_with_self_shadowing!`: Batch update with self-shadowing
- `apply_eclipse_shadowing!`: Apply mutual shadowing from another shape
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    View Factor Calculations                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ) -> fᵢⱼ, dᵢⱼ, d̂ᵢⱼ

Calculate the view factor from face i to face j, assuming Lambertian emission.

# Arguments
- `cᵢ::StaticVector{3}`: Center position of face i
- `cⱼ::StaticVector{3}`: Center position of face j
- `n̂ᵢ::StaticVector{3}`: Unit normal vector of face i
- `n̂ⱼ::StaticVector{3}`: Unit normal vector of face j
- `aⱼ::Real`           : Area of face j

# Returns
- `fᵢⱼ::Real`: View factor from face i to face j
- `dᵢⱼ::Real`: Distance between face centers
- `d̂ᵢⱼ::StaticVector{3}`: Unit direction vector from face i to face j

# Notes
The view factor is calculated using the formula:
```
fᵢⱼ = (cosθᵢ * cosθⱼ) / (π * dᵢⱼ²) * aⱼ
```
where θᵢ and θⱼ are the angles between the line connecting the faces
and the respective normal vectors.

The view factor is automatically zero when:
- Face i is facing away from face j (cosθᵢ ≤ 0)
- Face j is facing away from face i (cosθⱼ ≤ 0)
- Both conditions ensure that only mutually visible faces have non-zero view factors

# Visual representation
```
(i)   fᵢⱼ   (j)
 △    -->    △
```
"""
function view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ)
    cᵢⱼ = cⱼ - cᵢ    # Vector from face i to face j
    dᵢⱼ = norm(cᵢⱼ)  # Distance between face centers
    d̂ᵢⱼ = cᵢⱼ / dᵢⱼ  # Unit direction vector from face i to face j (more efficient than normalize())

    # Calculate cosines of angles between normals and the line connecting faces
    # cosθᵢ: How much face i is oriented towards face j (positive if facing towards)
    # cosθⱼ: How much face j is oriented towards face i (negative dot product because we need the opposite direction)
    cosθᵢ = max(0.0,  n̂ᵢ ⋅ d̂ᵢⱼ)  # Zero if face i is facing away from face j
    cosθⱼ = max(0.0, -n̂ⱼ ⋅ d̂ᵢⱼ)  # Zero if face j is facing away from face i

    # View factor is zero if either face is not facing the other
    fᵢⱼ = cosθᵢ * cosθⱼ * aⱼ / (π * dᵢⱼ^2)
    return fᵢⱼ, dᵢⱼ, d̂ᵢⱼ
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                 Face Visibility Graph Construction                ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    build_face_visibility_graph!(shape::ShapeModel)

Build face-to-face visibility graph for the shape model.

This function computes which faces are visible from each face and stores the results
in a `FaceVisibilityGraph` structure using CSR (Compressed Sparse Row) format.

# Arguments
- `shape` : Shape model of an asteroid

# Algorithm
The implementation uses an optimized non-BVH algorithm with candidate filtering:
1. Pre-filter candidate faces based on normal orientations
2. Sort candidates by distance for efficient occlusion testing
3. Check visibility between face pairs using ray-triangle intersection
4. Store results in memory-efficient CSR format

# Performance Considerations
- BVH acceleration was found to be less efficient for face visibility pair searches
  compared to the optimized candidate filtering approach (slower ~0.5x)
- The non-BVH implementation with distance-based sorting provides better performance
  due to the specific nature of face-to-face visibility queries
- Distance-based sorting provides ~2x speedup over naive approaches

# Notes
- The visibility graph is stored in `shape.face_visibility_graph`
- This is a computationally intensive operation, especially for large models
- The resulting graph contains view factors, distances, and direction vectors
"""
function build_face_visibility_graph!(shape::ShapeModel)
    nodes = shape.nodes
    faces = shape.faces
    face_centers = shape.face_centers
    face_normals = shape.face_normals
    face_areas   = shape.face_areas
    
    # Accumulate temporary visible face data
    temp_visible = [Vector{VisibleFace}() for _ in faces]
    
    # Optimized non-BVH algorithm with candidate filtering
    # Loop structure:
    # - i: source face (viewpoint)
    # - j: candidate faces that might be visible from i (pre-filtered)
    # - k: potential occluding faces (from the same candidate list)
    for i in eachindex(faces)
        cᵢ = face_centers[i]
        n̂ᵢ = face_normals[i]
        aᵢ = face_areas[i]

        # Build list of candidate faces that are potentially visible from face i
        candidates = Int64[]   # Indices of candidate faces
        distances = Float64[]  # Distances to candidate faces from face i
        for j in eachindex(faces)
            i == j && continue
            cⱼ = face_centers[j]
            n̂ⱼ = face_normals[j]

            Rᵢⱼ = cⱼ - cᵢ
            if Rᵢⱼ ⋅ n̂ᵢ > 0 && Rᵢⱼ ⋅ n̂ⱼ < 0
                push!(candidates, j)
                push!(distances, norm(Rᵢⱼ))
            end
        end
        
        # Sort candidates by distance
        if !isempty(candidates)
            perm = sortperm(distances)
            candidates = candidates[perm]
            distances = distances[perm]
        end
        
        # Check visibility for each candidate face
        for (j, dᵢⱼ) in zip(candidates, distances)
            # Skip if already processed
            j in (vf.id for vf in temp_visible[i]) && continue

            cⱼ = face_centers[j]
            n̂ⱼ = face_normals[j]
            aⱼ = face_areas[j]

            ray = Ray(cᵢ, cⱼ - cᵢ)  # Ray from face i to face j

            # Check if any face from the candidate list blocks the view from i to j
            blocked = false
            for (k, dᵢₖ) in zip(candidates, distances)
                k == j && continue
                dᵢₖ > dᵢⱼ  && continue  # Skip if face k is farther than face j
                
                intersection = intersect_ray_triangle(ray, shape, k)
                if intersection.hit
                    blocked = true
                    break
                end
            end
            
            blocked && continue
            push!(temp_visible[i], VisibleFace(j, view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ)...))
            push!(temp_visible[j], VisibleFace(i, view_factor(cⱼ, cᵢ, n̂ⱼ, n̂ᵢ, aᵢ)...))
        end
    end
    
    # Build FaceVisibilityGraph directly in CSR format
    nfaces = length(faces)
    nnz = sum(length.(temp_visible))
    
    # Build CSR format data
    row_ptr = Vector{Int}(undef, nfaces + 1)
    col_idx = Vector{Int}(undef, nnz)
    view_factors = Vector{Float64}(undef, nnz)
    distances = Vector{Float64}(undef, nnz)
    directions = Vector{SVector{3, Float64}}(undef, nnz)
    
    # Build row_ptr
    row_ptr[1] = 1
    for i in 1:nfaces
        row_ptr[i + 1] = row_ptr[i] + length(temp_visible[i])
    end
    
    # Copy data
    idx = 1
    for i in 1:nfaces
        for vf in temp_visible[i]
            col_idx[idx] = vf.id
            view_factors[idx] = vf.f
            distances[idx] = vf.d
            directions[idx] = vf.d̂
            idx += 1
        end
    end
    
    shape.face_visibility_graph = FaceVisibilityGraph(row_ptr, col_idx, view_factors, distances, directions)
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                       Illumination Analysis                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    isilluminated_pseudo_convex(shape::ShapeModel, r☉::StaticVector{3}, i::Integer) -> Bool

Check if a face is illuminated using pseudo-convex model (face orientation only).

# Arguments
- `shape` : Shape model of an asteroid
- `r☉`    : Sun's position in the asteroid-fixed frame (doesn't need to be normalized)
- `i`     : Index of the face to be checked

# Description
This function checks only if the face is oriented towards the sun, without any
occlusion testing. This is equivalent to assuming the asteroid is convex or that
self-shadowing effects are negligible.

This function ignores `face_visibility_graph` even if it exists.

# Returns
- `true` if the face is oriented towards the sun
- `false` if the face is facing away from the sun
"""
function isilluminated_pseudo_convex(shape::ShapeModel, r☉::StaticVector{3}, i::Integer)::Bool
    n̂ᵢ = shape.face_normals[i]
    r̂☉ = normalize(r☉)
    return n̂ᵢ ⋅ r̂☉ > 0
end

"""
    isilluminated_with_self_shadowing(shape::ShapeModel, r☉::StaticVector{3}, i::Integer) -> Bool

Check if a face is illuminated with self-shadowing effects.

# Arguments
- `shape` : Shape model with `face_visibility_graph` (required)
- `r☉`    : Sun's position in the asteroid-fixed frame (doesn't need to be normalized)
- `i`     : Index of the face to be checked

# Description
This function performs full illumination calculation including self-shadowing effects.
It requires that `shape.face_visibility_graph` has been built using `build_face_visibility_graph!(shape)`.

If `face_visibility_graph` is not available, this function will throw an error.

# Returns
- `true` if the face is illuminated (facing the sun and not occluded)
- `false` if the face is facing away from the sun or is in shadow
"""
function isilluminated_with_self_shadowing(shape::ShapeModel, r☉::StaticVector{3}, i::Integer)::Bool
    @assert !isnothing(shape.face_visibility_graph) "face_visibility_graph is required for self-shadowing. Build it using `build_face_visibility_graph!(shape)`."
    
    cᵢ = shape.face_centers[i]
    n̂ᵢ = shape.face_normals[i]
    r̂☉ = normalize(r☉)
    
    # First check if the face is oriented away from the sun
    n̂ᵢ ⋅ r̂☉ < 0 && return false
    
    # Check for occlusions using face visibility graph
    ray = Ray(cᵢ, r̂☉)  # Ray from face center to the sun's position
    visible_face_indices = get_visible_face_indices(shape.face_visibility_graph, i)
    for j in visible_face_indices
        intersect_ray_triangle(ray, shape, j).hit && return false
    end
    return true  # No obstruction found
end



"""
    update_illumination_pseudo_convex!(illuminated::AbstractVector{Bool}, shape::ShapeModel, r☉::StaticVector{3})

Update illumination state using pseudo-convex model (face orientation only, no shadow testing).

# Arguments
- `illuminated` : Boolean vector to store illumination state (must have length equal to number of faces)
- `shape`       : Shape model of an asteroid
- `r☉`          : Sun's position in the asteroid-fixed frame

# Description
This function checks only if each face is oriented towards the sun, without any
occlusion testing. This is equivalent to assuming the asteroid is convex or that
self-shadowing effects are negligible.

This function ignores `face_visibility_graph` even if it exists, making it useful
when you want to explicitly disable self-shadowing effects.

# Implementation Note
This implementation uses `isilluminated_pseudo_convex` for code reuse and clarity.
While this causes `normalize(r☉)` to be computed N times instead of once, 
the performance impact is negligible for most use cases.

# Example
```julia
# Always use pseudo-convex model regardless of `face_visibility_graph`
update_illumination_pseudo_convex!(illuminated, shape, sun_position)
```
"""
function update_illumination_pseudo_convex!(illuminated::AbstractVector{Bool}, shape::ShapeModel, r☉::StaticVector{3})
    @assert length(illuminated) == length(shape.faces) "illuminated vector must have same length as number of faces."
    
    @inbounds for i in eachindex(shape.faces)
        illuminated[i] = isilluminated_pseudo_convex(shape, r☉, i)
    end
    
    return nothing
end

"""
    update_illumination_with_self_shadowing!(illuminated::AbstractVector{Bool}, shape::ShapeModel, r☉::StaticVector{3})

Update illumination state with self-shadowing effects using face visibility graph.

# Arguments
- `illuminated` : Boolean vector to store illumination state (must have length equal to number of faces)
- `shape`       : Shape model with face_visibility_graph (required)
- `r☉`          : Sun's position in the asteroid-fixed frame

# Description
This function performs full illumination calculation including self-shadowing effects.
It requires that `shape.face_visibility_graph` has been built using `build_face_visibility_graph!`.

If `face_visibility_graph` is not available, this function will throw an error.

# Implementation Note
This implementation uses `isilluminated_with_self_shadowing` for code reuse and clarity.
While this causes `normalize(r☉)` to be computed N times instead of once, 
the performance impact is negligible for most use cases.

# Example
```julia
# Ensure face visibility graph is built
shape = load_shape_obj("path/to/shape.obj"; scale=1000, with_face_visibility=true)
# Or build it manually:
# build_face_visibility_graph!(shape)

update_illumination_with_self_shadowing!(illuminated, shape, sun_position)
```
"""
function update_illumination_with_self_shadowing!(illuminated::AbstractVector{Bool}, shape::ShapeModel, r☉::StaticVector{3})
    @assert length(illuminated) == length(shape.faces) "illuminated vector must have same length as number of faces."
    @assert !isnothing(shape.face_visibility_graph) "face_visibility_graph is required for self-shadowing. Build it using build_face_visibility_graph!(shape)."
    
    @inbounds for i in eachindex(shape.faces)
        illuminated[i] = isilluminated_with_self_shadowing(shape, r☉, i)
    end
    
    return nothing
end

"""
    apply_eclipse_shadowing!(
        illuminated::AbstractVector{Bool}, target_shape::ShapeModel, r☉::StaticVector{3}, 
        occluding_shape::ShapeModel, R::StaticMatrix{3,3}, t::StaticVector{3}
    )

Apply eclipse shadowing effects from another shape onto already illuminated faces.

# Arguments
- `illuminated`     : Boolean vector with current illumination state (will be modified)
- `target_shape`    : Target shape model being shadowed
- `r☉`              : Sun's position in the target shape's frame
- `occluding_shape` : Shape model that may cast shadows on the target shape
- `R`               : 3×3 rotation matrix from `target_shape` frame to `occluding_shape` frame
- `t`               : 3D translation vector from `target_shape` frame to `occluding_shape` frame

# Description
This function ONLY checks for mutual shadowing (eclipse) effects. It assumes that
the `illuminated` vector already contains the result of face orientation and/or
self-shadowing checks. Only faces marked as `true` in the input will be tested
for occlusion by the other body.

This separation allows flexible control of shadowing effects in thermal modeling:
- Call `update_illumination!` first for self-shadowing (or face orientation only)
- Then call this function to add mutual shadowing effects

# Coordinate Systems
The transformation from `target_shape` frame to `occluding_shape` frame is given by:
`p_occluding = R * p_target + t`

# Example
```julia
# Check self-shadowing first (considering self-shadowing effect)
update_illumination_with_self_shadowing!(illuminated1, shape1, sun_position1)
update_illumination_with_self_shadowing!(illuminated2, shape2, sun_position2)

# Or if you want to ignore self-shadowing:
update_illumination_pseudo_convex!(illuminated1, shape1, sun_position1)
update_illumination_pseudo_convex!(illuminated2, shape2, sun_position2)

# Then check mutual shadowing
apply_eclipse_shadowing!(illuminated1, shape1, sun_position1, shape2, R12, t12)
apply_eclipse_shadowing!(illuminated2, shape2, sun_position2, shape1, R21, t21)
```
"""
function apply_eclipse_shadowing!(
    illuminated::AbstractVector{Bool}, target_shape::ShapeModel, r☉::StaticVector{3},
    occluding_shape::ShapeModel, R::StaticMatrix{3,3}, t::StaticVector{3}
)
    @assert length(illuminated) == length(target_shape.faces) "illuminated vector must have same length as number of faces."
    
    # If all faces are already in shadow, no need to check occlusion
    if !any(illuminated)
        return nothing
    end
    
    # Check occlusion by the other body for illuminated faces only
    r̂☉ = normalize(r☉)
    
    @inbounds for i in eachindex(target_shape.faces)
        if illuminated[i]  # Only check if not already in shadow
            # Ray from face center to sun in target's frame
            ray_origin = target_shape.face_centers[i]
            
            # Transform ray's origin and direction to occluding shape's frame
            # (Ray directions are not affected by translation)
            origin_transformed = R * ray_origin + t
            direction_transformed = R * r̂☉
            
            # Create ray in occluding shape's frame
            ray_transformed = Ray(origin_transformed, direction_transformed)
            
            # Check intersection with occluding shape
            if intersect_ray_shape(ray_transformed, occluding_shape).hit
                illuminated[i] = false
            end
        end
    end
    
    return nothing
end
