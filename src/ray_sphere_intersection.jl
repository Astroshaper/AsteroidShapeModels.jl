#=
    ray_sphere_intersection.jl

This file implements ray-sphere intersection utility for eclipse shadowing calculations.
This function provides an optimized test to avoid expensive ray-shape intersection
calculations when possible.

Key Features:
- Fast ray-sphere intersection test with quadratic equation solving
- Returns intersection distances and points for both entry and exit
- Handles special cases (ray origin inside sphere, tangent rays)
- Used primarily in `apply_eclipse_shadowing!` for performance optimization

Exported Functions:
- `intersect_ray_sphere`: Full ray-sphere intersection test
=#

"""
    intersect_ray_sphere(
        ray_origin::SVector{3, Float64}, ray_direction::SVector{3, Float64}, 
        sphere_center::SVector{3, Float64}, sphere_radius::Float64,
    ) -> RaySphereIntersectionResult

Test if a ray intersects with a sphere.

# Arguments
- `ray_origin`    : Starting point of the ray
- `ray_direction` : Direction of the ray (will be normalized internally)
- `sphere_center` : Center of the sphere
- `sphere_radius` : Radius of the sphere

# Returns
`RaySphereIntersectionResult` with fields:
- `hit::Bool`                   : true if the ray intersects the sphere
- `distance1::Float64`          : Distance to first intersection point (NaN if no intersection)
- `distance2::Float64`          : Distance to second intersection point (NaN if no intersection)
- `point1::SVector{3, Float64}` : First intersection point coordinates
- `point2::SVector{3, Float64}` : Second intersection point coordinates

# Special Cases
- **Ray origin inside sphere**: When the ray starts inside the sphere, `distance1 < 0` (behind the origin) 
  and `distance2 > 0` (in front of the origin). The ray will always hit the sphere from inside.
- **Ray origin on sphere surface**: When the ray starts exactly on the sphere surface, `distance1 ≈ 0`.
- **Tangent ray**: When the ray just touches the sphere, `distance1 ≈ distance2`.
- **Sphere behind ray**: When both intersection points are behind the ray origin (`distance2 < 0`), 
  the function returns no intersection as the sphere is not in the ray's forward direction.
- **Degenerate cases**: Returns no intersection for zero or negative radius spheres, or zero-length ray directions.

# Algorithm
Solves the quadratic equation for ray-sphere intersection:
|ray_origin + t * ray_direction - sphere_center|² = sphere_radius²

# Example
```julia
ray_origin    = SVector(0.0, 0.0, 0.0)
ray_direction = SVector(1.0, 0.0, 0.0)  # Normalization is handled internally
sphere_center = SVector(5.0, 0.0, 0.0)
sphere_radius = 2.0

result = intersect_ray_sphere(ray_origin, ray_direction, sphere_center, sphere_radius)
if result.hit
    println("Ray hits sphere at distances: ", result.distance1, " and ", result.distance2)
    println("Entry point : ", result.point1)
    println("Exit point  : ", result.point2)
end
```
"""
function intersect_ray_sphere(
    ray_origin::SVector{3, Float64}, ray_direction::SVector{3, Float64}, 
    sphere_center::SVector{3, Float64}, sphere_radius::Float64,
)
    # Check for degenerate cases
    sphere_radius ≤ 0        && return NO_INTERSECTION_RAY_SPHERE
    norm(ray_direction) == 0 && return NO_INTERSECTION_RAY_SPHERE
    
    # Normalize ray direction for safety
    ray_direction = normalize(ray_direction)
    
    # Vector from sphere center to ray origin
    co = ray_origin - sphere_center
    
    # Quadratic equation coefficients: at² + bt + c = 0
    a = dot(ray_direction, ray_direction)  # Now guaranteed to be 1.0
    b = 2.0 * dot(co, ray_direction)
    c = dot(co, co) - sphere_radius^2
    
    # Discriminant
    D = b^2 - 4 * a * c
    
    # No intersection if D < 0
    D < 0 && return NO_INTERSECTION_RAY_SPHERE
    
    # Calculate the two intersection distances
    sqrt_D = sqrt(D)
    distance1 = (-b - sqrt_D) / 2a
    distance2 = (-b + sqrt_D) / 2a
    
    # If both intersections are behind the ray origin, no valid intersection
    distance2 < 0 && return NO_INTERSECTION_RAY_SPHERE
    
    # Calculate the intersection points
    point1 = ray_origin + distance1 * ray_direction
    point2 = ray_origin + distance2 * ray_direction
    
    return RaySphereIntersectionResult(true, distance1, distance2, point1, point2)
end

"""
    intersect_ray_sphere(ray::Ray, sphere::Sphere) -> RaySphereIntersectionResult

Test if a ray intersects with a sphere using Ray and Sphere objects.

This is a convenience overload that extracts the parameters from the Ray and Sphere 
objects and calls the main implementation.

# Arguments
- `ray`    : Ray object containing origin and direction
- `sphere` : Sphere object containing center and radius

# Returns
`RaySphereIntersectionResult` with intersection details

# Example
```julia
ray = Ray([0.0, 0.0, 0.0], [1.0, 0.0, 0.0])
sphere = Sphere([5.0, 0.0, 0.0], 2.0)

result = intersect_ray_sphere(ray, sphere)
if result.hit
    println("Ray hits sphere at distances: ", result.distance1, " and ", result.distance2)
    println("Entry point : ", result.point1)
    println("Exit point  : ", result.point2)
end
```
"""
function intersect_ray_sphere(ray::Ray, sphere::Sphere)
    return intersect_ray_sphere(ray.origin, ray.direction, sphere.center, sphere.radius)
end
