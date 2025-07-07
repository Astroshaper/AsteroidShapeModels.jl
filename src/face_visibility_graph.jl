#=
    face_visibility_graph.jl

This file implements the `FaceVisibilityGraph` data structure and related functions
for face-to-face visibility calculations. The graph stores visibility relationships
in a Compressed Sparse Row (CSR) format for efficient memory usage and cache locality.

Exported Types:
- `FaceVisibilityGraph`: CSR-style data structure for face visibility

Exported Functions:
- `view_factor`: Calculate the view factor between two triangular faces
- `build_face_visibility_graph!`: Build the face-to-face visibility graph
- `get_visible_face_indices`: Get indices of faces visible from a given face
- `get_view_factors`: Get view factors from a face to its visible faces
- `get_visible_face_distances`: Get distances to visible faces
- `get_visible_face_directions`: Get unit direction vectors to visible faces
- `get_visible_face_data`: Get all visibility data for a specific visible face
- `num_visible_faces`: Get number of faces visible from a given face
=#

# Type FaceVisibilityGraph is defined in types.jl

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Additional Constructors                         ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    FaceVisibilityGraph(nfaces::Int) -> FaceVisibilityGraph

Create an empty FaceVisibilityGraph with the specified number of faces.
"""
function FaceVisibilityGraph(nfaces::Int)
    row_ptr = ones(Int, nfaces + 1)
    FaceVisibilityGraph(row_ptr, Int[], Float64[], Float64[], SVector{3, Float64}[])
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                       Display Methods                             ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    Base.show(io::IO, graph::FaceVisibilityGraph)

Display FaceVisibilityGraph.
"""
function Base.show(io::IO, graph::FaceVisibilityGraph)
    print(io, "FaceVisibilityGraph:\n")
    print(io, "  Number of faces                : $(graph.nfaces)\n")
    print(io, "  Number of visible pairs        : $(graph.nnz)\n")
    if graph.nnz > 0
        avg_visible = graph.nnz / graph.nfaces
        print(io, "  Average visible faces per face : $(round(avg_visible, digits=2))\n")
    end
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      View Factor Calculation                      ║
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
# ║                      Data Access Methods                          ║
# ╚═══════════════════════════════════════════════════════════════════╝

# Internal helper function to get the range of indices for a face
function _get_visible_face_range(graph::FaceVisibilityGraph, face_idx::Int)
    @boundscheck 1 ≤ face_idx ≤ graph.nfaces || throw(BoundsError(graph, face_idx))
    start_idx = graph.row_ptr[face_idx]
    end_idx   = graph.row_ptr[face_idx + 1] - 1
    return start_idx:end_idx
end

"""
    get_visible_face_indices(graph::FaceVisibilityGraph, face_idx::Int) -> SubArray

Get indices of faces visible from the specified face.

# Arguments
- `graph`   : Face visibility graph
- `face_idx`: Source face index (1-based)

# Returns
- `SubArray{Int}`: View of face indices that are visible from the source face

# Example
```julia
# Get all faces visible from face 100
visible_face_indices = get_visible_face_indices(graph, 100)
println("Face 100 can see $(length(visible_face_indices)) faces")

# Iterate over visible faces
for j in visible_face_indices
    println("Face 100 can see face $j")
end
```

See also: [`get_view_factors`](@ref), [`get_visible_face_data`](@ref)
"""
function get_visible_face_indices(graph::FaceVisibilityGraph, face_idx::Int)
    range = _get_visible_face_range(graph, face_idx)
    return @view graph.col_idx[range]
end

"""
    get_view_factors(graph::FaceVisibilityGraph, face_idx::Int) -> SubArray

Get view factors from the specified face to all its visible faces.

# Arguments
- `graph`    : Face visibility graph
- `face_idx` : Source face index (1-based)

# Returns
- `SubArray{Float64}`: View of view factors corresponding to visible faces

# Notes
The returned array has the same length and ordering as `get_visible_face_indices`.
View factors represent the fraction of radiation leaving face `face_idx` that
directly reaches each visible face.

# Example
```julia
visible_face_indices = get_visible_face_indices(graph, 100)
view_factors = get_view_factors(graph, 100)

# Sum of view factors (always between 0 and 1)
# - Near 0 for convex shapes (most radiation escapes to space)  
# - Larger for concave regions (more reabsorption due to facing surfaces)
total_vf = sum(view_factors)
println("Total view factor from face 100: $total_vf")

# Pair indices with view factors
for (j, vf) in zip(visible_face_indices, view_factors)
    println("Face 100 -> Face $j: view factor = $vf")
end
```

See also: [`get_visible_face_indices`](@ref), [`view_factor`](@ref)
"""
function get_view_factors(graph::FaceVisibilityGraph, face_idx::Int)
    range = _get_visible_face_range(graph, face_idx)
    return @view graph.view_factors[range]
end

"""
    get_visible_face_distances(graph::FaceVisibilityGraph, face_idx::Int) -> SubArray

Get distances to visible faces from the specified face.

# Arguments
- `graph`    : Face visibility graph
- `face_idx` : Source face index (1-based)

# Returns
- `SubArray{Float64}`: View of distances (in meters) from face center to visible face centers

# Notes
The returned array has the same length and ordering as `get_visible_face_indices`.
Distances are computed between face centers during visibility graph construction.

# Example
```julia
visible_face_indices = get_visible_face_indices(graph, 100)
distances = get_visible_face_distances(graph, 100)

# Find the closest visible face
min_dist, idx = findmin(distances)
closest_face_idx = visible_face_indices[idx]
println("Closest visible face to face 100 is face $closest_face_idx at distance $min_dist m")
```

See also: [`get_visible_face_indices`](@ref), [`get_visible_face_directions`](@ref)
"""
function get_visible_face_distances(graph::FaceVisibilityGraph, face_idx::Int)
    range = _get_visible_face_range(graph, face_idx)
    return @view graph.distances[range]
end

"""
    get_visible_face_directions(graph::FaceVisibilityGraph, face_idx::Int) -> SubArray

Get unit direction vectors to visible faces from the specified face.

# Arguments
- `graph`    : Face visibility graph
- `face_idx` : Source face index (1-based)

# Returns
- `SubArray{SVector{3,Float64}}`: View of unit direction vectors from source face center to visible face centers

# Notes
The returned array has the same length and ordering as `get_visible_face_indices`.
Each vector points from the source face center to a visible face center and has unit length.

# Example
```julia
visible_face_indices = get_visible_face_indices(graph, 100)
directions = get_visible_face_directions(graph, 100)

# Calculate angle to each visible face
face_normal = shape.face_normals[100]
for (j, dir) in zip(visible_face_indices, directions)
    angle = acosd(face_normal ⋅ dir)  # Angle in degrees
    println("Face 100 -> Face $j: angle = $(round(angle, digits=1))°")
end
```

See also: [`get_visible_face_indices`](@ref), [`get_visible_face_distances`](@ref)
"""
function get_visible_face_directions(graph::FaceVisibilityGraph, face_idx::Int)
    range = _get_visible_face_range(graph, face_idx)
    return @view graph.directions[range]
end

"""
    get_visible_face_data(graph::FaceVisibilityGraph, face_idx::Int, idx::Int)

Get the idx-th visible face data for the specified face.

# Arguments
- `graph`    : Face visibility graph
- `face_idx` : Source face index (1-based)
- `idx`      : Index within the visible faces list (1-based)

# Returns
Named tuple with fields:
- `face_idx`    : Index of the visible face
- `view_factor` : View factor between the faces
- `distance`    : Distance between face centers
- `direction`   : Unit direction vector from source to visible face

# Example
```julia
# Get the third visible face from face 100
data = get_visible_face_data(graph, 100, 3)
println("Face 100 can see face $(data.face_idx) with view factor $(data.view_factor)")
```

See also: [`get_visible_face_indices`](@ref), [`get_view_factors`](@ref)
"""
function get_visible_face_data(graph::FaceVisibilityGraph, face_idx::Int, idx::Int)
    visible_faces = get_visible_face_indices(graph, face_idx)
    @boundscheck 1 ≤ idx ≤ length(visible_faces) || throw(BoundsError())
    
    base_idx = graph.row_ptr[face_idx] + idx - 1
    return (
        face_idx    = graph.col_idx[base_idx],
        view_factor = graph.view_factors[base_idx],
        distance    = graph.distances[base_idx],
        direction   = graph.directions[base_idx]
    )
end

"""
    num_visible_faces(graph::FaceVisibilityGraph, face_idx::Int) -> Int

Get the number of visible faces for the specified face.

# Arguments
- `graph`    : Face visibility graph
- `face_idx` : Source face index (1-based)

# Returns
- `Int`: Number of faces visible from the source face

# Example
```julia
# Count visible faces for each face
for i in 1:graph.nfaces
    n = num_visible_faces(graph, i)
    if n > 100
        println("Face $i can see $n other faces.")
    end
end

# Find the face with most visible faces
max_visible = 0
max_face = 0
for i in 1:graph.nfaces
    n = num_visible_faces(graph, i)
    if n > max_visible
        max_visible = n
        max_face = i
    end
end
println("Face $max_face has the most visible faces: $max_visible")
```

See also: [`get_visible_face_indices`](@ref), [`FaceVisibilityGraph`](@ref)
"""
function num_visible_faces(graph::FaceVisibilityGraph, face_idx::Int)
    @boundscheck 1 ≤ face_idx ≤ graph.nfaces || throw(BoundsError(graph, face_idx))
    return graph.row_ptr[face_idx + 1] - graph.row_ptr[face_idx]
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    Graph Construction                             ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    build_face_visibility_graph!(shape::ShapeModel)

Build face-to-face visibility graph for the shape model.

This function computes which faces are visible from each face and stores the results
in a `FaceVisibilityGraph` structure using CSR (Compressed Sparse Row) format.

# Arguments
- `shape` : Shape model of an asteroid

# Algorithm
The implementation uses an optimized non-BVH algorithm with candidate filtering:
1. Pre-filter candidate faces based on normal orientations
2. Sort candidates by distance for efficient occlusion testing
3. Check visibility between face pairs using ray-triangle intersection
4. Store results in memory-efficient CSR format

# Performance Considerations
- BVH acceleration was found to be less efficient for face visibility pair searches
  compared to the optimized candidate filtering approach (slower ~0.5x)
- The non-BVH implementation with distance-based sorting provides better performance
  due to the specific nature of face-to-face visibility queries
- Distance-based sorting provides ~2x speedup over naive approaches

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
    
    # Optimized non-BVH algorithm with candidate filtering
    # Loop structure:
    # - i: source face (viewpoint)
    # - j: candidate faces that might be visible from i (pre-filtered)
    # - k: potential occluding faces (from the same candidate list)
    for i in eachindex(faces)
        cᵢ = face_centers[i]
        n̂ᵢ = face_normals[i]
        aᵢ = face_areas[i]

        # Build list of candidate faces that are potentially visible from face i
        candidates = Int64[]   # Indices of candidate faces
        distances = Float64[]  # Distances to candidate faces from face i
        for j in eachindex(faces)
            i == j && continue
            cⱼ = face_centers[j]
            n̂ⱼ = face_normals[j]

            Rᵢⱼ = cⱼ - cᵢ
            if Rᵢⱼ ⋅ n̂ᵢ > 0 && Rᵢⱼ ⋅ n̂ⱼ < 0
                push!(candidates, j)
                push!(distances, norm(Rᵢⱼ))
            end
        end
        
        # Sort candidates by distance
        if !isempty(candidates)
            perm = sortperm(distances)
            candidates = candidates[perm]
            distances = distances[perm]
        end
        
        # Check visibility for each candidate face
        for (j, dᵢⱼ) in zip(candidates, distances)
            # Skip if already processed
            j in (vf.face_idx for vf in temp_visible[i]) && continue

            cⱼ = face_centers[j]
            n̂ⱼ = face_normals[j]
            aⱼ = face_areas[j]

            ray = Ray(cᵢ, cⱼ - cᵢ)  # Ray from face i to face j

            # Check if any face from the candidate list blocks the view from i to j
            blocked = false
            for (k, dᵢₖ) in zip(candidates, distances)
                k == j && continue
                dᵢₖ > dᵢⱼ  && continue  # Skip if face k is farther than face j
                
                intersection = intersect_ray_triangle(ray, shape, k)
                if intersection.hit
                    blocked = true
                    break
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
            col_idx[idx]      = vf.face_idx
            view_factors[idx] = vf.view_factor
            distances[idx]    = vf.distance
            directions[idx]   = vf.direction
            idx += 1
        end
    end
    
    shape.face_visibility_graph = FaceVisibilityGraph(row_ptr, col_idx, view_factors, distances, directions)
end
