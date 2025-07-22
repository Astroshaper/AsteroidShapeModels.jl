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

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                        Eclipse Status Types                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

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

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    Eclipse Shadowing Functions                    ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    apply_eclipse_shadowing!(
        illuminated_faces::AbstractVector{Bool}, shape1::ShapeModel, shape2::ShapeModel,
        r☉₁::StaticVector{3}, r₁₂::StaticVector{3}, R₁₂::StaticMatrix{3,3}
    ) -> EclipseStatus

Apply eclipse shadowing effects from shape2 onto shape1's already illuminated faces.

This is the recommended API as of v0.4.1, with more intuitive parameter ordering and direct use of shape2's position.

!!! note
    As of v0.4.0, `shape2` must have BVH pre-built before calling this function.
    Use either `with_bvh=true` when loading or call `build_bvh!(shape2)` explicitly.

!!! tip "New in v0.4.1"
    This function signature directly accepts `r₁₂` (shape2's position in shape1's frame),
    which is more intuitive when working with SPICE data. The older signature using `t₁₂`
    is maintained for backward compatibility but will be removed in v0.5.0.

!!! warning "OPTIMIZE"
    Current implementation calls `intersect_ray_shape` per face, causing ~200 allocations per call.
    For binary asteroid thermophysical simulations, this results in ~200 allocations × 2 bodies × 
    number of time steps. Future optimization should implement true batch ray tracing for mutual 
    shadowing to reduce allocation overhead.

!!! note "TODO"
    - **Parallel processing**: Add multi-threading support using `@threads` for face-level calculations.
      Each face's shadow test is independent, making this function ideal for parallelization.
    
    - **Spatial optimization**: Implement spatial data structures (e.g., octree) to pre-filter faces
      that could potentially be shadowed, reducing unnecessary ray tests.
    
    - **Caching for temporal coherence**: For simulations with small time steps, implement caching
      to reuse shadow information from previous time steps when relative positions change gradually.

# Arguments
- `illuminated_faces` : Boolean vector with current illumination state (will be modified)
- `shape1`            : Target shape model being shadowed (the shape receiving shadows)
- `shape2`            : Occluding shape model that may cast shadows on `shape1` (must have BVH built)
- `r☉₁`               : Sun's position in shape1's frame
- `r₁₂`               : Shape2's position in shape1's frame (e.g., secondary's position from SPICE)
- `R₁₂`               : 3×3 rotation matrix from `shape1` frame to `shape2` frame

# Returns
- `NO_ECLIPSE`: No eclipse occurs (bodies are misaligned).
- `PARTIAL_ECLIPSE`: Some faces that were illuminated are now in shadow by the occluding body.
- `TOTAL_ECLIPSE`: All faces that were illuminated are now in shadow.

# Throws
- `ArgumentError` if `shape2` does not have BVH built. Call `build_bvh!(shape2)` before using this function.

# Description
This function ONLY checks for mutual shadowing (eclipse) effects. It assumes that
the `illuminated_faces` vector already contains the result of face orientation and/or
self-shadowing checks. Only faces marked as `true` in the input will be tested
for occlusion by the other body.

# Example with SPICE integration
```julia
# Get positions and orientations from SPICE
et = ...               # Ephemeris time
sun_pos1 = ...         # Sun's position in primary's frame
secondary_pos = ...    # Secondary's position in primary's frame  
P2S = ...              # Rotation matrix from primary to secondary frame

# Calcuate required transformation
sun_pos2 = P2S * sun_pos1           # Sun's position in secondary's frame
S2P = P2S'                          # Inverse rotation
primary_pos = -S2P * secondary_pos  # Primary's position in secondary's frame

# Check self-shadowing first
update_illumination!(illuminated_faces1, shape1, sun_pos1; with_self_shadowing=true)
update_illumination!(illuminated_faces2, shape2, sun_pos2; with_self_shadowing=true)

# For primary eclipsed by secondary
status1 = apply_eclipse_shadowing!(illuminated_faces1, shape1, shape2, sun_pos1, secondary_pos, P2S)

# For secondary eclipsed by primary
status2 = apply_eclipse_shadowing!(illuminated_faces2, shape2, shape1, sun_pos2, primary_pos, S2P)
```

See also: [`update_illumination!`](@ref), [`EclipseStatus`](@ref)
"""
function apply_eclipse_shadowing!(
    illuminated_faces::AbstractVector{Bool}, shape1::ShapeModel, shape2::ShapeModel,
    r☉₁::StaticVector{3}, r₁₂::StaticVector{3}, R₁₂::StaticMatrix{3,3}
)::EclipseStatus
    @assert length(illuminated_faces) == length(shape1.faces) "illuminated_faces vector must have same length as number of faces."
    isnothing(shape2.bvh) && throw(ArgumentError("Occluding shape model (`shape2`) must have BVH built before checking eclipse shadowing. Call `build_bvh!(shape2)` first."))
    
    # Compute transformation parameter t₁₂ for coordinate transformation
    # p_shape2 = R₁₂ * p_shape1 + t₁₂, where shape2's origin is at r₁₂ in shape1's frame
    # Therefore: 0 = R₁₂ * r₁₂ + t₁₂, so t₁₂ = -R₁₂ * r₁₂
    t₁₂ = -R₁₂ * r₁₂
    
    r̂☉₁ = normalize(r☉₁)              # Normalized sun direction in shape1's frame
    r̂☉₂ = normalize(R₁₂ * r☉₁ + t₁₂)  # Normalized sun direction in shape2's frame
    
    # Get bounding sphere radii for both shapes
    ρ₁ = maximum_radius(shape1)
    ρ₂ = maximum_radius(shape2)
    
    # Get inscribed sphere radius for shape2 (for guaranteed shadow regions)
    ρ₂_inner = minimum_radius(shape2)
    
    # ==== Early Out 1 (Behind Check) ====
    # If shape2 is entirely behind shape1 relative to sun, no eclipse occur.
    if dot(r₁₂, r̂☉₁) < -(ρ₁ + ρ₂)
        return NO_ECLIPSE  
    end
    
    # ==== Early Out 2 (Lateral Separation Check)  ====
    # If bodies are too far apart laterally, no eclipse occur.
    r₁₂⊥ = r₁₂ - (dot(r₁₂, r̂☉₁) * r̂☉₁)  # Component of r₁₂ perpendicular to sun direction
    d⊥ = norm(r₁₂⊥)                     # Lateral distance between bodies
    if d⊥ > ρ₁ + ρ₂
        return NO_ECLIPSE
    end
    
    # ==== Early Out 3 (Total Eclipse Check) ====
    # If shape1 is completely within shape2's shadow, all faces are shadowed.
    # This happens when shape2 is between sun and shape1, and is larger than shape1.
    # Check if shape2 is in front of shape1 along sun direction,
    # and if the lateral distance is small enough.
    if dot(r₁₂, r̂☉₁) > 0  && d⊥ + ρ₁ < ρ₂_inner
        illuminated_faces .= false  # All faces are shadowed.
        return TOTAL_ECLIPSE
    end
    
    # Track whether any eclipse occurred
    eclipse_occurred = false
    
    # Check occlusion by the other body for illuminated faces only
    @inbounds for i in eachindex(shape1.faces)
        if illuminated_faces[i]  # Only check if not already in shadow
            
            # Create ray in shape2's frame
            ray_origin1 = shape1.face_centers[i]   # Ray from face center to sun in shape1's frame
            ray_origin2 = R₁₂ * ray_origin1 + t₁₂  # Transform ray's origin to shape2's frame
            ray2 = Ray(ray_origin2, r̂☉₂)
            
            # ==== Face-level Early Out ====
            # Check if the ray from this face to the sun can possibly intersect
            # shape2's bounding sphere.
            
            # Create spheres for shape2's bounding and inscribed spheres
            # (shape2 is centered at origin in its own frame)
            outer_sphere = Sphere(SVector(0.0, 0.0, 0.0), ρ₂)
            inner_sphere = Sphere(SVector(0.0, 0.0, 0.0), ρ₂_inner)
            
            # Check intersection with bounding sphere
            outer_sphere_result = intersect_ray_sphere(ray2, outer_sphere)
            
            # ==== Early Out 4 (Ray-Sphere Intersection Check) ====
            # If the ray misses the bounding sphere entirely, skip detailed test
            !outer_sphere_result.hit && continue
            
            # Check if ray origin is inside the bounding sphere
            if outer_sphere_result.distance1 < 0 && outer_sphere_result.distance2 > 0
                # Ray origin is inside bounding sphere
                # This can happen when the face is within shape2's bounding sphere
                # In this case, we still need to check detailed intersection
            elseif outer_sphere_result.distance2 < 0
                # Both intersection points are behind the ray origin
                # This means the sphere is entirely behind the face (opposite from sun)
                # No eclipse possible from this configuration
                continue
            else
                # ==== Early Out 5 (Inscribed Sphere Check) ====
                # If the ray passes through the inscribed sphere, it's guaranteed to hit shape2
                inner_sphere_result = intersect_ray_sphere(ray2, inner_sphere)
                if inner_sphere_result.hit && inner_sphere_result.distance1 > 0
                    illuminated_faces[i] = false
                    eclipse_occurred = true
                    continue
                end
            end
            
            # Check intersection with shape2
            if intersect_ray_shape(ray2, shape2).hit
                illuminated_faces[i] = false
                eclipse_occurred = true
            end
        end
    end
    
    # Determine eclipse status based on results
    if !eclipse_occurred
        return NO_ECLIPSE
    elseif count(illuminated_faces) == 0  # if all faces are now in shadow
        return TOTAL_ECLIPSE
    else
        return PARTIAL_ECLIPSE
    end
end
