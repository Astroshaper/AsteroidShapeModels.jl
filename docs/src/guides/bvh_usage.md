# BVH (Bounding Volume Hierarchy) Usage Guide

```@meta
CurrentModule = AsteroidShapeModels
```

## Overview

`AsteroidShapeModels.jl` uses BVH (Bounding Volume Hierarchy) acceleration structures to optimize ray-shape intersection operations. The BVH implementation is provided by the [ImplicitBVH.jl](https://github.com/StellaOrg/ImplicitBVH.jl) package and is automatically utilized for optimal performance.

## How BVH is Used

### Fixed Optimal Implementations

Each operation in the package uses a fixed implementation that has been determined to be optimal through benchmarking:

- **Ray-shape intersection**: Uses BVH implementation (~50x speedup over naive approach)
- **Face visibility graph**: Uses non-BVH algorithm with candidate filtering (2x faster than BVH)
- **Illumination checks**: Uses non-BVH implementation with precomputed visibility graph

These implementations are not user-configurable - the package uses the proven fastest approach for each operation.

### When to Use `with_bvh=true`

The `with_bvh` parameter in `load_shape_obj` controls whether the BVH is built during model loading:

```julia
# Build BVH during loading (recommended for ray tracing applications)
shape = load_shape_obj("path/to/shape.obj"; scale=1000, with_bvh=true)

# Load without BVH (BVH will be built on first ray intersection)
shape = load_shape_obj("path/to/shape.obj"; scale=1000, with_bvh=false)
# or simply omit the parameter (default is `with_bvh=false`):
shape = load_shape_obj("path/to/shape.obj"; scale=1000)
```

Use `with_bvh=true` when:
- You plan to perform many ray intersections
- You want predictable performance (avoid first-call overhead)
- You're building a ray tracing application

### Manual BVH Construction

You can also build the BVH manually after loading:

```julia
shape = load_shape_obj("asteroid.obj"; scale=1000)
build_bvh!(shape)  # Build BVH in-place
```

## Performance Characteristics

### Ray Intersection Performance

With BVH acceleration:
- Single ray: ~3-5 μs per intersection (for 50k face models)
- Complexity: O(log n) where n is the number of faces
- Memory overhead: ~100-200 bytes per face

Without BVH (first call only):
- Additional overhead for BVH construction
- Subsequent calls use the cached BVH

### Batch Processing

For multiple rays, use batch processing for optimal performance:

```julia
# Process multiple rays efficiently
rays = [Ray(origin, direction) for ...]

# Vector of rays - returns vector of results
results = intersect_ray_shape(rays, shape)

# Matrix of rays - preserves grid structure
ray_grid = [Ray(...) for x in 1:nx, y in 1:ny]
result_grid = intersect_ray_shape(ray_grid, shape)

# Raw arrays for maximum performance
origins    = zeros(3, n_rays)  # Each column is a ray origin
directions = zeros(3, n_rays)  # Each column is a ray direction
# ... fill arrays ...
results = intersect_ray_shape(shape, origins, directions)
```

## Implementation Details

### Why Different Algorithms for Different Operations?

1. **Ray intersection**: BVH excels at single ray queries by quickly eliminating non-intersecting faces
   
2. **Face visibility**: Non-BVH algorithm with candidate filtering is more efficient because:
   - It processes many face pairs simultaneously
   - Distance-based sorting provides natural occlusion culling
   - The specific geometry of face-to-face visibility favors this approach

3. **Illumination**: Leverages precomputed visibility graph for O(1) lookup of potentially occluding faces

### Memory Considerations

The BVH structure requires additional memory:
- Tree nodes: ~32 bytes per face
- Bounding boxes: ~24 bytes per face
- Total overhead: ~100-200 bytes per face (depending on tree depth)

For a 50k face model, expect ~5-10 MB additional memory usage.

## Example: Ray Tracing Application

```julia
using AsteroidShapeModels
using StaticArrays

# Load model with BVH for ray tracing
shape = load_shape_obj("path/to/shape.obj"; scale=1000, with_bvh=true)

# Camera rays for rendering
function render_image(shape, camera_pos, camera_dir, width, height)
    rays = Matrix{Ray}(undef, height, width)
    
    # Generate camera rays
    for y in 1:height, x in 1:width
        # ... compute ray direction ...
        rays[y, x] = Ray(camera_pos, ray_dir)
    end
    
    # Batch process all rays
    intersections = intersect_ray_shape(rays, shape)
    
    # Process results
    image = zeros(height, width)
    for y in 1:height, x in 1:width
        if intersections[y, x].hit
            # Compute shading, distance, etc.
            image[y, x] = compute_pixel_value(intersections[y, x])
        end
    end
    
    return image
end
```

## Best Practices

1. **Preload BVH** for ray tracing applications using `with_bvh=true`
2. **Use batch processing** when intersecting multiple rays
3. **Let the package choose** the optimal algorithm for each operation
4. **Monitor memory usage** for very large models (>1M faces)

## See Also

- [`intersect_ray_shape`](@ref) - Ray-shape intersection function
- [`build_bvh!`](@ref) - Manual BVH construction
- [Performance Tips](../tutorial.md#performance-tips) - General optimization guidelines
