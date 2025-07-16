# AsteroidShapeModels.jl Development Roadmap

This document outlines the development plans and milestones for `AsteroidShapeModels.jl`. We use [Semantic Versioning](https://semver.org/) for version numbering.

## Version 0.4.0 - BVH Integration and Optimization (Released: July 2025)

### Major Changes (Breaking Changes)
- **Full Integration of `ImplicitBVH.jl`**
  - [x] Add performance benchmarks
  - [x] Unify ray intersection to BVH implementation only (#28)
    - [x] Remove legacy non-BVH implementation (#28)
    - [x] Remove custom `BoundingBox` type in favor of `ImplicitBVH`'s BBox (#28)
    - [x] Add batch ray processing capability (#29)
  - [x] Unify face visibility graph to non-BVH implementation (cf. `build_face_visibility_graph` function) (#30)
  - [x] Unify illumination check to non-BVH implementation (cf. `isilluminated` function) (#31)
  
- **Illumination API Redesign**
  - [x] Clarify self-shadowing and mutual-shadowing APIs (feature/batch-illumination)
  - [x] Add binary asteroid eclipse detection capability (feature/batch-illumination)

### Infrastructure Improvements
- [x] Move BenchmarkTools to extras section
- [x] Optimize memory allocations in `visibility.jl` (experimental implementation in feature branch)

### Documentation
- [x] Add comprehensive BVH usage documentation
- [x] Update examples for new APIs

## Version 0.4.1 - API Improvements (Released: July 2025)

### Completed
- **Improved `apply_eclipse_shadowing!` API**
  - [x] New function signature with better parameter ordering
  - [x] Direct support for shape2's position (r₁₂) instead of transformation parameter
  - [x] Backward compatibility with deprecated old signature

- **Bug fixes**
  - [x] Fixed critical coordinate transformation bug in eclipse detection (#42)
    - Translation vector `t₁₂` was incorrectly interpreted as position vector
    - This caused false TOTAL_ECLIPSE detections when shape2 was actually behind shape1
    - Now correctly recovers shape2's position using `r₁₂ = -R₁₂' * t₁₂`
  - [x] Fixed sun position transformation in eclipse shadowing (include rotation + translation)

## Version 0.4.2 - Performance Optimizations (Target: August 2025)

### Performance Features
- **Face Maximum Elevation Precomputation**
  - [ ] Add `face_max_elevations` field to `ShapeModel` struct
  - [ ] Implement `compute_face_max_elevations!` function that calculates from `face_visibility_graph`
  - [ ] Modify `build_face_visibility_graph!` to compute `face_max_elevations` after graph construction
  - [ ] Ensure `face_max_elevations` is automatically populated when `with_face_visibility=true` in constructor
  - [ ] Optimize illumination checks using precomputed maximum elevations (skip ray-tracing when sun's elevation > `face_max_elevations[face_idx]`)
  - [ ] Verify illumination results match the original implementation using Ryugu shape model
  - [ ] Add benchmarks to measure performance improvements
  - [ ] Document the feature and its performance benefits

- **Improve `apply_eclipse_shadowing!` code readability**
  - [x] Extract ray-sphere intersection tests into dedicated reusable functions (#45)
  - [x] Ensure consistency in results with previous implementation (#45)

## Version 0.5.0 - Advanced Surface Modeling (Target: September 2025)

### Major Features
- **Hierarchical Surface Roughness Model**
  - [ ] Support nested shape models for multi-scale surface representation
  - [ ] Implement efficient traversal algorithms for nested structures
  
- **Complete Roughness Module**
  - [ ] Implement parallel sinusoidal trench generation
  - [ ] Implement Random Gaussian surface generation
  - [ ] Implement Fractal surface generation
  - [ ] Add comprehensive test coverage for roughness features

- **Performance Enhancements**
  - [ ] Add basic multi-threading support using `Threads.jl`
  - [ ] Optimize critical paths for better single-threaded performance
  - [ ] **Optimize `apply_eclipse_shadowing!` memory allocations**
    - Current implementation calls `intersect_ray_shape` per face, causing ~200 allocations per call
    - Implement true batch ray tracing with pre-allocated buffers for mutual shadowing
    - Design `EclipseShadowingBuffer` struct to hold reusable arrays
    - Implement filtering that preserves early-out optimizations
    - Ensure zero allocations during runtime after initial buffer creation
  - [ ] Add multi-threading support to `apply_eclipse_shadowing!` using `@threads`
  - [ ] Implement spatial data structures (e.g., octree) to pre-filter potentially shadowed faces
  - [ ] Add caching for temporal coherence in simulations with small time steps

### API Improvements
- [ ] Remove deprecated `apply_eclipse_shadowing!` signature that uses `t₁₂` parameter
  - Old signature: `apply_eclipse_shadowing!(illuminated_faces, shape1, r☉₁, R₁₂, t₁₂, shape2)`
  - Keep only the new signature with `r₁₂` parameter introduced in v0.4.1
- [ ] Unify parameter naming conventions across the package
- [ ] Create configuration structs for complex operations
- [ ] Improve error messages and validation

## Version 0.6.0 - High-Performance Computing Support (Target: October 2025)

### Major Features
- **GPU Acceleration (Optional)**
  - [ ] Add optional CUDA.jl support for ray tracing
  - [ ] Add optional AMDGPU.jl support
  - [ ] Implement GPU-accelerated visibility calculations
  - [ ] Use package extensions to keep GPU support optional

- **Advanced Parallelization**
  - [ ] Add distributed computing support via Distributed.jl
  - [ ] Implement efficient work distribution for large models
  - [ ] Add benchmarks for parallel performance

### Scalability
- [ ] Support for extremely large models (3M faces)
- [ ] Memory-efficient algorithms for resource-constrained environments
- [ ] Streaming processing for models that don't fit in memory

## Future Considerations (Beyond v0.6.0)

- **Machine Learning Integration**
  - If any.

- **Extended File Format Support**
  - PLY/STL/VTK/DSK format support

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on how to get involved.

## Tracking Progress

Development progress is tracked through:
- GitHub Milestones for each version
- GitHub Issues for specific features and bugs
- Pull Requests for implementation

Please check our [GitHub Issues](https://github.com/Astroshaper/AsteroidShapeModels.jl/issues) for current tasks and discussions.
