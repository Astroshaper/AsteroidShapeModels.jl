# Changelog

All notable changes to `AsteroidShapeModels.jl` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
  