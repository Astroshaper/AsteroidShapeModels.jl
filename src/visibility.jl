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
- `isilluminated`: Check face illumination (unified API)
- `update_illumination!`: Batch update illumination (unified API)
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
            j in (vf.face_idx for vf in temp_visible[i]) && continue

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
            col_idx[idx] = vf.face_idx
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
    EclipseStatus

Enum representing the eclipse status between binary pairs.

# Values
- `NO_ECLIPSE`      : No eclipse occurs (bodies are misaligned).
- `PARTIAL_ECLIPSE` : Some faces are eclipsed by the occluding body.
- `TOTAL_ECLIPSE`   : All illuminated faces are eclipsed (complete shadow).
"""
@enum EclipseStatus begin
    NO_ECLIPSE      = 0
    PARTIAL_ECLIPSE = 1
    TOTAL_ECLIPSE   = 2
end

"""
    isilluminated(shape::ShapeModel, r☉::StaticVector{3}, face_idx::Integer; with_self_shadowing::Bool) -> Bool

Check if a face is illuminated by the sun.

# Arguments
- `shape`    : Shape model of an asteroid
- `r☉`       : Sun's position in the asteroid-fixed frame
- `face_idx` : Index of the face to be checked

# Keyword Arguments
- `with_self_shadowing::Bool` : Whether to include self-shadowing effects.
  - `false`: Use pseudo-convex model (face orientation only)
  - `true`: Include self-shadowing (requires `face_visibility_graph` to be built)

# Returns
- `true` if the face is illuminated
- `false` if the face is in shadow or facing away from the sun

# Examples
```julia
# Without self-shadowing (pseudo-convex model)
illuminated = isilluminated(shape, sun_position, face_idx; with_self_shadowing=false)

# With self-shadowing
illuminated = isilluminated(shape, sun_position, face_idx; with_self_shadowing=true)
```
"""
function isilluminated(shape::ShapeModel, r☉::StaticVector{3}, face_idx::Integer; with_self_shadowing::Bool)
    if with_self_shadowing
        @assert !isnothing(shape.face_visibility_graph) "face_visibility_graph is required for self-shadowing. Build it using `build_face_visibility_graph!(shape)`."
        return isilluminated_with_self_shadowing(shape, r☉, face_idx)
    else
        return isilluminated_pseudo_convex(shape, r☉, face_idx)
    end
end

"""
    isilluminated_pseudo_convex(shape::ShapeModel, r☉::StaticVector{3}, face_idx::Integer) -> Bool

Check if a face is illuminated using pseudo-convex model (face orientation only).

# Arguments
- `shape`    : Shape model of an asteroid
- `r☉`       : Sun's position in the asteroid-fixed frame (doesn't need to be normalized)
- `face_idx` : Index of the face to be checked

# Description
This function checks only if the face is oriented towards the sun, without any
occlusion testing. This is equivalent to assuming the asteroid is convex or that
self-shadowing effects are negligible.

This function ignores `face_visibility_graph` even if it exists.

# Returns
- `true` if the face is oriented towards the sun
- `false` if the face is facing away from the sun
"""
function isilluminated_pseudo_convex(shape::ShapeModel, r☉::StaticVector{3}, face_idx::Integer)::Bool
    n̂ᵢ = shape.face_normals[face_idx]
    r̂☉ = normalize(r☉)
    return n̂ᵢ ⋅ r̂☉ > 0
end

"""
    isilluminated_with_self_shadowing(shape::ShapeModel, r☉::StaticVector{3}, face_idx::Integer) -> Bool

Check if a face is illuminated with self-shadowing effects.

# Arguments
- `shape`    : Shape model with `face_visibility_graph` (required)
- `r☉`       : Sun's position in the asteroid-fixed frame (doesn't need to be normalized)
- `face_idx` : Index of the face to be checked

# Description
This function performs full illumination calculation including self-shadowing effects.
It requires that `shape.face_visibility_graph` has been built using `build_face_visibility_graph!(shape)`.

If `face_visibility_graph` is not available, this function will throw an error.

# Returns
- `true` if the face is illuminated (facing the sun and not occluded)
- `false` if the face is facing away from the sun or is in shadow
"""
function isilluminated_with_self_shadowing(shape::ShapeModel, r☉::StaticVector{3}, face_idx::Integer)::Bool
    @assert !isnothing(shape.face_visibility_graph) "face_visibility_graph is required for self-shadowing. Build it using `build_face_visibility_graph!(shape)`."
    
    cᵢ = shape.face_centers[face_idx]
    n̂ᵢ = shape.face_normals[face_idx]
    r̂☉ = normalize(r☉)
    
    # First check if the face is oriented away from the sun
    n̂ᵢ ⋅ r̂☉ < 0 && return false
    
    # Check for occlusions using face visibility graph
    ray = Ray(cᵢ, r̂☉)  # Ray from face center to the sun's position
    visible_face_indices = get_visible_face_indices(shape.face_visibility_graph, face_idx)
    for j in visible_face_indices
        intersect_ray_triangle(ray, shape, j).hit && return false
    end
    return true  # No obstruction found
end

"""
    update_illumination!(illuminated::AbstractVector{Bool}, shape::ShapeModel, r☉::StaticVector{3}; with_self_shadowing::Bool)

Update illumination state for all faces of a shape model.

# Arguments
- `illuminated` : Boolean vector to store illumination state (must have length equal to number of faces)
- `shape`       : Shape model of an asteroid
- `r☉`          : Sun's position in the asteroid-fixed frame

# Keyword Arguments
- `with_self_shadowing::Bool` : Whether to include self-shadowing effects.
  - `false`: Use pseudo-convex model (face orientation only)
  - `true`: Include self-shadowing (requires `face_visibility_graph` to be built)

# Examples
```julia
# Prepare illumination vector
illuminated = Vector{Bool}(undef, length(shape.faces))

# Without self-shadowing (pseudo-convex model)
update_illumination!(illuminated, shape, sun_position; with_self_shadowing=false)

# With self-shadowing
update_illumination!(illuminated, shape, sun_position; with_self_shadowing=true)
```
"""
function update_illumination!(illuminated::AbstractVector{Bool}, shape::ShapeModel, r☉::StaticVector{3}; with_self_shadowing::Bool)
    if with_self_shadowing
        @assert !isnothing(shape.face_visibility_graph) "face_visibility_graph is required for self-shadowing. Build it using `build_face_visibility_graph!(shape)`."
        update_illumination_with_self_shadowing!(illuminated, shape, r☉)
    else
        update_illumination_pseudo_convex!(illuminated, shape, r☉)
    end
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
        illuminated::AbstractVector{Bool}, shape1::ShapeModel, r☉₁::StaticVector{3}, 
        R₁₂::StaticMatrix{3,3}, t₁₂::StaticVector{3}, shape2::ShapeModel
    ) -> EclipseStatus

Apply eclipse shadowing effects from another shape onto already illuminated faces.

# Arguments
- `illuminated` : Boolean vector with current illumination state (will be modified)
- `shape1`      : Target shape model being shadowed (the shape receiving shadows)
- `r☉₁`         : Sun's position in shape1's frame
- `R₁₂`         : 3×3 rotation matrix from `shape1` frame to `shape2` frame
- `t₁₂`         : 3D translation vector from `shape1` frame to `shape2` frame
- `shape2`      : Occluding shape model that may cast shadows on `shape1` (must have BVH built via `build_bvh!`)

# Returns
- `NO_ECLIPSE`: No eclipse occurs (bodies are misaligned).
- `PARTIAL_ECLIPSE`: Some faces that were illuminated are now in shadow by the occluding body.
- `TOTAL_ECLIPSE`: All faces that were illuminated are now in shadow.

# Throws
- `ArgumentError` if `shape2` does not have BVH built. Call `build_bvh!(shape2)` before using this function.

# Description
This function ONLY checks for mutual shadowing (eclipse) effects. It assumes that
the `illuminated` vector already contains the result of face orientation and/or
self-shadowing checks. Only faces marked as `true` in the input will be tested
for occlusion by the other body.

This separation allows flexible control of shadowing effects in thermal modeling:
- Call `update_illumination_*` first for self-shadowing (or face orientation only)
- Then call this function to add mutual shadowing effects

# Performance Optimizations
The function includes early-out checks at two levels:

## Body-level optimizations:
1. **Behind Check**: If the occluding body is entirely behind the target relative to the sun,
   no eclipse can occur.

2. **Lateral Separation Check**: If bodies are too far apart laterally (perpendicular to 
   sun direction), no eclipse can occur.

3. **Total Eclipse Check**: If the target is completely within the occluding body's shadow,
   all illuminated faces are set to false without individual ray checks.

## Face-level optimizations:
4. **Ray-Sphere Intersection Check**: For each face, checks if the ray to the sun can possibly
   intersect the occluding body's bounding sphere. Skips ray-shape test if the ray clearly
   misses the sphere.

5. **Inscribed Sphere Check**: If the ray passes through the occluding body's inscribed sphere,
   the face is guaranteed to be shadowed, avoiding the expensive ray-shape intersection test.

These optimizations use `maximum_radius` and `minimum_radius` for accurate sphere calculations.

# Coordinate Systems
The transformation from `shape1` frame to `shape2` frame is given by:
`p_shape2 = R₁₂ * p_shape1 + t₁₂`

# Example
```julia
# Check self-shadowing first (considering self-shadowing effect)
update_illumination_with_self_shadowing!(illuminated1, shape1, sun_position1)
update_illumination_with_self_shadowing!(illuminated2, shape2, sun_position2)

# Or if you want to ignore self-shadowing:
update_illumination_pseudo_convex!(illuminated1, shape1, sun_position1)
update_illumination_pseudo_convex!(illuminated2, shape2, sun_position2)

# Then check eclipse shadowing
# For checking mutual shadowing, apply to both shape1 and shape2:
status1 = apply_eclipse_shadowing!(illuminated1, shape1, sun_position1, R12, t12, shape2)
status2 = apply_eclipse_shadowing!(illuminated2, shape2, sun_position2, R21, t21, shape1)

# Handle eclipse status
if status1 == NO_ECLIPSE
    println("Shape1 is not eclipsed by shape2.")
elseif status1 == PARTIAL_ECLIPSE
    println("Shape1 is partially eclipsed by shape2.")
elseif status1 == TOTAL_ECLIPSE
    println("Shape1 is totally eclipsed by shape2.")
end
```
"""
function apply_eclipse_shadowing!(
    illuminated::AbstractVector{Bool}, shape1::ShapeModel, r☉₁::StaticVector{3},
    R₁₂::StaticMatrix{3,3}, t₁₂::StaticVector{3}, shape2::ShapeModel
)::EclipseStatus
    @assert length(illuminated) == length(shape1.faces) "illuminated vector must have same length as number of faces."
    isnothing(shape2.bvh) && throw(ArgumentError("Occluding shape model (`shape2`) must have BVH built before checking eclipse shadowing. Call `build_bvh!(shape2)` first."))
    
    r̂☉₁ = normalize(r☉₁)        # Normalized sun direction in shape1's frame
    r̂☉₂ = normalize(R₁₂ * r̂☉₁)  # Normalized sun direction in shape2's frame
    
    # Get bounding sphere radii for both shapes
    ρ₁ = maximum_radius(shape1)
    ρ₂ = maximum_radius(shape2)
    
    # Get inscribed sphere radius for shape2 (for guaranteed shadow regions)
    ρ₂_inner = minimum_radius(shape2)
    
    # ==== Early Out 1 (Behind Check) ====
    # If shape2 is entirely behind shape1 relative to sun, no eclipse occur.
    if dot(t₁₂, r̂☉₁) < -(ρ₁ + ρ₂)
        return NO_ECLIPSE  
    end
    
    # ==== Early Out 2 (Lateral Separation Check)  ====
    # If bodies are too far apart laterally, no eclipse occur.
    t₁₂⊥ = t₁₂ - (dot(t₁₂, r̂☉₁) * r̂☉₁)  # Component of t₁₂ perpendicular to sun direction
    d⊥ = norm(t₁₂⊥)                     # Lateral distance between bodies
    if d⊥ > ρ₁ + ρ₂
        return NO_ECLIPSE
    end
    
    # ==== Early Out 3 (Total Eclipse Check) ====
    # If shape1 is completely within shape2's shadow, all faces are shadowed.
    # This happens when shape2 is between sun and shape1, and is larger than shape1.
    # Check if shape2 is in front of shape1 along sun direction,
    # and if the lateral distance is small enough.
    if dot(t₁₂, r̂☉₁) > 0  && d⊥ + ρ₁ < ρ₂
        illuminated .= false  # All faces are shadowed.
        return TOTAL_ECLIPSE
    end
    
    # Track whether any eclipse occurred
    eclipse_occurred = false
    
    # Check occlusion by the other body for illuminated faces only
    @inbounds for i in eachindex(shape1.faces)
        if illuminated[i]  # Only check if not already in shadow
            # Ray from face center to sun in shape1's frame
            ray_origin1 = shape1.face_centers[i]
            
            # Transform ray's origin to shape2's frame
            ray_origin2 = R₁₂ * ray_origin1 + t₁₂
            
            # ==== Face-level Early Out ====
            # Check if the ray from this face to the sun can possibly intersect
            # shape2's bounding sphere.
            
            # Calculate the parameter t where the ray is closest to shape2's center.
            # Ray: P(t) = ray_origin2 + t * r̂☉₂, where t > 0 toward sun
            # The closest point is where d/dt |P(t)|² = 0
            t_min = -dot(ray_origin2, r̂☉₂)
            
            if t_min < 0
                # Shape2's center is in the opposite direction from the sun.
                # (i.e., the ray is moving away from shape2)
                # In this case, check if the face itself is outside bounding sphere.
                if norm(ray_origin2) > ρ₂
                    continue
                end
            else
                # The ray approaches shape2's center.
                # Calculate the closest point on the ray to the center
                p_closest = ray_origin2 + t_min * r̂☉₂
                d_center = norm(p_closest)
                
                # ==== Early Out 4 (Ray-Sphere Intersection Check) ====
                # If the ray passes within the bounding sphere,
                # ray misses the bounding sphere entirely.
                if d_center > ρ₂
                    continue
                end
                
                # ==== Early Out 5 (Inscribed Sphere Check) ====
                # If the ray passes through the inscribed sphere, it's guaranteed to hit shape2
                # (no need for detailed intersection test)
                if d_center < ρ₂_inner
                    illuminated[i] = false
                    eclipse_occurred = true
                    continue
                end
            end
            
            # Create ray in shape2's frame
            # (Direction was already transformed at the beginning of the function)
            ray2 = Ray(ray_origin2, r̂☉₂)
            
            # Check intersection with shape2
            if intersect_ray_shape(ray2, shape2).hit
                illuminated[i] = false
                eclipse_occurred = true
            end
        end
    end
    
    # Determine eclipse status based on results
    if !eclipse_occurred
        return NO_ECLIPSE
    elseif count(illuminated) == 0  # if all faces are now in shadow
        return TOTAL_ECLIPSE
    else
        return PARTIAL_ECLIPSE
    end
end
