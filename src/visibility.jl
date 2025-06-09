################################################################
#                 Face-to-face interactions
################################################################

"""
    view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ) -> fᵢⱼ, dᵢⱼ, d̂ᵢⱼ

Calculate the view factor from facet i to facet j, assuming Lambertian emission.

# Arguments
- `cᵢ::StaticVector{3}`: Center position of facet i
- `cⱼ::StaticVector{3}`: Center position of facet j
- `n̂ᵢ::StaticVector{3}`: Unit normal vector of facet i
- `n̂ⱼ::StaticVector{3}`: Unit normal vector of facet j
- `aⱼ::Real`           : Area of facet j

# Returns
- `fᵢⱼ::Real`: View factor from facet i to facet j
- `dᵢⱼ::Real`: Distance between facet centers
- `d̂ᵢⱼ::StaticVector{3}`: Unit direction vector from facet i to facet j

# Notes
The view factor is calculated using the formula:
```
fᵢⱼ = (cosθᵢ * cosθⱼ) / (π * dᵢⱼ²) * aⱼ
```
where θᵢ and θⱼ are the angles between the line connecting the facets
and the respective normal vectors.

# Visual representation
```
(i)   fᵢⱼ   (j)
 △    -->    △
```
"""
function view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ)
    dᵢⱼ = norm(cⱼ - cᵢ)
    d̂ᵢⱼ = normalize(cⱼ - cᵢ)

    cosθᵢ = n̂ᵢ ⋅ d̂ᵢⱼ
    cosθⱼ = n̂ⱼ ⋅ (-d̂ᵢⱼ)

    fᵢⱼ = cosθᵢ * cosθⱼ / (π * dᵢⱼ^2) * aⱼ
    fᵢⱼ, dᵢⱼ, d̂ᵢⱼ
end

"""
    find_visiblefacets!(shape::ShapeModel; show_progress=true)

Find facets that is visible from the facet where the observer is located.

# Arguments
- `shape` : Shape model of an asteroid
"""
function find_visiblefacets!(shape::ShapeModel)
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

    for visiblefacet in shape.visiblefacets[i]
        face = shape.faces[visiblefacet.id]
        A, B, C = shape.nodes[face[1]], shape.nodes[face[2]], shape.nodes[face[3]]
        ray = Ray(cᵢ, r̂☉)
        intersect_ray_triangle(ray, A, B, C).hit && return false
    end
    return true
end
