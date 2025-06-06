```@meta
CurrentModule = AsteroidShapeModels
```

# AsteroidShapeModels.jl

A Julia package for geometric processing and analysis of asteroid shape models.

## Overview

AsteroidShapeModels.jl provides comprehensive tools for working with polyhedral shape models of asteroids. The package supports:

- Loading shape models from OBJ files
- Computing geometric properties (area, volume, normals)
- Ray-shape intersection testing
- Face-to-face visibility analysis
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

# Load an asteroid shape model with face-face visibility
shape = load_shape_obj("path/to/asteroid.obj", scale=1000, find_visible_facets=true)  # Convert km to m

# Access to face properties
shape.face_centers  # Center position of each face
shape.face_normals  # Normal vector of each face
shape.face_areas    # Area of of each face

# Check illumination
sun_position = SA[1.0, 0.0, 0.0]  # Sun along +x axis
illuminated = isilluminated(shape, sun_position, 1)  # true or false
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
- Fast ray-triangle intersection
- Ray-shape intersection
- Bounding box acceleration

### Visibility Analysis
- Face-to-face visibility computation
- View factor calculations
- Illumination determination

### Surface Roughness
- Crater modeling
- Surface curvature analysis

## Package Structure

- [`types.jl`](@ref) - Core data structures
- [`obj_io.jl`](@ref) - OBJ file I/O
- [`face_properties.jl`](@ref) - Face geometric properties
- [`shape_operations.jl`](@ref) - Shape-level operations
- [`ray_intersection.jl`](@ref) - Ray casting algorithms
- [`visibility.jl`](@ref) - Visibility computations
- [`geometry_utils.jl`](@ref) - Geometric utilities
- [`roughness.jl`](@ref) - Surface roughness modeling

## Index

```@index
```