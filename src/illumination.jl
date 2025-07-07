#=
    illumination.jl

This file implements illumination analysis for asteroid shape models.
It includes functions for determining which faces are illuminated by the sun,
considering both simple face orientation and complex self-shadowing effects.

Exported Functions:
- `isilluminated`: Check face illumination (unified API)
- `update_illumination!`: Batch update illumination (unified API)
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Single Face Illumination Check                  ║
# ╚═══════════════════════════════════════════════════════════════════╝

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

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    Batch Illumination Update                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

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