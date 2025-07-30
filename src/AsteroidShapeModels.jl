"""
    AsteroidShapeModels

A Julia package for geometric processing and analysis of asteroid shape models.

This package provides comprehensive tools for working with polyhedral shape models of asteroids,
including loading from OBJ files, computing geometric properties, ray-shape intersection,
visibility analysis, and surface roughness modeling.

# Main Types
- `AbstractShapeModel`: Abstract base type for all shape models
- `ShapeModel`: Core data structure for polyhedral shapes
- `HierarchicalShapeModel`: Multi-scale shape model with surface roughness
- `Ray`: Ray for ray casting operations
- `FaceVisibilityGraph`: CSR-style data structure for face-to-face visibility

# Key Functions
- Shape I/O: `load_shape_obj`, `load_obj`, `load_shape_grid`
- Geometric properties: `face_center`, `face_normal`, `face_area`, `polyhedron_volume`
- Ray intersection: `intersect_ray_triangle`, `intersect_ray_shape`
- Visibility: `build_face_visibility_graph!`, `isilluminated`, `view_factor`
- Shape analysis: `equivalent_radius`, `maximum_radius`, `minimum_radius`

# Example
```julia
using AsteroidShapeModels

# Load an asteroid shape model with face-face visibility
shape = load_shape_obj("path/to/shape.obj", scale=1000, with_face_visibility=true)  # Convert km to m

# Access to face properties
shape.face_centers  # Center position of each face
shape.face_normals  # Normal vector of each face
shape.face_areas    # Area of of each face
```

See the documentation for detailed usage examples and API reference.
"""
module AsteroidShapeModels

using CoordinateTransformations
using FileIO
using LinearAlgebra
using StaticArrays

import GeometryBasics
import ImplicitBVH
import MeshIO

include("face_properties.jl")
export face_center, face_normal, face_area, get_face_nodes

include("types.jl")
export Ray, Sphere
export RayTriangleIntersectionResult, RayShapeIntersectionResult, RaySphereIntersectionResult

include("shape_model.jl")
export AbstractShapeModel, ShapeModel, build_bvh!

include("hierarchical_shape_model.jl")
export HierarchicalShapeModel
export add_roughness_model!, get_roughness_model, get_roughness_model_scale, has_roughness
export transform_point_global_to_local, transform_point_local_to_global
export transform_vector_global_to_local, transform_vector_local_to_global
export transform_physical_vector_global_to_local, transform_physical_vector_local_to_global

include("face_visibility_graph.jl")
export FaceVisibilityGraph, build_face_visibility_graph!, view_factor
export get_visible_face_indices, get_view_factors, get_visible_face_distances, get_visible_face_directions
export get_visible_face_data, num_visible_faces

include("obj_io.jl")
export load_obj, isobj

include("ray_intersection.jl")
export intersect_ray_triangle, intersect_ray_shape

include("ray_sphere_intersection.jl")
export intersect_ray_sphere

include("shape_operations.jl")
export load_shape_obj, load_shape_grid, grid_to_faces
export polyhedron_volume, equivalent_radius, maximum_radius, minimum_radius

include("illumination.jl")
export isilluminated, update_illumination!

include("face_max_elevations.jl")
export compute_face_max_elevations!

include("eclipse_shadowing.jl")
export apply_eclipse_shadowing!, EclipseStatus, NO_ECLIPSE, PARTIAL_ECLIPSE, TOTAL_ECLIPSE

include("geometry_utils.jl")
export angle_rad, angle_deg, solar_phase_angle, solar_elongation_angle

include("roughness.jl")
export crater_curvature_radius, concave_spherical_segment

end # module AsteroidShapeModels
