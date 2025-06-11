# Tutorial

This tutorial demonstrates the main features of AsteroidShapeModels.jl through practical examples.

## Loading a Shape Model

```julia
using AsteroidShapeModels
using StaticArrays

# Load from OBJ file
shape = load_shape_obj("asteroid.obj")

# Load with scaling (e.g., converting km to m)
shape_m = load_shape_obj("asteroid.obj", scale=1000)

# Access shape properties
println("Number of vertices: ", length(shape.vertices))
println("Number of faces: ", length(shape.faces))
println("Number of edges: ", length(shape.edges))
```

## Working with Face Properties

```julia
shape.face_centers  # Center position of each face
shape.face_normals  # Normal vector of each face
shape.face_areas    # Area of of each face

# Get properties of face 1
shape.face_centers[1]  # Center position of each face
shape.face_normals[1]  # Normal vector of each face
shape.face_areas[1]    # Area of of each face
```

## Shape Analysis

```julia
# Compute shape properties
volume = polyhedron_volume(shape)
eq_radius = equivalent_radius(shape)
max_radius = maximum_radius(shape)
min_radius = minimum_radius(shape)

println("Volume: ", volume, " m³")
println("Equivalent radius: ", eq_radius, " m")
println("Maximum radius: ", max_radius, " m")
println("Minimum radius: ", min_radius, " m")
println("Axis ratio (max/min): ", max_radius / min_radius)

# Compute bounding box
bbox = compute_bounding_box(shape)
```

## Performance Tips

1. **Use StaticArrays**: All vector operations use `SVector` for performance
2. **Batch operations**: Process multiple rays or faces together
3. **Scale appropriately**: Use consistent units (typically meters)

## Next Steps

- See the API Reference pages for detailed function documentation
- Check the test suite for more examples
- Explore integration with [SPICE.jl](https://github.com/JuliaAstro/SPICE.jl) for ephemeris data