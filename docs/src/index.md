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

# Load an asteroid shape model with face-face visibility
shape = load_shape_obj("path/to/shape.obj", scale=1000, with_face_visibility=true)  # Convert km to m

# NEW: Load with BVH acceleration for ray tracing
shape_bvh = load_shape_obj("path/to/shape.obj", scale=1000, with_bvh=true)

# Or build BVH for an existing shape
build_bvh!(shape)

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
- Face-to-face visibility computation with BVH support
- View factor calculations for thermal modeling
- Illumination determination with BVH-based shadow testing (The current BVH option is slower than the non-BVH version.)

### Surface Roughness
- Crater modeling
- Surface curvature analysis

## Package Structure

- `types.jl` - Core data structures and type definitions
- `obj_io.jl` - OBJ file loading and parsing
- `face_properties.jl` - Face geometric computations (center, normal, area)
- `shape_operations.jl` - Shape-level operations (volume, radius calculations)
- `ray_intersection.jl` - Ray casting and intersection algorithms
- `visibility.jl` - Face-to-face visibility and illumination analysis
- `geometry_utils.jl` - Geometric helper functions and angle calculations
- `roughness.jl` - Surface roughness and crater modeling

## Index

```@index
```