# AsteroidShapeModels.jl Development Roadmap

This document outlines the development plans and milestones for `AsteroidShapeModels.jl`. We use [Semantic Versioning](https://semver.org/) for version numbering.

## Version 0.4.0 - BVH Integration and Optimization (Target: July 2025)

### Major Changes (Breaking Changes)
- **Full Integration of `ImplicitBVH.jl`**
  - [x] Add performance benchmarks
  - [x] Unify ray intersection to BVH implementation only (#28)
    - [x] Remove legacy non-BVH implementation (#28)
    - [x] Remove custom `BoundingBox` type in favor of `ImplicitBVH`'s BBox (#28)
    - [x] Add batch ray processing capability (#29)
  - [x] Unify face visibility graph to non-BVH implementation (cf. `build_face_visibility_graph` function) (current PR)
  - [ ] Unify illumination check to non-BVH implementation (cf. `isilluminated` function)
  
- **Illumination API Redesign**
  - [ ] Clarify self-shadowing and mutual-shadowing APIs
  - [ ] Add binary asteroid eclipse detection capability

### Infrastructure Improvements
- [ ] Move BenchmarkTools to extras section
- [ ] Optimize memory allocations in `visibility.jl`

### Documentation
- [ ] Add comprehensive BVH usage documentation
- [ ] Document performance comparisons between BVH and non-BVH approaches
- [ ] Update examples for new APIs

## Version 0.5.0 - Advanced Surface Modeling (Target: August 2025)

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

### API Improvements
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
