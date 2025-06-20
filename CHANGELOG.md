# Changelog

All notable changes to `AsteroidShapeModels.jl` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2025-06-20

### Breaking Changes
- **Removed legacy visibility API** (#15)
  - Removed `visiblefacets` field from `ShapeModel`
  - Removed `use_visibility_graph` parameter (CSR format is now the only implementation)
  - Removed `from_adjacency_list` and `to_adjacency_list` conversion functions
  
- **API renaming for clarity and consistency** (#15, #17)
  - `find_visiblefacets!` → `build_face_visibility_graph!`
  - `ShapeModel.visibility_graph` → `ShapeModel.face_visibility_graph`
  - `find_visible_facets` parameter → `with_face_visibility`
  - Visibility graph accessor functions:
    - `get_visible_faces` → `get_visible_face_indices`
    - `get_distances` → `get_visible_face_distances`
    - `get_directions` → `get_visible_face_directions`
    - `get_visible_facet_data` → `get_visible_face_data`
  - `VisibleFacet` → `VisibleFace` (internal type, removed from exports)

- **Function naming convention updates** (#18)
  - `loadobj` → `load_obj` (follows Julia snake_case convention)
  - Removed `message` parameter from `load_obj` function

### Changed
- Removed redundant inner constructor from `ShapeModel`
- Fixed face orientations in test shapes for correct visibility calculations
- Used keyword argument shorthand syntax where applicable
- Made `VisibleFacet` an internal type and renamed to `VisibleFace` (#17)

### Migration Guide

#### Key Changes
1. The `visiblefacets` field has been removed from `ShapeModel`
2. CSR-based `FaceVisibilityGraph` is now the only implementation
3. Several functions and parameters have been renamed for clarity

#### Code Migration Examples

```julia
# Loading OBJ files
# Before (v0.2.x)
nodes, faces = loadobj("path/to/shape.obj", message=false)
# After (v0.3.0)
nodes, faces = load_obj("path/to/shape.obj")
# To get node/face counts:
println("Number of nodes: ", length(nodes))
println("Number of faces: ", length(faces))

# Loading shapes with visibility
# Before (v0.2.x)
shape = load_shape_obj("path/to/shape.obj"; find_visible_facets=true)
# After (v0.3.0)
shape = load_shape_obj("path/to/shape.obj"; with_face_visibility=true)

# Building visibility graph
# Before (v0.2.x)
find_visiblefacets!(shape, use_visibility_graph=true)
# After (v0.3.0)
build_face_visibility_graph!(shape)

# Accessing visibility data
# Before (v0.2.x)
visible_faces = get_visible_faces(shape.visibility_graph, i)
distances = get_distances(shape.visibility_graph, i)
directions = get_directions(shape.visibility_graph, i)
data = get_visible_facet_data(shape.visibility_graph, i, j)

# After (v0.3.0)
visible_indices = get_visible_face_indices(shape.face_visibility_graph, i)
distances = get_visible_face_distances(shape.face_visibility_graph, i)
directions = get_visible_face_directions(shape.face_visibility_graph, i)
data = get_visible_face_data(shape.face_visibility_graph, i, j)
```

#### Performance Benefits
The new CSR-based implementation provides:
- ~4x faster computation for small models (< 10k faces)
- ~50% memory reduction across all model sizes
- Better cache locality for sequential access patterns

## [0.2.1] - 2025-06-17

### Added
- `FaceVisibilityGraph`: New CSR-style data structure for face visibility (#12)
  - ~4x faster for small models (< 10k faces) 
  - ~50% memory reduction for all model sizes
  - Better cache locality for sequential access
  - Backward compatible with existing code
- Benchmark suite for performance comparison
- High-resolution (49k faces) model benchmark
- `use_visibility_graph` parameter to `find_visiblefacets!` (default: true)
- Manifest.toml files for reproducible builds (#11)

### Deprecated
- Legacy adjacency list implementation will be removed in v0.3.0
- `shape.visiblefacets` field will be removed in v0.3.0 (use `shape.visibility_graph`)

## [0.2.0] - 2025-06-14

### Breaking Changes
- **Removed `raycast` function** - Use `intersect_ray_triangle` instead (#4)
  - The `raycast` function that returned only a boolean hit/miss result has been removed
  - All ray-triangle intersection operations now use `intersect_ray_triangle` which provides detailed intersection information
  - Migration guide:
    ```julia
    # Old code
    if raycast(A, B, C, ray_direction, ray_origin)
        # handle intersection
    end
    
    # New code
    ray = Ray(ray_origin, ray_direction)
    if intersect_ray_triangle(ray, A, B, C).hit
        # handle intersection
    end
    ```

### Added
- `ShapeModel` constructor that automatically computes face properties (#2)
  - Reduces code duplication when creating shape models
  - Optionally computes face-to-face visibility with `with_face_visibility=true`

### Changed
- Improved performance and readability across the codebase (#3)
  - Optimized face property calculations
  - Enhanced code clarity and maintainability

### Documentation
- Added PkgEval badge to README
- Updated installation instructions for Julia General registry
- Added Julia REPL package mode installation method

## [0.1.0] - Initial Release

### Added
- Initial release with core functionality:
  - Shape model loading from OBJ files
  - Face geometric properties (centers, normals, areas)
  - Ray-triangle intersection detection using Möller–Trumbore algorithm
  - Bounding box calculations
  - Face-to-face visibility analysis
  - Shape characteristics (volume, equivalent radius, max/min radii)
  