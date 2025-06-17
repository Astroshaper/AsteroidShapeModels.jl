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

# Load an asteroid shape model with face-face visibility
shape = load_shape_obj("path/to/shape.obj", scale=1000, find_visible_facets=true)  # Convert km to m

# Access to face properties
shape.face_centers  # Center position of each face
shape.face_normals  # Normal vector of each face
shape.face_areas    # Area of of each face
```

See the documentation for detailed usage examples and API reference.
"""
module AsteroidShapeModels

using LinearAlgebra
using StaticArrays
using FileIO
import MeshIO
import GeometryBasics

include("face_properties.jl")
export face_center, face_normal, face_area

include("types.jl")
export VisibleFacet, Ray, BoundingBox
export RayTriangleIntersectionResult, RayShapeIntersectionResult

include("face_visibility_graph.jl")
export FaceVisibilityGraph
export get_visible_faces, get_view_factors, get_distances, get_directions
export get_visible_facet_data, num_visible_faces, memory_usage

include("shape_model.jl")
export ShapeModel

include("obj_io.jl")
export loadobj, isobj

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
