"""
Geometric utility functions for asteroid shape analysis.
"""

"""
    angle_rad(v1, v2) -> Float64

Calculate the angle between two vectors in radians.

# Arguments
- `v1` : First vector
- `v2` : Second vector

# Returns
- Angle between vectors in radians [0, π]
"""
angle_rad(v1::AbstractVector{<:Real}, v2::AbstractVector{<:Real}) = acos(clamp(normalize(v1) ⋅ normalize(v2), -1.0, 1.0))

"""
    angle_deg(v1, v2) -> Float64

Calculate the angle between two vectors in degrees.

# Arguments
- `v1` : First vector
- `v2` : Second vector

# Returns
- Angle between vectors in degrees [0, 180]
"""
angle_deg(v1::AbstractVector{<:Real}, v2::AbstractVector{<:Real}) = rad2deg(angle_rad(v1, v2))

"""
    angle_rad(v1::AbstractVector{<:AbstractVector}, v2::AbstractVector{<:AbstractVector}) -> Vector{Float64}

Calculate angles between corresponding pairs of vectors in two arrays (broadcast version).

# Arguments
- `v1`: Array of first vectors
- `v2`: Array of second vectors (must have same length as v1)

# Returns
- Array of angles in radians between corresponding vector pairs

# Examples
```julia
v1s = [SA[1,0,0], SA[0,1,0]]
v2s = [SA[0,1,0], SA[1,0,0]]
angles = angle_rad(v1s, v2s)  # Returns [π/2, π/2]
```
"""
angle_rad(v1::AbstractVector{<:AbstractVector{<:Real}}, v2::AbstractVector{<:AbstractVector{<:Real}}) = angle_rad.(v1, v2)

"""
    angle_deg(v1::AbstractVector{<:AbstractVector}, v2::AbstractVector{<:AbstractVector}) -> Vector{Float64}

Calculate angles between corresponding pairs of vectors in two arrays (broadcast version).

# Arguments
- `v1`: Array of first vectors
- `v2`: Array of second vectors (must have same length as v1)

# Returns
- Array of angles in degrees between corresponding vector pairs

# Examples
```julia
v1s = [SA[1,0,0], SA[0,1,0]]
v2s = [SA[0,1,0], SA[1,0,0]]
angles = angle_deg(v1s, v2s)  # Returns [90.0, 90.0]
```
"""
angle_deg(v1::AbstractVector{<:AbstractVector{<:Real}}, v2::AbstractVector{<:AbstractVector{<:Real}}) = angle_deg.(v1, v2)

"""
    solar_phase_angle(sun, target, observer) -> Float64

Calculate a sun-target-observer angle (phase angle).

# Arguments
- `sun`      : Sun position vector
- `target`   : Target position vector
- `observer` : Observer position vector

# Returns
- ∠STO : Sun-target-observer angle (phase angle) [rad]
"""
solar_phase_angle(sun::AbstractVector{<:Real}, target::AbstractVector{<:Real}, observer::AbstractVector{<:Real}) = angle_rad(sun - target, observer - target)

"""
    solar_elongation_angle(sun, observer, target) -> Float64

Calculate a sun-observer-target angle (solar elongation angle).

# Arguments
- `sun`      : Sun position vector
- `observer` : Observer position vector
- `target`   : Target position vector

# Returns
- ∠SOT : Sun-observer-target angle (solar elongation angle) [rad]
"""
solar_elongation_angle(sun::AbstractVector{<:Real}, observer::AbstractVector{<:Real}, target::AbstractVector{<:Real}) = angle_rad(sun - observer, target - observer)
