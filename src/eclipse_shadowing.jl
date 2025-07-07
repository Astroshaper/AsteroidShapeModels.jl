#=
    eclipse_shadowing.jl

This file implements eclipse shadowing calculations for binary asteroid systems.
It provides functions to determine mutual shadowing effects between two bodies,
which is essential for thermal modeling of binary systems.

Exported Types:
- `EclipseStatus`: Enum representing eclipse states

Exported Functions:
- `apply_eclipse_shadowing!`: Apply mutual shadowing from another shape
=#

"""
    EclipseStatus

Enum representing the eclipse status between binary pairs.

# Values
- `NO_ECLIPSE`      : No eclipse occurs (bodies are misaligned).
- `PARTIAL_ECLIPSE` : Some faces are eclipsed by the occluding body.
- `TOTAL_ECLIPSE`   : All illuminated faces are eclipsed (complete shadow).
"""
@enum EclipseStatus begin
    NO_ECLIPSE      = 0
    PARTIAL_ECLIPSE = 1
    TOTAL_ECLIPSE   = 2
end

"""
    apply_eclipse_shadowing!(
        illuminated::AbstractVector{Bool}, shape1::ShapeModel, r☉₁::StaticVector{3}, 
        R₁₂::StaticMatrix{3,3}, t₁₂::StaticVector{3}, shape2::ShapeModel
    ) -> EclipseStatus

Apply eclipse shadowing effects from another shape onto already illuminated faces.

# Arguments
- `illuminated` : Boolean vector with current illumination state (will be modified)
- `shape1`      : Target shape model being shadowed (the shape receiving shadows)
- `r☉₁`         : Sun's position in shape1's frame
- `R₁₂`         : 3×3 rotation matrix from `shape1` frame to `shape2` frame
- `t₁₂`         : 3D translation vector from `shape1` frame to `shape2` frame
- `shape2`      : Occluding shape model that may cast shadows on `shape1` (must have BVH built via `build_bvh!`)

# Returns
- `NO_ECLIPSE`: No eclipse occurs (bodies are misaligned).
- `PARTIAL_ECLIPSE`: Some faces that were illuminated are now in shadow by the occluding body.
- `TOTAL_ECLIPSE`: All faces that were illuminated are now in shadow.

# Throws
- `ArgumentError` if `shape2` does not have BVH built. Call `build_bvh!(shape2)` before using this function.

# Description
This function ONLY checks for mutual shadowing (eclipse) effects. It assumes that
the `illuminated` vector already contains the result of face orientation and/or
self-shadowing checks. Only faces marked as `true` in the input will be tested
for occlusion by the other body.

This separation allows flexible control of shadowing effects in thermal modeling:
- Call `update_illumination_*` first for self-shadowing (or face orientation only)
- Then call this function to add mutual shadowing effects

# Performance Optimizations
The function includes early-out checks at two levels:

## Body-level optimizations:
1. **Behind Check**: If the occluding body is entirely behind the target relative to the sun,
   no eclipse can occur.

2. **Lateral Separation Check**: If bodies are too far apart laterally (perpendicular to 
   sun direction), no eclipse can occur.

3. **Total Eclipse Check**: If the target is completely within the occluding body's shadow,
   all illuminated faces are set to false without individual ray checks.

## Face-level optimizations:
4. **Ray-Sphere Intersection Check**: For each face, checks if the ray to the sun can possibly
   intersect the occluding body's bounding sphere. Skips ray-shape test if the ray clearly
   misses the sphere.

5. **Inscribed Sphere Check**: If the ray passes through the occluding body's inscribed sphere,
   the face is guaranteed to be shadowed, avoiding the expensive ray-shape intersection test.

These optimizations use `maximum_radius` and `minimum_radius` for accurate sphere calculations.

# Coordinate Systems
The transformation from `shape1` frame to `shape2` frame is given by:
`p_shape2 = R₁₂ * p_shape1 + t₁₂`

# Example
```julia
# Check self-shadowing first (considering self-shadowing effect)
update_illumination_with_self_shadowing!(illuminated1, shape1, sun_position1)
update_illumination_with_self_shadowing!(illuminated2, shape2, sun_position2)

# Or if you want to ignore self-shadowing:
update_illumination_pseudo_convex!(illuminated1, shape1, sun_position1)
update_illumination_pseudo_convex!(illuminated2, shape2, sun_position2)

# Then check eclipse shadowing
# For checking mutual shadowing, apply to both shape1 and shape2:
status1 = apply_eclipse_shadowing!(illuminated1, shape1, sun_position1, R12, t12, shape2)
status2 = apply_eclipse_shadowing!(illuminated2, shape2, sun_position2, R21, t21, shape1)

# Handle eclipse status
if status1 == NO_ECLIPSE
    println("Shape1 is not eclipsed by shape2.")
elseif status1 == PARTIAL_ECLIPSE
    println("Shape1 is partially eclipsed by shape2.")
elseif status1 == TOTAL_ECLIPSE
    println("Shape1 is totally eclipsed by shape2.")
end
```
"""
function apply_eclipse_shadowing!(
    illuminated::AbstractVector{Bool}, shape1::ShapeModel, r☉₁::StaticVector{3},
    R₁₂::StaticMatrix{3,3}, t₁₂::StaticVector{3}, shape2::ShapeModel
)::EclipseStatus
    @assert length(illuminated) == length(shape1.faces) "illuminated vector must have same length as number of faces."
    isnothing(shape2.bvh) && throw(ArgumentError("Occluding shape model (`shape2`) must have BVH built before checking eclipse shadowing. Call `build_bvh!(shape2)` first."))
    
    r̂☉₁ = normalize(r☉₁)        # Normalized sun direction in shape1's frame
    r̂☉₂ = normalize(R₁₂ * r̂☉₁)  # Normalized sun direction in shape2's frame
    
    # Get bounding sphere radii for both shapes
    ρ₁ = maximum_radius(shape1)
    ρ₂ = maximum_radius(shape2)
    
    # Get inscribed sphere radius for shape2 (for guaranteed shadow regions)
    ρ₂_inner = minimum_radius(shape2)
    
    # ==== Early Out 1 (Behind Check) ====
    # If shape2 is entirely behind shape1 relative to sun, no eclipse occur.
    if dot(t₁₂, r̂☉₁) < -(ρ₁ + ρ₂)
        return NO_ECLIPSE  
    end
    
    # ==== Early Out 2 (Lateral Separation Check)  ====
    # If bodies are too far apart laterally, no eclipse occur.
    t₁₂⊥ = t₁₂ - (dot(t₁₂, r̂☉₁) * r̂☉₁)  # Component of t₁₂ perpendicular to sun direction
    d⊥ = norm(t₁₂⊥)                     # Lateral distance between bodies
    if d⊥ > ρ₁ + ρ₂
        return NO_ECLIPSE
    end
    
    # ==== Early Out 3 (Total Eclipse Check) ====
    # If shape1 is completely within shape2's shadow, all faces are shadowed.
    # This happens when shape2 is between sun and shape1, and is larger than shape1.
    # Check if shape2 is in front of shape1 along sun direction,
    # and if the lateral distance is small enough.
    if dot(t₁₂, r̂☉₁) > 0  && d⊥ + ρ₁ < ρ₂
        illuminated .= false  # All faces are shadowed.
        return TOTAL_ECLIPSE
    end
    
    # Track whether any eclipse occurred
    eclipse_occurred = false
    
    # Check occlusion by the other body for illuminated faces only
    @inbounds for i in eachindex(shape1.faces)
        if illuminated[i]  # Only check if not already in shadow
            # Ray from face center to sun in shape1's frame
            ray_origin1 = shape1.face_centers[i]
            
            # Transform ray's origin to shape2's frame
            ray_origin2 = R₁₂ * ray_origin1 + t₁₂
            
            # ==== Face-level Early Out ====
            # Check if the ray from this face to the sun can possibly intersect
            # shape2's bounding sphere.
            
            # Calculate the parameter t where the ray is closest to shape2's center.
            # Ray: P(t) = ray_origin2 + t * r̂☉₂, where t > 0 toward sun
            # The closest point is where d/dt |P(t)|² = 0
            t_min = -dot(ray_origin2, r̂☉₂)
            
            if t_min < 0
                # Shape2's center is in the opposite direction from the sun.
                # (i.e., the ray is moving away from shape2)
                # In this case, check if the face itself is outside bounding sphere.
                if norm(ray_origin2) > ρ₂
                    continue
                end
            else
                # The ray approaches shape2's center.
                # Calculate the closest point on the ray to the center
                p_closest = ray_origin2 + t_min * r̂☉₂
                d_center = norm(p_closest)
                
                # ==== Early Out 4 (Ray-Sphere Intersection Check) ====
                # If the ray passes within the bounding sphere,
                # ray misses the bounding sphere entirely.
                if d_center > ρ₂
                    continue
                end
                
                # ==== Early Out 5 (Inscribed Sphere Check) ====
                # If the ray passes through the inscribed sphere, it's guaranteed to hit shape2
                # (no need for detailed intersection test)
                if d_center < ρ₂_inner
                    illuminated[i] = false
                    eclipse_occurred = true
                    continue
                end
            end
            
            # Create ray in shape2's frame
            # (Direction was already transformed at the beginning of the function)
            ray2 = Ray(ray_origin2, r̂☉₂)
            
            # Check intersection with shape2
            if intersect_ray_shape(ray2, shape2).hit
                illuminated[i] = false
                eclipse_occurred = true
            end
        end
    end
    
    # Determine eclipse status based on results
    if !eclipse_occurred
        return NO_ECLIPSE
    elseif count(illuminated) == 0  # if all faces are now in shadow
        return TOTAL_ECLIPSE
    else
        return PARTIAL_ECLIPSE
    end
end