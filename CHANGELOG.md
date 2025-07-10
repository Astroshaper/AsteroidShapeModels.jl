# Changelog

All notable changes to `AsteroidShapeModels.jl` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **New `apply_eclipse_shadowing!` API with improved parameter ordering** (feature/eclipse-shadowing-new-api)
  - New signature: `apply_eclipse_shadowing!(illuminated_faces, shape1, shape2, r☉₁, r₁₂, R₁₂)`
  - Directly accepts `r₁₂` (shape2's position in shape1's frame) for better SPICE integration
  - More intuitive parameter ordering with shapes grouped together
  - The old signature using `t₁₂` is deprecated and will be removed in v0.5.0

### Changed
- **Parameter naming consistency for batch illumination functions**
  - Renamed `illuminated` parameter to `illuminated_faces` across all batch processing functions
  - Affects `update_illumination!`, `apply_eclipse_shadowing!`, and related functions
  - Improves API consistency and clarity

### Fixed
- **Critical coordinate transformation bug in eclipse detection** (#42)
  - Translation vector `t₁₂` was incorrectly interpreted as position vector
  - This caused false TOTAL_ECLIPSE detections when shape2 was actually behind shape1
  - Now correctly recovers shape2's position using `r₁₂ = -R₁₂' * t₁₂`
  - This was a critical bug affecting binary asteroid thermal simulations
  
- **Sun position transformation in `apply_eclipse_shadowing!`**
  - Now correctly includes translation when transforming sun position to shape2's frame
  - Previously only applied rotation, which could lead to incorrect shadow calculations
  - Ensures accurate eclipse detection in binary asteroid systems

## [0.4.0] - 2025-07-07

### Breaking Changes
- **BVH must be pre-built for ray intersection** (04d2937, 5355dbc)
  - `intersect_ray_shape` now requires BVH to be built before use
  - Throws `ArgumentError` if BVH is not present (previously built automatically)
  - Use `build_bvh!(shape)` or `with_bvh=true` when loading shapes
  - This change provides explicit control over memory usage and performance

- **Renamed `get_face_vertices` to `get_face_nodes`** (#35)
  - Function renamed to better reflect that it returns nodes, not vertices
  - Signature changed from `get_face_nodes(nodes, face)` to `get_face_nodes(nodes, faces, face_idx)`
  - More consistent with other functions like `intersect_ray_triangle`
  - Update your code: `get_face_nodes(nodes, faces[i])` → `get_face_nodes(nodes, faces, i)`

- **Standardized face index naming to `face_idx`** (#36)
  - All face index parameters renamed from `face_id` or `i` to `face_idx`
  - `RayShapeIntersectionResult.face_index` field renamed to `face_idx`
  - `VisibleFace` struct fields renamed for clarity:
    - `id` → `face_idx`
    - `f` → `view_factor`
    - `d` → `distance`
    - `d̂` → `direction`
  - `get_visible_face_data` return value fields renamed accordingly
  - Update your code: 
    - `result.face_index` → `result.face_idx`
    - `vf.id` → `vf.face_idx`
    - `vf.f` → `vf.view_factor`
    - `vf.d` → `vf.distance`
    - `vf.d̂` → `vf.direction`
  - This change improves consistency and readability across the entire API

### Added
- **Batch ray processing functionality** (#29)
  - Multiple dispatch for `intersect_ray_shape` to handle various input formats:
    - `intersect_ray_shape(rays::Vector{Ray}, shape)` for ray collections
    - `intersect_ray_shape(rays::Matrix{Ray}, shape)` preserves grid structure.
    - `intersect_ray_shape(shape, origins, directions)` matching `ImplicitBVH`
  - Efficient batch processing using single BVH traversal
  - Results maintain input shape for vector/matrix inputs

- **Unified illumination API with batch processing** (#31, feature/batch-illumination)
  - New `isilluminated` function with `with_self_shadowing` keyword argument
  - New `update_illumination!` function for efficient batch illumination updates
  - New `apply_eclipse_shadowing!` function for binary asteroid mutual shadowing
  - `EclipseStatus` enum for eclipse detection (NO_ECLIPSE, PARTIAL_ECLIPSE, TOTAL_ECLIPSE)
  - Specialized implementations for pseudo-convex and self-shadowing models
  - Performance optimizations including early-out checks and sphere-based culling

### Changed
- **Face visibility graph unified to non-BVH implementation** (#30)
  - Removed BVH-based visibility graph construction in `build_face_visibility_graph!`
  - Non-BVH algorithm with candidate filtering provides better performance (~2x faster than BVH)
  - BVH was found to be ~0.5x slower for face-to-face visibility queries
- **Illumination check unified to non-BVH implementation** (#31)
  - Removed BVH-based implementation from `isilluminated` function
  - Uses FaceVisibilityGraph for efficient occlusion testing when available
  - Falls back to checking all faces when visibility graph is not precomputed

### Improved
- **Code organization** (#37)
  - Split large `visibility.jl` (650 lines) into focused modules:
    - `face_visibility_graph.jl`: Face visibility graph and view factor calculations
    - `illumination.jl`: Illumination analysis and shadow testing
    - `eclipse_shadowing.jl`: Eclipse shadowing for binary asteroid systems
  - Moved `FaceVisibilityGraph` type definition to `types.jl` to resolve circular dependencies
  - Added section dividers throughout files for better code navigation
  - Better separation of concerns and improved maintainability

### Documentation
- Enhanced `intersect_ray_triangle` docstrings with backface culling behavior details
- Added batch ray processing examples to tutorial
- Updated performance tips with batch operation recommendations
- Documented performance characteristics of BVH vs non-BVH for visibility graphs
- Updated file-level documentation in `visibility.jl` with new exported functions
- Updated package structure documentation to reflect new file organization

## [0.3.1] - 2025-07-02

### Added
- **BVH (Bounding Volume Hierarchy) acceleration** (#22)
  - Optional BVH support via `with_bvh` parameter in `load_shape_obj`
  - New `build_bvh!` function to add BVH to existing shapes
  - BVH acceleration in three core functions:
    - `intersect_ray_shape`: ~50x speedup for ray-shape intersections
    - `isilluminated`: BVH-based shadow testing
    - `build_face_visibility_graph!`: Foundation for future optimizations
  - Uses `ImplicitBVH.jl as an optional dependency

### Improved
- **Non-BVH visibility calculations** (#22)
  - Distance-based candidate sorting: ~2x speedup
  - Pre-computed distance reuse via `zip()` iteration
  - Optimized Ray object creation (moved outside loops)
  - Clearer code structure with detailed comments

### Documentation
- Updated README with BVH feature highlights
- Added BVH usage examples in Quick Start sections
- Updated feature descriptions in documentation

### Notes
- Backward compatible - no breaking changes
- BVH support is opt-in and does not affect existing code
- Current BVH visibility implementation has room for future optimization

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
visible_face_indices = get_visible_face_indices(shape.face_visibility_graph, i)
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
  