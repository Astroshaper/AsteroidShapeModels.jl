```@meta
CurrentModule = AsteroidShapeModels
```

# AsteroidShapeModels.jl

```@docs
AsteroidShapeModels
```

## Overview

`AsteroidShapeModels.jl` provides comprehensive tools for working with polyhedral shape models of asteroids. The package supports:

- Loading shape models from OBJ files
- Computing geometric properties (area, volume, normals)
- Ray-shape intersection testing with optional BVH acceleration
- Face-to-face visibility analysis with BVH support
- Surface roughness modeling
- Illumination calculations

## Installation

```julia
using Pkg
Pkg.add("AsteroidShapeModels")
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

# NEW in v0.4.0: Unified illumination API
sun_position = SA[149597870700, 0.0, 0.0]  # Sun 1 au away
illuminated = Vector{Bool}(undef, length(shape.faces))
update_illumination!(illuminated, shape, sun_position; with_self_shadowing=false)

# Access to face properties
shape.face_centers  # Center position of each face
shape.face_normals  # Normal vector of each face
shape.face_areas    # Area of of each face
```

## Features

### Shape Model Management
- Load polyhedral models from OBJ files
- Automatic computation of face centers, normals, and areas
- Support for scaling and coordinate transformations

### Geometric Analysis
- Face properties: center, normal, area
- Shape properties: volume, equivalent radius
- Bounding box computation

### Ray Intersection
- Fast ray-triangle intersection using Möller–Trumbore algorithm
- Ray-shape intersection with optional BVH acceleration (~50x speedup)
- Bounding box culling for efficiency

### Visibility Analysis
- Face-to-face visibility computation with optimized non-BVH algorithm
- View factor calculations for thermal modeling
- Illumination determination with configurable self-shadowing
- Batch illumination updates for all faces
- Binary asteroid mutual shadowing and eclipse detection

### Surface Roughness
- Crater modeling
- Surface curvature analysis

## Package Structure

- `types.jl` - Core data structures and type definitions
- `obj_io.jl` - OBJ file loading and parsing
- `face_properties.jl` - Face geometric computations (center, normal, area)
- `shape_operations.jl` - Shape-level operations (volume, radius calculations)
- `ray_intersection.jl` - Ray casting and intersection algorithms
- `face_visibility_graph.jl` - Face-to-face visibility graph and view factor calculations
- `illumination.jl` - Illumination analysis and shadow testing
- `eclipse_shadowing.jl` - Eclipse shadowing for binary asteroid systems
- `geometry_utils.jl` - Geometric helper functions and angle calculations
- `roughness.jl` - Surface roughness and crater modeling

## Index

```@index
```