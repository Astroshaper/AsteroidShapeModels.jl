# AsteroidShapeModels.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://astroshaper.github.io/AsteroidShapeModels.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroshaper.github.io/AsteroidShapeModels.jl/dev/)
[![Build Status](https://github.com/Astroshaper/AsteroidShapeModels.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Astroshaper/AsteroidShapeModels.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Astroshaper/AsteroidShapeModels.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Astroshaper/AsteroidShapeModels.jl)

A Julia package for geometric processing of asteroid shape models.

## Overview

AsteroidShapeModels.jl provides comprehensive tools for working with polyhedral shape models of asteroids. This package consolidates the geometric functionality that was previously duplicated across multiple asteroid analysis packages.

## Key Features

- **Shape Model Loading**: Load 3D models in OBJ file format
- **Face Geometric Properties**: Calculate face centers, normal vectors, and areas
- **Ray Intersection Detection**: High-precision ray-triangle intersection using the Möller–Trumbore algorithm
- **Bounding Boxes**: Boundary boxes for efficient collision detection
- **Visibility Analysis**: Calculate visibility and view factors between faces
- **Shape Characteristics**: Calculate volume, equivalent radius, maximum and minimum radii

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/Astroshaper/AsteroidShapeModels.jl")
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
```

## Documentation

For detailed usage and API reference, please visit the [documentation](https://astroshaper.github.io/AsteroidShapeModels.jl/dev/).

## License

This project is released under the MIT License.
