# AsteroidShapeModels.jl

A Julia package for geometric processing of asteroid shape models.

## Overview

This package consolidates the geometric functionality for asteroid shape models that was duplicated across AsteroidThermoPhysicalModels.jl and FOVSimulator.jl.

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
Pkg.add(url="https://github.com/user/AsteroidShapeModels.jl")
```

## Usage Example

```julia
using AsteroidShapeModels

# Load shape model from OBJ file
shape = load_shape_obj("path/to/asteroid.obj", scale=1000.0)

# Display basic shape information
println(shape)

# Ray-shape intersection detection
ray = Ray([0.0, 0.0, 10.0], [0.0, 0.0, -1.0])
bbox = compute_bounding_box(shape)
result = intersect_ray_shape(ray, shape, bbox)

if result.hit
    println("Intersection point: ", result.point)
    println("Distance: ", result.distance)
    println("Face index: ", result.face_index)
end
```

## License

This project is released under the MIT License.