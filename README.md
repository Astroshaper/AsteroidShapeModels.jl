# AsteroidShapeModels.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://astroshaper.github.io/AsteroidShapeModels.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroshaper.github.io/AsteroidShapeModels.jl/dev/)
[![Build Status](https://github.com/Astroshaper/AsteroidShapeModels.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Astroshaper/AsteroidShapeModels.jl/actions/workflows/ci.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Astroshaper/AsteroidShapeModels.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Astroshaper/AsteroidShapeModels.jl)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/A/AsteroidShapeModels.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/report.html)

A Julia package for geometric processing of asteroid shape models.

## Overview

`AsteroidShapeModels.jl` provides comprehensive tools for working with polyhedral shape models of asteroids. This package consolidates the geometric functionality that was previously duplicated across multiple asteroid analysis packages.

For detailed documentation, please visit:
- [Stable Documentation](https://Astroshaper.github.io/AsteroidShapeModels.jl/stable)
- [Development Documentation](https://Astroshaper.github.io/AsteroidShapeModels.jl/dev)

For future development plans, see our [Development Roadmap](ROADMAP.md).

## Key Features

- **Shape Model Loading**: Load 3D models in OBJ file format
- **Geometric Properties**:
  - Face properties: Calculate face centers, normal vectors, and areas
  - Shape properties: Compute volume, equivalent radius, and maximum/minimum radii
- **Ray Intersection Detection**: High-precision ray-triangle intersection using the Möller–Trumbore algorithm with BVH (Bounding Volume Hierarchy) acceleration for efficient computation
  - **Batch Ray Processing**: Process multiple rays efficiently in vectors or matrices while preserving input structure
- **Visibility Analysis**: Calculate visibility and view factors between faces
  - Optimized non-BVH algorithm with candidate filtering for face-to-face visibility
  - Distance-based sorting provides ~2x speedup over naive approaches
- **Illumination Analysis**: Determine face illumination states with flexible shadowing models
  - Pseudo-convex model for fast computation (only face orientation check)
  - Self-shadowing model for accurate shading (considers occlusions from other faces)
  - Mutual shadowing (eclipse) detection for a binary asteroid

## What's New in v0.4.2

- **Performance Optimization**: Face maximum elevation pre-computation provides ~2.5x speedup for illumination calculations with self-shadowing
- **Enhanced Eclipse Detection**: More accurate total eclipse detection for non-spherical shapes
- **Ray-Sphere Utilities**: New geometric utilities for cleaner eclipse calculations

For detailed migration instructions between versions, see the [Migration Guide](https://astroshaper.github.io/AsteroidShapeModels.jl/dev/guides/migration/).

## Requirements

- Julia 1.10 or later

## Installation

The package is registered in the [General Julia registry](https://github.com/JuliaRegistries/General) and can be installed with:

```julia
using Pkg
Pkg.add("AsteroidShapeModels")
```

Or from the Julia REPL:

```julia
julia> ]  # Press ] to enter package mode
pkg> add AsteroidShapeModels
```

## Quick Start

```julia
using AsteroidShapeModels
using StaticArrays

# Load an asteroid shape model
# - `path/to/shape.obj` is the path to your OBJ file (mandatory)
# - `scale` : scale factor for the shape model (e.g., 1000 for km to m conversion)
# - `with_face_visibility` : whether to build face-to-face visibility graph for illumination checking and thermophysical modeling
# - `with_bvh` : whether to build BVH for ray tracing
shape = load_shape_obj("path/to/shape.obj"; scale=1000, with_face_visibility=true, with_bvh=true)

# Or you can build face-face visibility graph and/or BVH for an existing shape
# build_face_visibility_graph!(shape)
# build_bvh!(shape)

# Access to face properties
shape.face_centers  # Center position of each face
shape.face_normals  # Normal vector of each face
shape.face_areas    # Area of of each face

# Single ray intersection (requires BVH to be built)
ray = Ray(SA[1000.0, 0.0, 0.0], SA[-1.0, 0.0, 0.0])
result = intersect_ray_shape(ray, shape)

# Batch ray processing (NEW in v0.4.0)
rays = [Ray(SA[x, 0.0, 1000.0], SA[0.0, 0.0, -1.0]) for x in -500:100:500]
results = intersect_ray_shape(rays, shape)

# Illumination analysis (NEW in v0.4.0)
sun_position = SA[149597870700, 0.0, 0.0]  # Sun 1 au away
face_idx = 100

# Check single face illumination
illuminated = isilluminated(shape, sun_position, face_idx; with_self_shadowing=true)

# Batch update all faces
illuminated_faces = Vector{Bool}(undef, length(shape.faces))
update_illumination!(illuminated_faces, shape, sun_position; with_self_shadowing=true)

# Binary asteroid mutual shadowing (NEW in v0.4.1)
# For eclipse detection in binary systems
shape1 = load_shape_obj("primary.obj"; scale=1000, with_bvh=true)
shape2 = load_shape_obj("secondary.obj"; scale=1000, with_bvh=true)

# Positions and orientations from e.g., SPICE
sun_pos1 = SA[149597870700, 0.0, 0.0]  # Sun position in primary's frame
secondary_pos = SA[2000.0, 0.0, 0.0]     # Secondary's position in primary's frame
P2S = SA[1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]  # Rotation matrix

# Check for eclipse shadowing
status = apply_eclipse_shadowing!(illuminated_faces, shape1, shape2, sun_pos1, secondary_pos, P2S)
# Returns: NO_ECLIPSE, PARTIAL_ECLIPSE, or TOTAL_ECLIPSE
```

## License

This project is released under the MIT License.
