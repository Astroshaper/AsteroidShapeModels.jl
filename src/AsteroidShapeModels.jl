"""
    AsteroidShapeModels

A Julia package for geometric processing and analysis of asteroid shape models.

This package provides comprehensive tools for working with polyhedral shape models of asteroids,
including loading from OBJ files, computing geometric properties, ray-shape intersection,
visibility analysis, and surface roughness modeling.

# Main Types
- `ShapeModel`: Core data structure for polyhedral shapes
- `Ray`, `BoundingBox`: Ray casting and acceleration structures
- `VisibleFacet`: Face-to-face visibility relationships

# Key Functions
- Shape I/O: `load_shape_obj`, `loadobj`, `load_shape_grid`
- Geometric properties: `face_center`, `face_normal`, `face_area`, `polyhedron_volume`
- Ray intersection: `raycast`, `intersect_ray_shape`
- Visibility: `find_visiblefacets!`, `isilluminated`, `view_factor`
- Shape analysis: `equivalent_radius`, `maximum_radius`, `minimum_radius`

# Example
```julia
using AsteroidShapeModels

# Load asteroid shape model
shape = load_shape_obj("ryugu.obj", scale=1000)  # Convert km to m

# Compute visibility between faces
find_visiblefacets!(shape)

# Check illumination
sun_position = SA[1.0, 0.0, 0.0]  # Sun along +x axis
illuminated = isilluminated(shape, sun_position, 1)  # Check face 1
```

See the documentation for detailed usage examples and API reference.
"""
module AsteroidShapeModels

using LinearAlgebra
using StaticArrays
using FileIO
import MeshIO
import GeometryBasics

include("types.jl")
export ShapeModel, VisibleFacet, Ray, BoundingBox
export RayTriangleIntersectionResult, RayShapeIntersectionResult

include("obj_io.jl")
export loadobj, isobj

include("face_properties.jl")
export face_center, face_normal, face_area

include("ray_intersection.jl")
export intersect_ray_triangle, intersect_ray_shape
export intersect_ray_bounding_box, compute_bounding_box

include("shape_operations.jl")
export load_shape_obj, load_shape_grid, grid_to_faces
export polyhedron_volume, equivalent_radius, maximum_radius, minimum_radius

include("visibility.jl")
export view_factor, find_visiblefacets!, isilluminated

include("geometry_utils.jl")
export angle_rad, angle_deg, solar_phase_angle, solar_elongation_angle

include("roughness.jl")
export crater_curvature_radius, concave_spherical_segment

end # module AsteroidShapeModels
