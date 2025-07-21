#=
    face_max_elevations.jl

Implementation of face maximum elevation computation for illumination optimization.
This module calculates the maximum elevation angle from which each face can be 
potentially shadowed by other faces, enabling early-out optimization in illumination checks.

Exported Functions:
- `compute_face_max_elevations!`: Compute maximum elevation angles for all faces
=#

"""
    compute_elevation_angle(obs::SVector{3}, n̂::SVector{3}, p::SVector{3}) -> Float64

Compute the elevation angle from observer position to a point.

# Arguments
- `obs` : Observer position
- `n̂`   : Observer's surface normal (must be normalized)
- `p`   : Point to compute elevation angle to

# Returns
- Elevation angle in radians, in range [-π/2, π/2]

# Notes
The elevation angle is the angle between the horizon plane (perpendicular to n̂) 
and the direction from observer to the point. Positive angles indicate the point 
is above the horizon, negative angles indicate below.
"""
@inline function compute_elevation_angle(obs::SVector{3}, n̂::SVector{3}, p::SVector{3})::Float64
    d̂ = normalize(p - obs)
    return asin(clamp(n̂ ⋅ d̂, -1.0, 1.0))
end

"""
    compute_edge_max_elevation(
        obs::SVector{3}, n̂::SVector{3},
        A::SVector{3}, B::SVector{3},
    ) -> (θ_max::Float64, p_max::SVector{3})

Compute the maximum elevation angle on the edge from A to B when viewed from obs with normal n̂.

# Arguments
- `obs` : Observer position (face center)
- `n̂` : Observer normal (face normal, must be normalized)
- `A` : First vertex of the edge
- `B` : Second vertex of the edge

# Returns
- `θ_max`: Maximum elevation angle in radians
- `p_max`: Point on the edge where maximum elevation occurs

# Algorithm
Maximizes the elevation angle θ(t) = arcsin(n̂ · d̂(t)) for t ∈ [0, 1],
where d̂(t) = normalize((1-t)A + t·B - obs) is the direction from observer to a point on edge A-B.
If t = 0, the edge point is A, if t = 1, it is B.

Since sin(θ) = n̂ · d̂(t), maximizing θ is equivalent to maximizing f(t) = n̂ · d̂(t).
The derivative results in df/dt = α·t² + β·t + γ,
where α = 0,
      β = (n̂·e)(a·e) - (n̂·a)(e·e),
      γ = (n̂·e)(a·a) - (n̂·a)(a·e),
with a = A - obs, e = B - A.
A critical t giving the maximum of f(t) is obtained by solving df/dt = β·t + γ = 0.

# Notes
- The computation may become unstable when `obs` coincides with vertices A, B, 
  or points on the edge. In such cases, the normalize operation may produce NaN.
- This function is designed for use with a face center as the observer position `obs`, 
  where such degeneracies do not occur in practice.
"""
function compute_edge_max_elevation(obs::SVector{3}, n̂::SVector{3}, A::SVector{3}, B::SVector{3})::Tuple{Float64, SVector{3,Float64}}
    a = A - obs  # From observer to first vertex
    e = B - A    # Edge vector from A to B
    
    # Compute coefficients for critical point equation, df/dt = 0
    n_dot_a = n̂ ⋅ a
    n_dot_e = n̂ ⋅ e
    a_dot_a = a ⋅ a
    a_dot_e = a ⋅ e
    e_dot_e = e ⋅ e
    
    # Coefficients of the dervative df/dt = β·t + γ
    β = n_dot_e * a_dot_e - n_dot_a * e_dot_e
    γ = n_dot_e * a_dot_a - n_dot_a * a_dot_e
    
    # Evaluate elevation for endpoints
    θ_A = compute_elevation_angle(obs, n̂, A)
    θ_B = compute_elevation_angle(obs, n̂, B)
    
    # Find optimal t based on β
    if abs(β) < 1e-10
        # β ≈ 0: df/dt = γ is constant
        # If γ > 0, f(t) is increasing → maximum at t = 1
        # If γ < 0, f(t) is decreasing → maximum at t = 0
        # If γ ≈ 0, f(t) is constant   → check endpoints
        if abs(γ) < 1e-10
            return θ_A ≥ θ_B ? (θ_A, A) : (θ_B, B)
        elseif γ > 0
            return (θ_B, B)
        else
            return (θ_A, A)
        end
    elseif β < 0
        # β < 0: df/dt has a maximum (f is concave down)
        # Critical point t_crit = -γ/β could be a maximum
        t_crit = -γ / β
        
        if t_crit ≤ 0
            # Maximum is at t = 0 (or before the edge)
            return (θ_A, A)
        elseif t_crit ≥ 1
            # Maximum is at t = 1 (or beyond the edge)
            return (θ_B, B)
        else
            # Maximum is at the critical point inside [0, 1]
            p_crit = (1 - t_crit) * A + t_crit * B
            θ_crit = compute_elevation_angle(obs, n̂, p_crit)
            return (θ_crit, p_crit)
        end
    else  # β > 0
        # β > 0: df/dt has a minimum (f is concave up)
        # Maximum must be at one of the endpoints
        return θ_A ≥ θ_B ? (θ_A, A) : (θ_B, B)
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
                θ, _ = compute_edge_max_elevation(cᵢ, n̂ᵢ, A, B)
                θ_max = max(θ_max, θ)
            end
        end
        
        shape.face_max_elevations[i] = θ_max
    end
    
    return nothing
end
