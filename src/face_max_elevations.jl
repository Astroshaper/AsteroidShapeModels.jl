#=
    face_max_elevations.jl

Implementation of face maximum elevation computation for illumination optimization.
This module calculates the maximum elevation angle from which each face can be 
potentially shadowed by other faces, enabling early-out optimization in illumination checks.

Exported Functions:
- `compute_face_max_elevations!`: Compute maximum elevation angles for all faces
- `compute_edge_max_elevation`: Compute maximum elevation angle on a single edge
- `isilluminated_with_self_shadowing_optimized`: Optimized single-face illumination check
- `update_illumination_with_self_shadowing_optimized!`: Optimized batch illumination update
=#

"""
    compute_edge_max_elevation(
        obs::SVector{3}, n̂::SVector{3},
        A::SVector{3}, B::SVector{3},
    ) -> (p_max::SVector{3}, θ_max::Float64)

Compute the maximum elevation angle on the edge from A to B when viewed from obs with normal n̂.

# Arguments
- `obs` : Observer position (face center)
- `n̂` : Observer normal (face normal, must be normalized)
- `A` : First vertex of the edge
- `B` : Second vertex of the edge

# Returns
- `p_max`: Point on the edge where maximum elevation occurs
- `θ_max`: Maximum elevation angle in radians

# Algorithm
Maximizes the elevation angle θ(t) = arcsin(n̂ · d̂(t)) for t ∈ [0,1],
where d̂(t) = normalize((1-t)A + t·B - obs) is the direction from observer to a point on edge A-B.
If t = 0, the edge point is A, if t = 1, it is B.

Approach: Set dθ/dt = 0 and solve for critical points.
Since sin(θ) = n̂ · d̂(t), maximizing θ is equivalent to maximizing n̂ · d̂(t).
The derivative leads to a linear equation: β·t + γ = 0,
where β = (n̂·e)(a·e) - (n̂·a)(e·e),
      γ = (n̂·e)(a·a) - (n̂·a)(a·e),
with a = A - obs, e = B - A

# Notes
- The computation may become unstable when `obs` coincides with vertices A, B, 
  or points on the edge. In such cases, the normalize operation may produce NaN.
- This function is designed for use with a face center as the observer position `obs`, 
  where such degeneracies do not occur in practice.
"""
function compute_edge_max_elevation(obs::SVector{3}, n̂::SVector{3}, A::SVector{3}, B::SVector{3})
    # Relative vectors
    a = A - obs  # From observer to first vertex
    b = B - obs  # From observer to second vertex
    e = B - A    # Edge direction
    
    # Compute coefficients for critical point equation
    n_dot_a = n̂ ⋅ a
    n_dot_e = n̂ ⋅ e
    a_dot_a = a ⋅ a
    a_dot_e = a ⋅ e
    e_dot_e = e ⋅ e
    
    β = n_dot_e * a_dot_e - n_dot_a * e_dot_e
    γ = n_dot_e * a_dot_a - n_dot_a * a_dot_e
    
    # Find optimal t according to t = -γ / β
    if abs(β) < 1e-10
        # β ≈ 0: no critical point or constant function
        # Check endpoints
        â = normalize(a)
        b̂ = normalize(b)
        θ_a = asin(clamp(n̂ ⋅ â, -1.0, 1.0))
        θ_b = asin(clamp(n̂ ⋅ b̂, -1.0, 1.0))
        
        return θ_a ≥ θ_b ? (A, θ_a) : (B, θ_b)
    else
        # Find maximum at clamped critical point
        t_max = clamp(-γ/β, 0.0, 1.0)  # Critical t giving maximum elevation
        p_max = (1 - t_max) * A + t_max * B    # Point on edge at critical t

        d̂ = normalize(p_max - obs)             # Direction from observer to maximum elevation point
        θ_max = asin(clamp(n̂ ⋅ d̂, -1.0, 1.0))  # Maximum elevation angle [rad]

        return (p_max, θ_max)
    end
end

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
- Nothing (modifies `shape.face_max_elevations` in-place)

# Algorithm
For each face i:
1. Get all faces j visible from face i (from `shape.face_visibility_graph`)
2. For each visible face j:
   - Check maximum elevation angles on all three edges using `compute_edge_max_elevation`
   - Note: `compute_edge_max_elevation` handles both edge interiors and endpoints (vertices)
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
            v1, v2, v3 = get_face_nodes(shape, j)
            
            # Check elevation angle for each edge of face j
            # Note: This includes vertices as edge endpoints (t=0 or t=1)
            edges = [(v1, v2), (v2, v3), (v3, v1)]
            for (A, B) in edges
                _, θ = compute_edge_max_elevation(cᵢ, n̂ᵢ, A, B)
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