"""
    load_shape_obj(shapepath; scale=1.0, find_visible_facets=false; show_progress=true)

Load a shape model from a Wavefront OBJ file.

# Arguments
- `shapepath` : Path to a Wavefront OBJ file

# Keyword arguments
- `scale`               : Scale factor of the shape model
- `find_visible_facets` : Switch to find visible facets
- `show_progress`       : Switch to show a progress meter
"""
function load_shape_obj(shapepath; scale=1.0, find_visible_facets=false)
    nodes, faces = loadobj(shapepath; scale = scale, message = false)

    face_centers = [face_center(nodes[face]) for face in faces]
    face_normals = [face_normal(nodes[face]) for face in faces]
    face_areas   = [face_area(nodes[face])   for face in faces]

    visiblefacets = [VisibleFacet[] for _ in faces]

    shape = ShapeModel(nodes, faces, face_centers, face_normals, face_areas, visiblefacets)
    find_visible_facets && find_visiblefacets!(shape)
    
    return shape
end

################################################################
#               Create a shape model from grid
################################################################

"""
    grid_to_faces(xs::AbstractVector, ys::AbstractVector, zs::AbstractMatrix) -> nodes, faces

Convert a regular grid (x, y) and corresponding z-coordinates to triangular facets

    | ⧹| ⧹| ⧹|
j+1 ・--C--D--・
    |⧹ |⧹ |⧹ |
    | ⧹| ⧹| ⧹|
j   ・--A--B--・
    |⧹ |⧹ |⧹ |
       i  i+1

# Arguments
- `xs::AbstractVector` : x-coordinates of grid points (should be sorted)
- `ys::AbstractVector` : y-coordinates of grid points (should be sorted)
- `zs::AbstractMatrix` : z-coordinates of grid points
"""
function grid_to_faces(xs::AbstractVector, ys::AbstractVector, zs::AbstractMatrix)
    nodes = SVector{3, Float64}[]
    faces = SVector{3, Int}[]

    for j in eachindex(ys)
        for i in eachindex(xs)
            push!(nodes, @SVector [xs[i], ys[j], zs[i, j]])
        end
    end

    for j in eachindex(ys)[begin:end-1]
        for i in eachindex(xs)[begin:end-1]
            ABC = @SVector [i + (j-1)*length(xs), i+1 + (j-1)*length(xs), i + j*length(xs)]
            DCB = @SVector [i+1 + j*length(xs), i + j*length(xs), i+1 + (j-1)*length(xs)]

            push!(faces, ABC, DCB)
        end
    end

    return nodes, faces
end

"""
    load_shape_grid(xs, ys, zs; scale=1.0, find_visible_facets=false) -> shape

Convert a regular grid (x, y) to a shape model

# Arguments
- `xs::AbstractVector` : x-coordinates of grid points
- `ys::AbstractVector` : y-coordinates of grid points
- `zs::AbstractMatrix` : z-coordinates of grid points
"""
function load_shape_grid(xs::AbstractVector, ys::AbstractVector, zs::AbstractMatrix; scale=1.0, find_visible_facets=false)
    nodes, faces = grid_to_faces(xs, ys, zs)
    nodes .*= scale
    
    face_centers = [face_center(nodes[face]) for face in faces]
    face_normals = [face_normal(nodes[face]) for face in faces]
    face_areas   = [face_area(nodes[face])   for face in faces]

    visiblefacets = [VisibleFacet[] for _ in faces]

    shape = ShapeModel(nodes, faces, face_centers, face_normals, face_areas, visiblefacets)
    find_visible_facets && find_visiblefacets!(shape)
    
    return shape
end

################################################################
#                      Shape properites
################################################################

"""
    polyhedron_volume(nodes, faces)      -> vol
    polyhedron_volume(shape::ShapeModel) -> vol

Calculate volume of a polyhedral
"""
function polyhedron_volume(nodes, faces)
    volume = 0.
    for face in faces
        A, B, C = nodes[face]
        volume += (A × B) ⋅ C / 6
    end
    volume
end

polyhedron_volume(shape::ShapeModel) = polyhedron_volume(shape.nodes, shape.faces)

equivalent_radius(VOLUME::Real) = (3VOLUME/4π)^(1/3)
equivalent_radius(shape::ShapeModel) = equivalent_radius(polyhedron_volume(shape))

maximum_radius(nodes) = maximum(norm, nodes)
maximum_radius(shape::ShapeModel) = maximum_radius(shape.nodes)

minimum_radius(nodes) = minimum(norm, nodes)
minimum_radius(shape::ShapeModel) = minimum_radius(shape.nodes)