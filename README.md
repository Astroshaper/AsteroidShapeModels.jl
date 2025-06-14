# AsteroidShapeModels.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://astroshaper.github.io/AsteroidShapeModels.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroshaper.github.io/AsteroidShapeModels.jl/dev/)
[![Build Status](https://github.com/Astroshaper/AsteroidShapeModels.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Astroshaper/AsteroidShapeModels.jl/actions/workflows/ci.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Astroshaper/AsteroidShapeModels.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Astroshaper/AsteroidShapeModels.jl)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/A/AsteroidShapeModels.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/report.html)

A Julia package for geometric processing of asteroid shape models.

## Overview

`AsteroidShapeModels.jl` provides comprehensive tools for working with polyhedral shape models of asteroids. This package consolidates the geometric functionality that was previously duplicated across multiple asteroid analysis packages.

## Key Features

- **Shape Model Loading**: Load 3D models in OBJ file format
- **Face Geometric Properties**: Calculate face centers, normal vectors, and areas
- **Ray Intersection Detection**: High-precision ray-triangle intersection using the Möller–Trumbore algorithm
- **Bounding Boxes**: Boundary boxes for efficient collision detection
- **Visibility Analysis**: Calculate visibility and view factors between faces
- **Shape Characteristics**: Calculate volume, equivalent radius, maximum and minimum radii

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

# Load an asteroid shape model with face-face visibility
shape = load_shape_obj("path/to/shape.obj", scale=1000, find_visible_facets=true)  # Convert km to m

# Access to face properties
shape.face_centers  # Center position of each face
shape.face_normals  # Normal vector of each face
shape.face_areas    # Area of of each face
```

## Documentation

For detailed documentation, please visit:
- [Stable Documentation](https://Astroshaper.github.io/AsteroidShapeModels.jl/stable)
- [Development Documentation](https://Astroshaper.github.io/AsteroidShapeModels.jl/dev)

## License

This project is released under the MIT License.
