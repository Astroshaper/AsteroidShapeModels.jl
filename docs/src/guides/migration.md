# Migration Guide

This guide helps you migrate your code when upgrading between major versions of `AsteroidShapeModels.jl`.

## Migrating to v0.4.2

### New Performance Features

#### Face Maximum Elevation Optimization

The v0.4.2 release includes automatic performance optimizations for illumination calculations. No code changes are required to benefit from these improvements.

```julia
# Your existing code works as before, but ~2.5x faster!
illuminated = isilluminated(shape, sun_position, face_idx; with_self_shadowing=true)
```

To disable the optimization (not recommended):
```julia
# Explicitly disable optimization
illuminated = isilluminated(
   shape, sun_position, face_idx; 
   with_self_shadowing=true, 
   use_elevation_optimization=false,
)
```

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

## Future Deprecations (v0.5.0)

### Planned Removals

1. **`use_elevation_optimization` parameter**
   - Will be removed in v0.5.0
   - Optimization will become the default behavior
   - Start removing explicit `use_elevation_optimization=true` from your code

2. **Old `apply_eclipse_shadowing!` signature**
   - The deprecated signature with `t₁₂` will be removed
   - Migrate to the new API with `r₁₂` parameter

## Getting Help

If you encounter issues during migration:

1. Check the [CHANGELOG](https://github.com/Astroshaper/AsteroidShapeModels.jl/blob/main/CHANGELOG.md) for detailed changes
2. Review the [API documentation](https://astroshaper.github.io/AsteroidShapeModels.jl/stable)
3. Open an [issue](https://github.com/Astroshaper/AsteroidShapeModels.jl/issues) on GitHub
