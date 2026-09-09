#=
    roughness.jl

This file provides functions for modeling surface roughness features on asteroids,
particularly focusing on crater geometries. Surface roughness significantly affects
thermal properties, light scattering, and radar reflection characteristics of
asteroid surfaces.

Exported Functions:
- `crater_curvature_radius`: Calculate the curvature radius of a concave spherical segment
- `concave_spherical_segment`: Generate crater geometry as a concave spherical segment
- `create_shape_crater`: Create a ShapeModel of a concave spherical crater
- `projected_area`: Area of a surface patch projected along the local z-axis
- `rms_slope`: RMS slope of a surface patch (Rozitis & Green 2011, Eq. 36)
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                  Concave spherical segment                        ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    crater_curvature_radius(r, h) -> R

!!! note "TODO (v0.6.0)"
    This function will be made internal (unexported) in v0.6.0.

Calculate the curvature radius of a concave spherical segment.

# Arguments
- `r::Real`: Crater radius (same units as h)
- `h::Real`: Crater depth (same units as r)

# Returns
- `R::Real`: Curvature radius of the spherical segment

# Notes
The curvature radius is calculated using the formula: `R = (r² + h²) / 2h`
This represents the radius of the sphere from which the crater segment is cut.

# Example
```julia
# Small bowl-shaped crater: 100m radius, 10m deep
R = crater_curvature_radius(100.0, 10.0)  # Returns 505.0 m

# Deeper crater (smaller curvature radius): 100m radius, 50m deep
R = crater_curvature_radius(100.0, 50.0)  # Returns 125.0 m
```

See also: [`concave_spherical_segment`](@ref)
"""
crater_curvature_radius(r::Real, h::Real) = (r^2 + h^2) / 2h

"""
    concave_spherical_segment(r, h, xc, yc, x, y) -> z

!!! note "TODO (v0.6.0)"
    This function will be renamed to `concave_spherical_segment_depth` and made internal (unexported) in v0.6.0.

Calculate the z-coordinate (depth) of a concave spherical segment at a given (x,y) position.

# Arguments
- `r::Real`  : Crater radius
- `h::Real`  : Crater depth (maximum depth at center)
- `xc::Real` : x-coordinate of crater center
- `yc::Real` : y-coordinate of crater center
- `x::Real`  : x-coordinate where to calculate z
- `y::Real`  : y-coordinate where to calculate z

# Returns
- `z::Real`: Depth below the surface (negative value inside, 0 outside crater)

# Notes
- Returns 0 for points outside the crater radius
- The crater profile follows a spherical cap geometry
- All spatial parameters should use consistent units

# Example
```julia
# Crater at origin with 10m radius and 2m depth
z_center = concave_spherical_segment(10.0, 2.0, 0.0, 0.0, 0.0, 0.0)   # Returns -2.0
z_edge   = concave_spherical_segment(10.0, 2.0, 0.0, 0.0, 10.0, 0.0)  # Returns 0.0
z_mid    = concave_spherical_segment(10.0, 2.0, 0.0, 0.0, 5.0, 0.0)   # Returns ~-0.6
```

See also: [`crater_curvature_radius`](@ref)
"""
function concave_spherical_segment(r::Real, h::Real, xc::Real, yc::Real, x::Real, y::Real)
    d² = (x - xc)^2 + (y - yc)^2
    d = √d²  # Distance from the crater center

    if d > r
        z = 0.
    else
        R = crater_curvature_radius(r, h)
        z = R - h - √(R^2 - d²)
    end
    z
end

"""
    concave_spherical_segment(r, h; xc=0.5, yc=0.5, Nx=2^5, Ny=2^5) -> xs, ys, zs

!!! note "TODO (v0.6.0)"
    This function will be renamed to `concave_spherical_segment_grid` and made internal (unexported) in v0.6.0.

Generate a grid representation of a concave spherical segment (crater).

# Arguments
- `r::Real` : Crater radius (in normalized units, typically 0-1)
- `h::Real` : Crater depth (in same units as radius)

# Keyword Arguments
- `xc::Real=0.5`   : x-coordinate of crater center (normalized, 0-1)
- `yc::Real=0.5`   : y-coordinate of crater center (normalized, 0-1)
- `Nx::Integer=32` : Number of grid points in x-direction (default: 2^5)
- `Ny::Integer=32` : Number of grid points in y-direction (default: 2^5)

# Returns
- `xs::LinRange`: x-coordinates of grid points (0 to 1)
- `ys::LinRange`: y-coordinates of grid points (0 to 1)
- `zs::Matrix`  : z-coordinates (depths) at each grid point

# Notes
- The grid spans a unit square [0,1] × [0,1]
- z-values are negative inside the crater, 0 outside
- Suitable for use with `load_shape_grid` to create crater shape models

# Example
```julia
# Generate a crater covering 40% of the domain, 0.1 units deep
xs, ys, zs = concave_spherical_segment(0.4, 0.1; Nx=64, Ny=64)

# Convert to shape model
shape = load_shape_grid(xs, ys, zs)

# Off-center crater
xs, ys, zs = concave_spherical_segment(0.3, 0.05; xc=0.3, yc=0.7)
```

See also: [`load_shape_grid`](@ref), [`grid_to_faces`](@ref)
"""
function concave_spherical_segment(r::Real, h::Real; xc::Real=0.5, yc::Real=0.5, Nx::Integer=2^5, Ny::Integer=2^5)
    xs = LinRange(0, 1, Nx + 1)
    ys = LinRange(0, 1, Ny + 1)
    zs = [concave_spherical_segment(r, h, xc, yc, x, y) for x in xs, y in ys]

    xs, ys, zs
end

"""
    create_shape_crater(r, h;
        xc = 0.5,
        yc = 0.5,
        Nx = 32,
        Ny = 32,
        scale = 1.0,
        with_face_visibility = false,
        with_bvh = false,
        as_hierarchical = false,
    ) -> Union{ShapeModel, HierarchicalShapeModel}

Create a shape model representing a concave spherical crater.

This is a convenience wrapper that combines [`concave_spherical_segment`](@ref) and
[`load_shape_grid`](@ref). The crater sits on a unit square [0,1]×[0,1].

# Arguments
- `r::Real`: Crater radius in normalized units (0–1). A value of 0.5 fills the unit square.
- `h::Real`: Crater depth in the same units as `r`.

# Keyword Arguments
- `xc::Real=0.5`                     : x-coordinate of crater center (normalized, 0–1)
- `yc::Real=0.5`                     : y-coordinate of crater center (normalized, 0–1)
- `Nx::Integer=32`                   : Number of grid points in x-direction
- `Ny::Integer=32`                   : Number of grid points in y-direction
- `scale::Real=1.0`                  : Scale factor applied to all coordinates after grid generation
- `with_face_visibility::Bool=false` : Whether to build face-to-face visibility graph
- `with_bvh::Bool=false`             : Whether to build BVH for ray tracing
- `as_hierarchical::Bool=false`      : Whether to return a `HierarchicalShapeModel` instead of a `ShapeModel`

# Returns
- `ShapeModel` or `HierarchicalShapeModel`: Shape model with computed geometric properties (centers, normals, areas)

# Example
```julia
# Crater centered at (0.5, 0.5) with radius 0.4 and depth 0.1, scaled to meters
crater = create_shape_crater(0.4, 0.1; scale=100.0, with_face_visibility=true)

# Off-center crater with higher resolution
crater = create_shape_crater(0.3, 0.1; xc=0.3, yc=0.7, Nx=64, Ny=64)

# As HierarchicalShapeModel
crater = create_shape_crater(0.4, 0.1; as_hierarchical=true)
```

See also: [`concave_spherical_segment`](@ref), [`load_shape_grid`](@ref)
"""
function create_shape_crater(r::Real, h::Real;
    xc::Real = 0.5,
    yc::Real = 0.5,
    Nx::Integer = 32,
    Ny::Integer = 32,
    scale::Real = 1.0,
    with_face_visibility::Bool = false,
    with_bvh::Bool = false,
    as_hierarchical::Bool = false,
)::Union{ShapeModel, HierarchicalShapeModel}
    xs, ys, zs = concave_spherical_segment(r, h; xc, yc, Nx, Ny)
    load_shape_grid(xs, ys, zs; scale, with_face_visibility, with_bvh, as_hierarchical)
end


# ╔═══════════════════════════════════════════════════════════════════╗
# ║                 Parallel sinusoidal trenches                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

# function parallel_sinusoidal_trenches(Ct, N_trench, x)
#     z = Ct + Ct * sin(2π * (N_trench + 0.5) * x)
# end

# function parallel_sinusoidal_trenches(Ct, N_trench; Nx=2^5, Ny=2^5)
#     xs = LinRange(0, 1, Nx + 1)
#     ys = LinRange(0, 1, Ny + 1)
#     zs = [parallel_sinusoidal_trenches(Ct, N_trench, x) for x in xs, y in ys]

#     xs, ys, zs 
# end


# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Random Gaussian surface                         ║
# ╚═══════════════════════════════════════════════════════════════════╝

# TODO: Functions to generate random Gaussian surface will be implmented.


# ╔═══════════════════════════════════════════════════════════════════╗
# ║                       Fractal surface                             ║
# ╚═══════════════════════════════════════════════════════════════════╝

# TODO: Functions to generate fractal surface will be implmented.


# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Roughness statistics                         ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    projected_area(shape::ShapeModel) -> A_proj

Compute the area of the shape projected onto the local xy-plane (i.e., along
the local z-axis, which corresponds to the mean surface normal for a roughness
patch):

```math
A_{\\mathrm{proj}} = \\sum_j a_j \\, (\\hat{n}_j \\cdot \\hat{z})^+
```

where ``a_j`` is the area of face ``j``, ``\\hat{n}_j`` its unit normal, and
``(x)^+ = \\max(x, 0)`` so that faces tilted away from the z-axis (overhangs)
do not contribute.

For a roughness patch built on the unit square ``[0,1] \\times [0,1]`` (e.g.,
[`create_shape_crater`](@ref)), the projected area equals 1 regardless of the
roughness, since the z-projection of the surface covers the unit square exactly.
This quantity is used to normalize energy fluxes of a representative roughness
patch in thermophysical modeling.

# Arguments
- `shape::ShapeModel`: Shape model of a surface patch

# Returns
- `A_proj::Float64`: Projected area along the local z-axis

See also: [`rms_slope`](@ref)
"""
function projected_area(shape::ShapeModel)
    A_proj = 0.0
    for (n̂, a) in zip(shape.face_normals, shape.face_areas)
        A_proj += a * max(n̂[3], 0.0)
    end
    A_proj
end

"""
    rms_slope(shape::ShapeModel) -> θ_RMS

Compute the root-mean-square (RMS) slope of a surface patch, following the
standard definition in thermal-infrared beaming studies
(Spencer, 1990; Rozitis & Green, 2011, Eq. 36):

```math
\\theta_{\\mathrm{RMS}} = \\sqrt{\\frac{\\sum_j \\theta_j^2 \\, a_j \\cos\\theta_j}{\\sum_j a_j \\cos\\theta_j}},
\\qquad \\theta_j = \\arccos(\\hat{n}_j \\cdot \\hat{z})
```

where ``\\theta_j`` is the slope angle of face ``j`` measured from the local
z-axis, ``a_j`` its area, and the weight ``a_j \\cos\\theta_j`` is the projected
(z-projected) area of the face. Faces tilted away from the z-axis
(``\\cos\\theta_j \\le 0``) are excluded.

# Arguments
- `shape::ShapeModel`: Shape model of a surface patch

# Returns
- `θ_RMS::Float64`: RMS slope in radians (use `rad2deg` for degrees)

# Notes
- The statistic is taken over the **entire patch, including flat portions**.
  For a crater patch built on the unit square (e.g., [`create_shape_crater`](@ref)),
  the flat apron contributes zero slope but full weight, so the roughness
  fraction ``\\sqrt{f_R}`` of Rozitis & Green (2011, Eq. 37) is automatically
  included. To get the RMS slope of the cratered part alone, divide by the
  square root of the projected areal coverage: `rms_slope(shape) / √(π * r^2)`
  for a crater of normalized radius `r` (approximate on a discrete grid, where
  the rim discretization makes the actual coverage slightly larger than `π * r^2`).
- This is **not** Hapke's mean slope angle ``\\bar{\\theta}``, which uses a
  different (tangent-based) definition.

# References
- Spencer, J. R. (1990), Icarus 83, 27
- Rozitis, B. & Green, S. F. (2011), MNRAS 415, 2042, Eqs. (36)–(37)

# Example
```julia
crater = create_shape_crater(0.4, 0.4; Nx=64, Ny=64)  # hemispherical crater
rad2deg(rms_slope(crater))  # ≈ 36.5° (whole patch, flat apron included)
```

See also: [`projected_area`](@ref)
"""
function rms_slope(shape::ShapeModel)
    num = 0.0
    den = 0.0
    for (n̂, a) in zip(shape.face_normals, shape.face_areas)
        cosθ = clamp(n̂[3], -1.0, 1.0)
        cosθ ≤ 0 && continue
        θ = acos(cosθ)
        w = a * cosθ
        num += θ^2 * w
        den += w
    end
    den == 0 && return 0.0
    √(num / den)
end
