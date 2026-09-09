# Surface Roughness

```@meta
CurrentModule = AsteroidShapeModels
```

## Surface Roughness Management

```@docs
has_roughness
get_roughness_model
get_roughness_model_scale
get_roughness_model_transform
add_roughness_models!
clear_roughness_models!
```

### Coordinate Transformations

```@docs
transform_point_global_to_local
transform_point_local_to_global
transform_geometric_vector_global_to_local
transform_geometric_vector_local_to_global
transform_physical_vector_global_to_local
transform_physical_vector_local_to_global
```

## Crater Modeling

```@docs
create_shape_crater
crater_curvature_radius
concave_spherical_segment
```

## Roughness Statistics

```@docs
projected_area
rms_slope
```