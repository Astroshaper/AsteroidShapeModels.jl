# Tutorial

This tutorial demonstrates the main features of AsteroidShapeModels.jl through practical examples.

## Loading a Shape Model

```julia
using AsteroidShapeModels
using StaticArrays

# Load from OBJ file
shape = load_shape_obj("path/to/shape.obj")

# Load with scaling (e.g., converting km to m)
shape_m = load_shape_obj("path/to/shape.obj"; scale=1000)

# Access shape properties
println("Number of nodes : $(length(shape.nodes))")
println("Number of faces : $(length(shape.faces))")
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

println("Volume            : $volume m³")
println("Equivalent radius : $eq_radius m")
println("Maximum radius    : $max_radius m")
println("Minimum radius    : $min_radius m")
```

## Face Visibility Analysis

```julia
# Load shape with face visibility computation
shape_vis = load_shape_obj("path/to/shape.obj"; scale=1000, with_face_visibility=true)

# Or build visibility graph for existing shape
build_face_visibility_graph!(shape)

# Access visibility data for a specific face
face_id = 100
visible_faces = get_visible_face_indices(shape.face_visibility_graph, face_id)
view_factors = get_view_factors(shape.face_visibility_graph, face_id)
num_visible = num_visible_faces(shape.face_visibility_graph, face_id)

println("Face $face_id can see $num_visible other faces.")
println("Total view factor: ", sum(view_factors))

# Check if a face is illuminated by the sun
sun_position = SA[1.5e11, 0.0, 0.0]  # Sun 1 au away along x-axis

# Without self-shadowing (pseudo-convex model)
illuminated = isilluminated(shape, sun_position, face_id; with_self_shadowing=false)
println("Face $face_id is ", illuminated ? "illuminated" : "in shadow")

# With self-shadowing (requires `face_visibility_graph` to be built)
illuminated = isilluminated(shape_vis, sun_position, face_id; with_self_shadowing=true)
println("Face $face_id is ", illuminated ? "illuminated" : "in shadow")
```

## Batch Illumination Updates

```julia
# Efficiently update illumination state for all faces
illuminated = Vector{Bool}(undef, length(shape.faces))

# Without self-shadowing (fast, pseudo-convex model)
update_illumination!(illuminated, shape, sun_position; with_self_shadowing=false)
n_illuminated = count(illuminated)
println("$n_illuminated faces are illuminated (pseudo-convex model).")

# With self-shadowing (requires `face_visibility_graph` to be built)
update_illumination!(illuminated, shape_vis, sun_position; with_self_shadowing=true)
n_illuminated = count(illuminated)
println("$n_illuminated faces are illuminated (with self-shadowing).")
```

## Binary Asteroid Shadowing

```julia
# For binary asteroid systems, check mutual shadowing effects
# Assume we have two shape models: shape1 (primary) and shape2 (secondary)
shape1 = load_shape_obj("primary_shape.obj"; scale=1000, with_face_visibility=true, with_bvh=true)
shape2 = load_shape_obj("secondary_shape.obj"; scale=1000, with_face_visibility=true, with_bvh=true)

# Define relative position and orientation
# R12: rotation from shape1 frame to shape2 frame
# R21: rotation from shape2 frame to shape1 frame
# t12: translation from shape1 origin to shape2 origin
# t21: translation from shape2 origin to shape1 origin
R12 = SA[1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]  # Identity (no rotation)
t12 = SA[2000.0, 0.0, 0.0]  # 2 km separation

R21 = R12'         # Inverse rotation
t21 = -R12' * t12  # Inverse translation

# Sun position in each body's frame
sun_position1 = SA[1.5e11, 0.0, 0.0]
sun_position2 = sun_position1 - t12  # Transform to shape2's frame

# First, check self-shadowing for each body
illuminated1 = Vector{Bool}(undef, length(shape1.faces))
illuminated2 = Vector{Bool}(undef, length(shape2.faces))
update_illumination!(illuminated1, shape1, sun_position1; with_self_shadowing=true)
update_illumination!(illuminated2, shape2, sun_position2; with_self_shadowing=true)

# Then apply mutual shadowing
status1 = apply_eclipse_shadowing!(illuminated1, shape1, sun_position1, R12, t12, shape2)
status2 = apply_eclipse_shadowing!(illuminated2, shape2, sun_position2, R21, t21, shape1)

# Check eclipse status
if status1 == NO_ECLIPSE
    println("Primary is not eclipsed by secondary.")
elseif status1 == PARTIAL_ECLIPSE
    println("Primary is partially eclipsed by secondary.")
elseif status1 == TOTAL_ECLIPSE
    println("Primary is totally eclipsed by secondary.")
end
```

## Ray-Shape Intersection

### Single Ray

```julia
# Ensure BVH is built for ray intersection
if isnothing(shape.bvh)
    build_bvh!(shape)
end

# Define a ray
origin = SA[1000.0, 0.0, 0.0]  # Start 1 km away
direction = normalize(SA[-1.0, 0.0, 0.0])  # Point toward origin
ray = Ray(origin, direction)

# Find intersection with shape
result = intersect_ray_shape(ray, shape)

if result.hit
    println("Ray hit face $(result.face_index) at distance $(result.distance).")
    println("Hit point: ", result.point)
else
    println("Ray missed the shape.")
end
```

### Batch Ray Processing

```julia
# Process multiple rays efficiently
rays = [Ray(SA[x, 0.0, 1000.0], SA[0.0, 0.0, -1.0]) for x in -500:100:500]
results = intersect_ray_shape(rays, shape)

# Count hits
n_hits = count(r -> r.hit, results)
println("$n_hits out of $(length(rays)) rays hit the shape.")

# Process rays in a grid pattern
ray_grid = [Ray(SA[x, y, 1000.0], SA[0.0, 0.0, -1.0]) 
            for x in -500:100:500, y in -500:100:500]
result_grid = intersect_ray_shape(ray_grid, shape)

# Results maintain the same shape as input
@assert size(result_grid) == size(ray_grid)

# Alternative: Use matrix interface for maximum performance
n_rays = 100
origins = rand(3, n_rays) .* 2000 .- 1000  # Random origins
directions = normalize.(eachcol(rand(3, n_rays) .- 0.5))
directions = hcat(directions...)  # Convert back to matrix

results = intersect_ray_shape(shape, origins, directions)
```

## Performance Tips

1. **Use StaticArrays**: All vector operations use `SVector` for performance
2. **Batch operations**: Process multiple rays together using vector/matrix interfaces:
   - `intersect_ray_shape(rays::Vector{Ray}, shape)` for ray collections
   - `intersect_ray_shape(rays::Matrix{Ray}, shape)` preserves grid structure
   - `intersect_ray_shape(shape, origins, directions)` for maximum performance
3. **BVH acceleration**: Must be pre-built using `build_bvh!(shape)` or `with_bvh=true` when loading a shape model
4. **Scale appropriately**: Use consistent units (typically meters)
5. **Precompute visibility**: Use `with_face_visibility=true` when loading if you need visibility analysis
6. **Access patterns**: The face visibility graph uses CSR format - sequential access is faster than random

## Next Steps

- See the API Reference pages for detailed function documentation
- Check the test suite for more examples
- Explore integration with [SPICE.jl](https://github.com/JuliaAstro/SPICE.jl) for ephemeris data
