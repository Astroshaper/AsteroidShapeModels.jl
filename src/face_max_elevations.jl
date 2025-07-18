"""
    face_max_elevations.jl

Implementation of face maximum elevation computation for illumination optimization.
This module calculates the maximum elevation angle from which each face can be 
potentially shadowed by other faces, enabling early-out optimization in illumination checks.
"""

"""
    compute_face_max_elevations!(shape::ShapeModel)

Compute the maximum elevation angle for each face based on the face visibility graph.

# Description
For each face, this function calculates the maximum elevation angle from which
the face can potentially be shadowed by any visible face. If the sun's elevation
is higher than this angle, the face is guaranteed to be illuminated (if facing the sun).

The elevation is calculated as the angle between the horizon plane (perpendicular to
the face normal) and the direction to the highest visible face.

# Arguments
- `shape`: ShapeModel with face_visibility_graph already built

# Returns
- Nothing (modifies `ShapeModel.face_max_elevations` in-place)

# Algorithm
For each face i:
1. Get all faces j visible from face i (from face_visibility_graph)
2. For each visible face j:
   - Calculate direction vector d_ij from face i to face j
   - Calculate elevation angle: angle between d_ij and the horizon plane of face i
3. Store the maximum elevation angle found
"""
function compute_face_max_elevations!(shape::ShapeModel)
    @assert !isnothing(shape.face_visibility_graph) "face_visibility_graph is required. Build it using build_face_visibility_graph!(shape)."
    
    nfaces = length(shape.faces)
    
    # Initialize face_max_elevations if not present
    if isnothing(shape.face_max_elevations)
        shape.face_max_elevations = zeros(Float64, nfaces)
    end
    
    # Compute maximum elevation for each face
    for i in eachindex(shape.faces)
        θ_max = 0.0
        
        # Get face normal and center
        n̂ᵢ = shape.face_normals[i]
        cᵢ = shape.face_centers[i]
        
        # Get visible faces from this face
        visible_face_indices = get_visible_face_indices(shape.face_visibility_graph, i)
        
        for j in visible_face_indices
            # Get vertices of face j
            vs = get_face_nodes(shape, j)  # (v1, v2, v3)
            
            # Check elevation angle for each vertex of face j
            for v in vs
                # Direction from face i center to vertex of face j
                d̂ᵢⱼ = normalize(v - cᵢ)
                
                # Calculate elevation angle θ [rad]
                # Elevation θ is the angle from the horizon plane (perpendicular to normal)
                # cos(90° - θ) = sin(θ) = n̂ᵢ ⋅ d̂ᵢⱼ
                sinθ = n̂ᵢ ⋅ d̂ᵢⱼ
                θ = asin(clamp(sinθ, 0.0, 1.0))
                
                # Update maximum elevation angle for face i
                θ_max = max(θ_max, θ)
            end
        end

        shape.face_max_elevations[i] = θ_max
    end
    
    return nothing
end

"""
    isilluminated_with_self_shadowing_optimized(shape::ShapeModel, r☉::StaticVector{3}, face_idx::Integer) -> Bool

Optimized version of isilluminated_with_self_shadowing using face_max_elevations.

# Arguments
- `shape`    : Shape model with face_visibility_graph and face_max_elevations
- `r☉`       : Sun's position in the asteroid-fixed frame
- `face_idx` : Index of the face to be checked

# Description
This function uses the precomputed face_max_elevations to skip ray-triangle
intersection tests when the sun's elevation is higher than the maximum elevation
from which the face can be shadowed.

# Performance
- Best case (high sun): O(1) - only dot product and comparison
- Worst case (low sun): Same as original implementation
- Expected speedup: Significant for high sun elevations

# Returns
- `true` if the face is illuminated
- `false` if the face is in shadow or facing away from the sun
"""
function isilluminated_with_self_shadowing_optimized(shape::ShapeModel, r☉::StaticVector{3}, face_idx::Integer)::Bool
    @assert !isnothing(shape.face_visibility_graph) "face_visibility_graph is required for self-shadowing. Build it using `build_face_visibility_graph!(shape)`."
    @assert !isnothing(shape.face_max_elevations) "face_max_elevations must be computed first."
    
    cᵢ = shape.face_centers[face_idx]
    n̂ᵢ = shape.face_normals[face_idx]
    r̂☉ = normalize(r☉)

    # Sun's elevation angle relative to the face, θ☉ [rad]
    # cos(90° - θ☉) = sin(θ☉) = n̂ᵢ ⋅ r̂☉
    sinθ☉ = n̂ᵢ ⋅ r̂☉
    
    # Early-out 1:
    # If this face is oriented away from the sun, not illuminated (return false).
    sinθ☉ < 0 && return false
    
    θ☉ = asin(clamp(sinθ☉, 0.0, 1.0))
    
    # Early-out 2:
    # If sun elevation is higher than surrounding maximum elevation for this face,
    # guaranteed to be illuminated (return true).
    θ☉ > shape.face_max_elevations[face_idx] && return true
    
    # Otherwise, perform regular occlusion check
    ray = Ray(cᵢ, r̂☉)
    visible_face_indices = get_visible_face_indices(shape.face_visibility_graph, face_idx)
    for j in visible_face_indices
        intersect_ray_triangle(ray, shape, j).hit && return false
    end
    return true
end

"""
    update_illumination_with_self_shadowing_optimized!(illuminated_faces::AbstractVector{Bool}, shape::ShapeModel, r☉::StaticVector{3})

Optimized batch illumination update using `ShapeModel.face_max_elevations`.

# Arguments
- `illuminated_faces` : Boolean vector to store illumination state
- `shape`             : Shape model with face_visibility_graph and face_max_elevations
- `r☉`                : Sun's position in the asteroid-fixed frame

# Description
Batch version of the optimized illumination check. Uses face_max_elevations
to skip ray-triangle intersection tests for faces that are guaranteed to be
illuminated based on sun elevation.
"""
function update_illumination_with_self_shadowing_optimized!(illuminated_faces::AbstractVector{Bool}, shape::ShapeModel, r☉::StaticVector{3})
    @assert length(illuminated_faces) == length(shape.faces) "illuminated_faces vector must have same length as number of faces."
    @assert !isnothing(shape.face_visibility_graph) "face_visibility_graph is required. Build it using build_face_visibility_graph!(shape)."
    @assert !isnothing(shape.face_max_elevations) "face_max_elevations must be computed first."
    
    @inbounds for i in eachindex(shape.faces)
        illuminated_faces[i] = isilluminated_with_self_shadowing_optimized(shape, r☉, i)
    end
    
    return nothing
end