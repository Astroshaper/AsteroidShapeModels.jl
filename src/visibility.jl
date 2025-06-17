################################################################
#                 Face-to-face interactions
################################################################

"""
    view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ) -> fᵢⱼ, dᵢⱼ, d̂ᵢⱼ

Calculate the view factor from face i to face j, assuming Lambertian emission.

# Arguments
- `cᵢ::StaticVector{3}`: Center position of face i
- `cⱼ::StaticVector{3}`: Center position of face j
- `n̂ᵢ::StaticVector{3}`: Unit normal vector of face i
- `n̂ⱼ::StaticVector{3}`: Unit normal vector of face j
- `aⱼ::Real`           : Area of face j

# Returns
- `fᵢⱼ::Real`: View factor from face i to face j
- `dᵢⱼ::Real`: Distance between face centers
- `d̂ᵢⱼ::StaticVector{3}`: Unit direction vector from face i to face j

# Notes
The view factor is calculated using the formula:
```
fᵢⱼ = (cosθᵢ * cosθⱼ) / (π * dᵢⱼ²) * aⱼ
```
where θᵢ and θⱼ are the angles between the line connecting the faces
and the respective normal vectors.

The view factor is automatically zero when:
- Face i is facing away from face j (cosθᵢ ≤ 0)
- Face j is facing away from face i (cosθⱼ ≤ 0)
- Both conditions ensure that only mutually visible faces have non-zero view factors

# Visual representation
```
(i)   fᵢⱼ   (j)
 △    -->    △
```
"""
function view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ)
    cᵢⱼ = cⱼ - cᵢ    # Vector from face i to face j
    dᵢⱼ = norm(cᵢⱼ)  # Distance between face centers
    d̂ᵢⱼ = cᵢⱼ / dᵢⱼ  # Unit direction vector from face i to face j (more efficient than normalize())

    # Calculate cosines of angles between normals and the line connecting faces
    # cosθᵢ: How much face i is oriented towards face j (positive if facing towards)
    # cosθⱼ: How much face j is oriented towards face i (negative dot product because we need the opposite direction)
    cosθᵢ = max(0.0,  n̂ᵢ ⋅ d̂ᵢⱼ)  # Zero if face i is facing away from face j
    cosθⱼ = max(0.0, -n̂ⱼ ⋅ d̂ᵢⱼ)  # Zero if face j is facing away from face i

    # View factor is zero if either face is not facing the other
    fᵢⱼ = cosθᵢ * cosθⱼ * aⱼ / (π * dᵢⱼ^2)
    return fᵢⱼ, dᵢⱼ, d̂ᵢⱼ
end

"""
    find_visiblefacets!(shape::ShapeModel; use_visibility_graph=true, show_progress=true)

Find facets that is visible from the facet where the observer is located.

# Arguments
- `shape` : Shape model of an asteroid

# Keyword Arguments
- `use_visibility_graph::Bool=true`: Use the new FaceVisibilityGraph implementation for better performance
- `show_progress::Bool=true`: Show progress (currently unused, kept for compatibility)

# Notes
When `use_visibility_graph=true`, both `visiblefacets` and `visibility_graph` fields are populated
to maintain backward compatibility. The `visiblefacets` field will be deprecated in v1.0.0.
"""
function find_visiblefacets!(shape::ShapeModel; use_visibility_graph=true, show_progress=true)
    if use_visibility_graph
        _find_visiblefacets_graph!(shape)
    else
        _find_visiblefacets_legacy!(shape)
    end
end

# New implementation: Using FaceVisibilityGraph
function _find_visiblefacets_graph!(shape::ShapeModel)
    nodes = shape.nodes
    faces = shape.faces
    face_centers = shape.face_centers
    face_normals = shape.face_normals
    face_areas = shape.face_areas
    
    # Accumulate temporary visible face data
    temp_visible = [Vector{VisibleFacet}() for _ in faces]
    
    for i in eachindex(faces)
        cᵢ = face_centers[i]
        n̂ᵢ = face_normals[i]
        aᵢ = face_areas[i]

        candidates = Int64[]
        for j in eachindex(faces)
            i == j && continue
            cⱼ = face_centers[j]
            n̂ⱼ = face_normals[j]

            Rᵢⱼ = cⱼ - cᵢ
            Rᵢⱼ ⋅ n̂ᵢ > 0 && Rᵢⱼ ⋅ n̂ⱼ < 0 && push!(candidates, j)
        end
        
        for j in candidates
            j in (vf.id for vf in temp_visible[i]) && continue
            cⱼ = face_centers[j]
            n̂ⱼ = face_normals[j]
            aⱼ = face_areas[j]

            Rᵢⱼ = cⱼ - cᵢ
            dᵢⱼ = norm(Rᵢⱼ)
            
            blocked = false
            for k in candidates
                j == k && continue
                cₖ = face_centers[k]

                Rᵢₖ = cₖ - cᵢ
                dᵢₖ = norm(Rᵢₖ)
                
                dᵢⱼ < dᵢₖ && continue
                
                ray = Ray(cᵢ, Rᵢⱼ)
                A, B, C = nodes[faces[k][1]], nodes[faces[k][2]], nodes[faces[k][3]]
                intersection = intersect_ray_triangle(ray, A, B, C)
                if intersection.hit
                    blocked = true
                    break
                end
            end

            blocked && continue
            push!(temp_visible[i], VisibleFacet(j, view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ)...))
            push!(temp_visible[j], VisibleFacet(i, view_factor(cⱼ, cᵢ, n̂ⱼ, n̂ᵢ, aᵢ)...))
        end
    end
    
    # Build FaceVisibilityGraph
    shape.visibility_graph = from_adjacency_list(temp_visible)
    
    # Also update visiblefacets for backward compatibility
    shape.visiblefacets .= temp_visible
end

# Legacy implementation: Traditional method (with deprecation warning)
function _find_visiblefacets_legacy!(shape::ShapeModel)
    @warn "Legacy visibility algorithm will be removed in v1.0.0. Set use_visibility_graph=true for better performance." maxlog=1
    
    nodes = shape.nodes
    faces = shape.faces
    face_centers = shape.face_centers
    face_normals = shape.face_normals
    face_areas = shape.face_areas
    visiblefacets = shape.visiblefacets

    for i in eachindex(faces)
        cᵢ = face_centers[i]
        n̂ᵢ = face_normals[i]
        aᵢ = face_areas[i]

        candidates = Int64[]
        for j in eachindex(faces)
            i == j && continue
            cⱼ = face_centers[j]
            n̂ⱼ = face_normals[j]

            Rᵢⱼ = cⱼ - cᵢ
            Rᵢⱼ ⋅ n̂ᵢ > 0 && Rᵢⱼ ⋅ n̂ⱼ < 0 && push!(candidates, j)
        end
        
        for j in candidates
            j in (visiblefacet.id for visiblefacet in visiblefacets[i]) && continue
            cⱼ = face_centers[j]
            n̂ⱼ = face_normals[j]
            aⱼ = face_areas[j]

            Rᵢⱼ = cⱼ - cᵢ
            dᵢⱼ = norm(Rᵢⱼ)
            
            blocked = false
            for k in candidates
                j == k && continue
                cₖ = face_centers[k]

                Rᵢₖ = cₖ - cᵢ
                dᵢₖ = norm(Rᵢₖ)
                
                dᵢⱼ < dᵢₖ && continue
                
                ray = Ray(cᵢ, Rᵢⱼ)
                A, B, C = nodes[faces[k][1]], nodes[faces[k][2]], nodes[faces[k][3]]
                intersection = intersect_ray_triangle(ray, A, B, C)
                if intersection.hit
                    blocked = true
                    break
                end
            end

            blocked && continue
            push!(visiblefacets[i], VisibleFacet(j, view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ)...))
            push!(visiblefacets[j], VisibleFacet(i, view_factor(cⱼ, cᵢ, n̂ⱼ, n̂ᵢ, aᵢ)...))
        end
    end
end

"""
    isilluminated(shape::ShapeModel, r☉::StaticVector{3}, i::Integer) -> Bool

Return if the `i`-th face of the `shape` model is illuminated by the direct sunlight or not

# Arguments
- `shape` : Shape model of an asteroid
- `r☉`    : Sun's position in the asteroid-fixed frame, which doesn't have to be normalized.
- `i`     : Index of the face to be checked
"""
function isilluminated(shape::ShapeModel, r☉::StaticVector{3}, i::Integer)
    cᵢ = shape.face_centers[i]
    n̂ᵢ = shape.face_normals[i]
    r̂☉ = normalize(r☉)

    n̂ᵢ ⋅ r̂☉ < 0 && return false

    ray = Ray(cᵢ, r̂☉)  # Ray from face center to the sun's position

    # Use FaceVisibilityGraph if available
    if !isnothing(shape.visibility_graph)
        visible_faces = get_visible_faces(shape.visibility_graph, i)
        for j in visible_faces
            face = shape.faces[j]
            A = shape.nodes[face[1]]
            B = shape.nodes[face[2]]
            C = shape.nodes[face[3]]

            intersect_ray_triangle(ray, A, B, C).hit && return false
        end
    else
        # Fallback to legacy implementation
        for visiblefacet in shape.visiblefacets[i]
            face = shape.faces[visiblefacet.id]
            A = shape.nodes[face[1]]
            B = shape.nodes[face[2]]
            C = shape.nodes[face[3]]

            intersect_ray_triangle(ray, A, B, C).hit && return false
        end
    end
    return true
end
