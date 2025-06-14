# Performance Benchmarks for AsteroidShapeModels.jl

This directory contains performance benchmarks for tracking the performance of `AsteroidShapeModels.jl` across different versions.

## Running Benchmarks

### Quick Run
To run the benchmarks directly:
```julia
julia benchmark/benchmarks.jl
```

### Using PkgBenchmark
For more detailed analysis and comparison between versions:

```julia
using PkgBenchmark
using AsteroidShapeModels

# Run benchmarks for current state
results = benchmarkpkg(AsteroidShapeModels)

# Compare against a specific version (e.g., v0.2.0)
judge(AsteroidShapeModels, "v0.2.0")

# Compare against a specific commit
judge(AsteroidShapeModels, "main")
```

## Benchmark Categories

1. **Loading**: Shape model loading with and without visibility calculations
2. **Face Properties**: Face center, normal, and area calculations
3. **Visibility**: Illumination checks and face visibility lookups
4. **Ray Intersection**: Single triangle and full shape intersections
5. **Bounding Box**: Computing and ray-box intersection
6. **Shape Characteristics**: Volume, equivalent radius, max/min radius
7. **Memory**: Memory allocation benchmarks

## Interpreting Results

- **Time**: Lower is better (measured in nanoseconds, microseconds, or milliseconds)
- **Memory**: Lower allocation count and size is better
- **Regression**: A significant increase in time or memory compared to baseline

## Adding New Benchmarks

To add new benchmarks, edit `benchmarks.jl` and add to the appropriate `SUITE` group:

```julia
SUITE["category"]["new_benchmark"] = @benchmarkable begin
    # Your benchmark code here
end
```