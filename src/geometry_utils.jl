#=
    geometry_utils.jl

Geometric utility functions for asteroid shape analysis.
This file provides functions for:
- Angle calculations between vectors
- Solar geometry calculations for asteroid observations
- Common geometric operations used in asteroid science
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Angle Calculations                           ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    angle_rad(v1, v2) -> Float64

Calculate the angle between two vectors in radians.

# Arguments
- `v1::AbstractVector` : First vector
- `v2::AbstractVector` : Second vector

# Returns
- `Float64`: Angle between vectors in radians [0, π]

# Notes
- Vectors are automatically normalized before angle calculation
- Uses clamping to handle numerical errors in dot product
- Result is always in range [0, π] regardless of vector orientations

# Example
```julia
# Perpendicular vectors
angle = angle_rad([1, 0, 0], [0, 1, 0])  # Returns π/2

# Opposite vectors
angle = angle_rad([1, 0, 0], [-1, 0, 0])  # Returns π

# Same direction
angle = angle_rad([1, 0, 0], [2, 0, 0])  # Returns 0.0
```

See also: [`angle_deg`](@ref)
"""
angle_rad(v1::AbstractVector{<:Real}, v2::AbstractVector{<:Real}) = acos(clamp(normalize(v1) ⋅ normalize(v2), -1.0, 1.0))

"""
    angle_deg(v1, v2) -> Float64

Calculate the angle between two vectors in degrees.

# Arguments
- `v1::AbstractVector` : First vector
- `v2::AbstractVector` : Second vector

# Returns
- `Float64`: Angle between vectors in degrees [0, 180]

# Notes
This is a convenience function that converts the result of `angle_rad` to degrees.

# Example
```julia
# Perpendicular vectors
angle = angle_deg([1, 0, 0], [0, 1, 0])  # Returns 90.0

# Opposite vectors
angle = angle_deg([1, 0, 0], [-1, 0, 0])  # Returns 180.0

# 45 degree angle
angle = angle_deg([1, 0, 0], [1, 1, 0])  # Returns 45.0
```

See also: [`angle_rad`](@ref)
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

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                       Solar Geometry                              ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    solar_phase_angle(sun, target, observer) -> Float64

Calculate the solar phase angle (sun-target-observer angle).

# Arguments
- `sun::AbstractVector`      : Sun position vector in the same reference frame
- `target::AbstractVector`   : Target (asteroid) position vector
- `observer::AbstractVector` : Observer position vector

# Returns
- `Float64`: Solar phase angle in radians [0, π]

# Notes
The phase angle is a key parameter in asteroid photometry:
- 0° (0 rad)    : Opposition (Sun behind observer)
- 90° (π/2 rad) : Quadrature
- 180° (π rad)  : Conjunction (Sun behind target)

Phase angle affects apparent brightness through phase functions.

# Example
```julia
# Opposition geometry (phase angle ≈ 0)
sun = [1.0, 0.0, 0.0] * 1.496e11       # 1 au from origin
observer = [1.0, 0.0, 0.0] * 1.495e11  # Slightly closer
target = [0.0, 0.0, 0.0]               # At origin
α = solar_phase_angle(sun, target, observer)
println("Phase angle: \$(rad2deg(α))°")  # ≈ 0°

# Quadrature geometry (phase angle = 90°)
observer = [0.0, 1.0, 0.0] * 1.496e11
α = solar_phase_angle(sun, target, observer)
println("Phase angle: \$(rad2deg(α))°")  # = 90°
```

See also: [`solar_elongation_angle`](@ref), [`angle_rad`](@ref)
"""
solar_phase_angle(sun::AbstractVector{<:Real}, target::AbstractVector{<:Real}, observer::AbstractVector{<:Real}) = angle_rad(sun - target, observer - target)

"""
    solar_elongation_angle(sun, observer, target) -> Float64

Calculate the solar elongation angle (sun-observer-target angle).

# Arguments
- `sun::AbstractVector`      : Sun position vector in the same reference frame
- `observer::AbstractVector` : Observer position vector
- `target::AbstractVector`   : Target (asteroid) position vector

# Returns
- `Float64`: Solar elongation angle in radians [0, π]

# Notes
The elongation angle determines observability from Earth:
- 0° (0 rad)    : Conjunction (target near Sun, unobservable)
- 90° (π/2 rad) : Quadrature (good observability)
- 180° (π rad)  : Opposition (best observability)

Objects with small elongation angles are difficult to observe due to
sunlight and proximity to the Sun in the sky.

# Example
```julia
# Near conjunction (small elongation, poor observability)
sun = [1.0, 0.0, 0.0] * 1.496e11  # 1 au
observer = [0.0, 0.0, 0.0]  # Earth at origin
target = [1.1, 0.0, 0.0] * 1.496e11  # Just beyond Sun
ε = solar_elongation_angle(sun, observer, target)
println("Elongation: \$(rad2deg(ε))°")  # Small angle

# Opposition (maximum elongation)
target = [-1.0, 0.0, 0.0] * 1.496e11  # Opposite side from Sun
ε = solar_elongation_angle(sun, observer, target)
println("Elongation: \$(rad2deg(ε))°")  # ≈ 180°
```

See also: [`solar_phase_angle`](@ref), [`angle_rad`](@ref)
"""
solar_elongation_angle(sun::AbstractVector{<:Real}, observer::AbstractVector{<:Real}, target::AbstractVector{<:Real}) = angle_rad(sun - observer, target - observer)
