# Migration Guide

This guide helps you migrate your code when upgrading between major versions of `AsteroidShapeModels.jl`.

## Getting Help

If you encounter issues during migration:

1. Check the [CHANGELOG](https://github.com/Astroshaper/AsteroidShapeModels.jl/blob/main/CHANGELOG.md) for detailed changes
2. Review the [API documentation](https://astroshaper.github.io/AsteroidShapeModels.jl/stable)
3. Open an [issue](https://github.com/Astroshaper/AsteroidShapeModels.jl/issues) on GitHub

## Future Deprecations

No planned deprecations at this time.

## Migrating to v0.6.0

!!! note
    This section is a skeleton for the upcoming v0.6.0 release and will be completed before the release.

v0.6.0 unifies `HierarchicalShapeModel` into `ShapeModel`: surface roughness is now an optional
`roughness` field (`SurfaceRoughness`) of `ShapeModel`, and `HierarchicalShapeModel` has been removed.

### API replacement table

| v0.5.x | v0.6.0 | Notes |
|---|---|---|
| `HierarchicalShapeModel(shape)` / `HierarchicalShapeModel(nodes, faces; ...)` | Not needed; use `ShapeModel` directly | Removed |
| `load_shape_obj(...; as_hierarchical=true)` / `load_shape_grid(...; as_hierarchical=true)` / `create_shape_crater(...; as_hierarchical=true)` | Remove the keyword | Removed |
| `hier.global_shape` | The `shape` itself | Field no longer exists |
| `hier.face_roughness_indices` / `hier.face_roughness_transforms` / `hier.roughness_models` | `shape.roughness.face_roughness_indices` etc. | `shape.roughness` may be `nothing` |
| `add_roughness_models!(hier, ...)` / `clear_roughness_models!(hier, ...)` | First argument is a `ShapeModel` | Names unchanged; first `add_roughness_models!` call constructs `shape.roughness` |
| `has_roughness_model(hier, i)` / `get_roughness_model(hier, i)` / `get_roughness_model_scale(hier, i)` / `get_roughness_model_transform(hier, i)` | First argument is a `ShapeModel` | If `shape.roughness === nothing`: `false` / `nothing` / error / error |
| — | **New**: `has_roughness(shape)::Bool` | Whole-shape roughness check |
| `transform_point_*` / `transform_geometric_vector_*` / `transform_physical_vector_*` | First argument is a `ShapeModel` | Names unchanged |
| Delegation methods (`build_face_visibility_graph!(hier)` etc.) | Not needed; call the `ShapeModel` methods directly | Removed |

### Code example

```julia
# v0.5.x
hier   = load_shape_obj("shape.obj"; as_hierarchical=true, with_face_visibility=true)
crater = create_shape_crater(0.4, 0.1; Nx=8, Ny=8)
add_roughness_models!(hier, crater; scale=0.1)
update_illumination!(illum, hier, r☉; with_self_shadowing=true)   # was delegated
hier.global_shape.face_areas

# v0.6.0
shape  = load_shape_obj("shape.obj"; with_face_visibility=true)
crater = create_shape_crater(0.4, 0.1; Nx=8, Ny=8)
add_roughness_models!(shape, crater; scale=0.1)                    # shape.roughness is constructed
update_illumination!(illum, shape, r☉; with_self_shadowing=true)   # unchanged
shape.face_areas
has_roughness(shape)                                               # true
```

## Migrating to v0.5.0

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
