# Benchmarks

This directory contains performance benchmarks for AsteroidShapeModels.jl.

## Running Benchmarks

### Quick Benchmarks
```bash
# Run basic benchmarks
julia --project=. benchmark/benchmarks.jl

# Run high-resolution model benchmark (downloads 49k face model)
julia --project=. benchmark/benchmark_49k_shape.jl
```

### Comparing Implementations
To compare performance before and after changes:

```bash
# Compare visibility implementations (requires v0.2.x with backward compatibility)
julia --project=. benchmark/compare_visibility.jl
```

## Benchmark Results

Historical benchmark results are documented in:
- [`docs/src/benchmarks/`](../docs/src/benchmarks/) - Detailed performance comparisons for each version

## Reproducing Historical Benchmarks

To reproduce benchmarks from specific versions:

```bash
# Example: Reproduce v0.2.0 FaceVisibilityGraph benchmarks
git checkout v0.2.0
julia --project=. benchmark/compare_visibility.jl
```

## Shape Models

Large shape models for benchmarks are downloaded on-demand to `benchmark/shape/`. These files are git-ignored to keep the repository size manageable.

### Available Models
- `SHAPE_SFM_49k_v20180804.obj` - High-resolution Ryugu model (49,152 faces)
  - Source: JAXA Data Archive
  - Used for production-scale performance testing