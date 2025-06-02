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
export raycast, intersect_ray_triangle, intersect_ray_shape
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