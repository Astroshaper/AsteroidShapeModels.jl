# Changelog

All notable changes to `AsteroidShapeModels.jl` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
  - Optionally computes face-to-face visibility with `find_visible_facets=true`

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
  