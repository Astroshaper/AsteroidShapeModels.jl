# Migration Guide

This guide helps you migrate your code when upgrading between major versions of `AsteroidShapeModels.jl`.

## Getting Help

If you encounter issues during migration:

1. Check the [CHANGELOG](https://github.com/Astroshaper/AsteroidShapeModels.jl/blob/main/CHANGELOG.md) for detailed changes
2. Review the [API documentation](https://astroshaper.github.io/AsteroidShapeModels.jl/stable)
3. Open an [issue](https://github.com/Astroshaper/AsteroidShapeModels.jl/issues) on GitHub

## Future Deprecations

No planned deprecations at this time.

## Migrating to v0.5.0 (Unreleased)

### New Features

#### Hierarchical Shape Models

v0.5.0 introduces `HierarchicalShapeModel` for multi-scale surface representation:

```julia
# Create hierarchical model from global shape
hier_shape = HierarchicalShapeModel(global_shape)

# Add roughness models to specific faces
roughness = load_shape_obj("roughness.obj", scale=10)
add_roughness_models!(hier_shape, roughness, face_idx; scale=0.01)

# Transform between global and local coordinates
p_local = transform_point_global_to_local(hier_shape, face_idx, p_global)
v_local = transform_geometric_vector_global_to_local(hier_shape, face_idx, v_global)
f_local = transform_physical_vector_global_to_local(hier_shape, face_idx, f_global)
```

Key features:
- Add surface roughness models to individual faces
- Automatic coordinate transformations between global and local frames
- Separate handling of geometric vectors (with scaling) and physical vectors (rotation only)
- Memory-efficient sharing of roughness models across multiple faces

### Breaking Changes

#### Removed `apply_eclipse_shadowing!` deprecated signature

The old function signature that used the `t₁₂` parameter has been removed:

```julia
# Old signature (removed)
apply_eclipse_shadowing!(illuminated_faces, shape1, r☉₁, R₁₂, t₁₂, shape2)

# New signature (use this)
apply_eclipse_shadowing!(illuminated_faces, shape1, shape2, r☉₁, r₁₂, R₁₂)
```

**Migration steps:**

1. Replace the `t₁₂` parameter with `r₁₂` (shape2's position in shape1's frame)
  - The position corresponding to `r₁₂` can be retrieved from SPICE kernels.
  - If you have `t₁₂`, compute `r₁₂` using: `r₁₂ = -R₁₂' * t₁₂`
2. Update the parameter order to group shapes together

**Example migration:**

```julia
# Before (v0.4.x)
t₁₂ = -R₁₂ * r₁₂  # You might have computed t₁₂ like this
apply_eclipse_shadowing!(illuminated, shape1, sun_pos, R₁₂, t₁₂, shape2)

# After (v0.5.0)
# Use r₁₂ directly (shape2's position)
apply_eclipse_shadowing!(illuminated, shape1, shape2, sun_pos, r₁₂, R₁₂)
```

#### Removed `use_elevation_optimization` parameter

The `use_elevation_optimization` parameter has been removed from all illumination APIs. The elevation-based optimization is now always enabled when using `with_self_shadowing=true`.

```julia
# Before (v0.4.x)
isilluminated(shape, sun_pos, face_idx; 
    with_self_shadowing=true, 
    use_elevation_optimization=false  # This parameter is removed
)

# After (v0.5.0)
isilluminated(shape, sun_pos, face_idx; 
    with_self_shadowing=true  # Optimization is always enabled
)
```

This change applies to both `isilluminated` and `update_illumination!` functions.

## Migrating to v0.4.2

### New Performance Features

#### Face Maximum Elevation Optimization

The v0.4.2 release includes automatic performance optimizations for illumination calculations. No code changes are required to benefit from these improvements.

```julia
# Your existing code works as before, but ~2.5x faster!
illuminated = isilluminated(shape, sun_position, face_idx; with_self_shadowing=true)
```

Note: The `use_elevation_optimization` parameter was introduced in v0.4.2 but has been removed in v0.5.0 as the optimization is now always enabled.

## Migrating to v0.4.1

### Breaking Changes

#### New `apply_eclipse_shadowing!` API

The parameter order has been changed for better SPICE integration:

```julia
# New API
apply_eclipse_shadowing!(illuminated_faces, shape1, shape2, r☉₁, r₁₂, R₁₂)
```

Key differences from v0.4.0:
- `shape1` and `shape2` are now grouped together
- `r₁₂` (shape2's position in shape1's frame) is used directly
- More intuitive parameter ordering for SPICE integration

## Migrating to v0.4.0

### New Unified Illumination API

The illumination functions have been unified into a single API:

```julia
# Old APIs (removed)
isilluminated_pseudoconvex(shape, sun_position, face_idx)
isilluminated_with_self_shadowing(shape, sun_position, face_idx)

# New unified API
isilluminated(shape, sun_position, face_idx; with_self_shadowing=false)  # pseudo-convex
isilluminated(shape, sun_position, face_idx; with_self_shadowing=true)   # with shadowing
```

### Batch Processing

New batch processing functions for better performance:

```julia
# Process all faces at once
illuminated = Vector{Bool}(undef, length(shape.faces))
update_illumination!(illuminated, shape, sun_position; with_self_shadowing=true)
```
