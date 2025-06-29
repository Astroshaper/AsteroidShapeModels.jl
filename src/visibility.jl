#=
    visibility.jl

This file implements face-to-face visibility calculations for asteroid shape models.
It includes functions for computing view factors between faces, building visibility
graphs, and determining illumination conditions. These calculations are essential
for thermal modeling, radiative heat transfer analysis, and understanding the
surface energy balance of asteroids.

Exported Functions:
- `view_factor`: Calculate the view factor between two triangular faces
- `build_face_visibility_graph!`: Build the face-to-face visibility graph
- `isilluminated`: Check if a face is illuminated by direct sunlight
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    View Factor Calculations                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

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

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                 Face Visibility Graph Construction                ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    build_face_visibility_graph!(shape::ShapeModel)

Build face-to-face visibility graph for the shape model.

This function computes which faces are visible from each face and stores the results
in a `FaceVisibilityGraph` structure using CSR (Compressed Sparse Row) format.

# Arguments
- `shape` : Shape model of an asteroid

# Notes
- The visibility graph is stored in `shape.face_visibility_graph`
- This is a computationally intensive operation, especially for large models
- The resulting graph contains view factors, distances, and direction vectors
"""
function build_face_visibility_graph!(shape::ShapeModel)
    nodes = shape.nodes
    faces = shape.faces
    face_centers = shape.face_centers
    face_normals = shape.face_normals
    face_areas   = shape.face_areas
    
    # Accumulate temporary visible face data
    temp_visible = [Vector{VisibleFace}() for _ in faces]
    
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
            d̂ᵢⱼ = Rᵢⱼ / dᵢⱼ  # Normalized direction
            
            # Use BVH to check for obstructions
            blocked = false
            
            if !isnothing(shape.bvh)
                # Create ray from face i to face j
                origins    = reshape([cᵢ[1], cᵢ[2], cᵢ[3]], 3, 1)
                directions = reshape([d̂ᵢⱼ[1], d̂ᵢⱼ[2], d̂ᵢⱼ[3]], 3, 1)
                
                # Traverse BVH to find all potential intersections
                traversal = ImplicitBVH.traverse_rays(shape.bvh, origins, directions)
                
                # Check if any face blocks the path
                for contact in traversal.contacts
                    k = Int(contact[1])  # Face index
                    k == i && continue   # Skip source face
                    k == j && continue   # Skip target face
                    
                    # Perform actual intersection test
                    ray = Ray(cᵢ, d̂ᵢⱼ)
                    result = intersect_ray_triangle(ray, shape, k)
                    if result.hit && result.distance < dᵢⱼ
                        blocked = true
                        break
                    end
                end
            else
                # Fallback to linear search if BVH not available
                for k in candidates
                    j == k && continue
                    cₖ = face_centers[k]

                    Rᵢₖ = cₖ - cᵢ
                    dᵢₖ = norm(Rᵢₖ)
                    
                    dᵢⱼ < dᵢₖ && continue
                    
                    ray = Ray(cᵢ, Rᵢⱼ)
                    intersection = intersect_ray_triangle(ray, shape, k)
                    if intersection.hit
                        blocked = true
                        break
                    end
                end
            end

            blocked && continue
            push!(temp_visible[i], VisibleFace(j, view_factor(cᵢ, cⱼ, n̂ᵢ, n̂ⱼ, aⱼ)...))
            push!(temp_visible[j], VisibleFace(i, view_factor(cⱼ, cᵢ, n̂ⱼ, n̂ᵢ, aᵢ)...))
        end
    end
    
    # Build FaceVisibilityGraph directly in CSR format
    nfaces = length(faces)
    nnz = sum(length.(temp_visible))
    
    # Build CSR format data
    row_ptr = Vector{Int}(undef, nfaces + 1)
    col_idx = Vector{Int}(undef, nnz)
    view_factors = Vector{Float64}(undef, nnz)
    distances = Vector{Float64}(undef, nnz)
    directions = Vector{SVector{3, Float64}}(undef, nnz)
    
    # Build row_ptr
    row_ptr[1] = 1
    for i in 1:nfaces
        row_ptr[i + 1] = row_ptr[i] + length(temp_visible[i])
    end
    
    # Copy data
    idx = 1
    for i in 1:nfaces
        for vf in temp_visible[i]
            col_idx[idx] = vf.id
            view_factors[idx] = vf.f
            distances[idx] = vf.d
            directions[idx] = vf.d̂
            idx += 1
        end
    end
    
    shape.face_visibility_graph = FaceVisibilityGraph(row_ptr, col_idx, view_factors, distances, directions)
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                       Illumination Analysis                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

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

    # Use BVH if available for faster ray intersection
    if !isnothing(shape.bvh)
        # Use ImplicitBVH to check for any obstruction
        origins    = reshape([cᵢ[1], cᵢ[2], cᵢ[3]], 3, 1)
        directions = reshape([r̂☉[1], r̂☉[2], r̂☉[3]], 3, 1)
        
        # Traverse BVH to find all potential intersections
        traversal = ImplicitBVH.traverse_rays(shape.bvh, origins, directions)
        
        # Check for any valid intersection (excluding self-intersection)
        for contact in traversal.contacts
            j = Int(contact[1])  # Face index
            j == i && continue   # Skip self-intersection
            
            # Perform actual intersection test
            intersect_ray_triangle(ray, shape, j).hit && return false
        end
        return true  # No obstruction found
    end
    
    # Fallback to FaceVisibilityGraph
    if !isnothing(shape.face_visibility_graph)
        visible_faces = get_visible_face_indices(shape.face_visibility_graph, i)
        for j in visible_faces
            intersect_ray_triangle(ray, shape, j).hit && return false
        end
        return true  # No obstruction found
    end

    return true  # No obstruction found
end
