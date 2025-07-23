#=
    hierarchical_shape_model.jl

Implements hierarchical shape models for multi-scale surface representation.
This allows detailed surface features (craters, boulders, roughness) to be
added to base shape models while maintaining computational efficiency.

The hierarchical structure uses:
- Base shape model (ShapeModel) for global geometry
- Detail shape models (ShapeModel) for localized surface roughness
- Transformation matrices and scales stored as arrays
- Efficient indexing for O(1) access to face details
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                        Type Definition                            ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    HierarchicalShapeModel <: AbstractShapeModel

A shape model that supports multi-scale surface representation through surface roughness models.

# Fields
- `global_shape`           : `ShapeModel` to represent the global shape of the asteroid
- `face_roughness_indices` : Mapping from face index to roughness model index (0 = no roughness)
- `roughness_models`       : Vector of `ShapeModel` objects representing surface roughness
- `roughness_model_scales` : Vector of scale factors for each roughness model

# Description
This structure allows representing asteroid surfaces at two scales:
1. **Global scale**: The overall asteroid shape (`global_shape`)
2. **Local scale**: Surface roughness models attached to individual faces (`roughness_models`)

Each face of the global shape can have at most one roughness model attached to it.
The `face_roughness_indices` array provides O(1) access to roughness models for any face.

# Coordinate System Convention

The local coordinate system for each roughness model follows geographic conventions:

1. **Origin**: Face center, corresponding to (0.5, 0.5) in the roughness model's UV coordinates
2. **Z-axis**: Face normal (outward), representing "up" or elevation
3. **Y-axis**: Points towards north (projected onto the face plane)
4. **X-axis**: Points east (completing a right-handed coordinate system)

This convention ensures that:
- Roughness models have consistent north-aligned orientation across the surface
- UV coordinates [0,1]×[0,1] map naturally to local coordinates with (0.5, 0.5) at origin
- Height/elevation data in the roughness model corresponds to the local Z direction
- Solar azimuth angles can be computed intuitively (north = 0°, east = 90°)

# Example
```julia
# Load global shape
global_shape = load_shape_obj("path/to/shape.obj", scale=1000)

# Create hierarchical model
hier_shape = HierarchicalShapeModel(global_shape)

# Add crater roughness to specific faces
crater = load_shape_obj("crater_roughness.obj", scale=10)
add_roughness_model!(hier_shape, face_idx, crater, 0.01)
```

# Implementation Notes

Currently, the coordinate transformations between global and local systems are computed
on-the-fly based on face geometry. This design prioritizes memory efficiency and simplicity.

## Future Considerations

For performance-critical applications, consider pre-computing and storing transformation matrices:
- Add fields: `global_to_local_rotations::Vector{SMatrix{3,3}}` and `global_to_local_translations::Vector{SVector{3}}`
- Trade-off: ~25% increase in memory usage for O(1) transformation access
- Benefit: Faster coordinate transformations in intensive calculations
- Additional flexibility: Support custom orientations beyond the default north-aligned system

See also: [`AbstractShapeModel`](@ref), [`ShapeModel`](@ref)
"""
mutable struct HierarchicalShapeModel <: AbstractShapeModel
    global_shape           ::ShapeModel
    face_roughness_indices ::Vector{Int}
    roughness_models       ::Vector{ShapeModel}
    roughness_model_scales ::Vector{Float64}
    
    function HierarchicalShapeModel(global_shape::ShapeModel)
        nfaces = length(global_shape.faces)
        face_roughness_indices = zeros(Int, nfaces)
        return new(
            global_shape,
            face_roughness_indices,
            ShapeModel[],
            Float64[]
        )
    end
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Basic Operations                             ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    Base.show(io::IO, model::HierarchicalShapeModel)

Custom display method for HierarchicalShapeModel objects.
"""
function Base.show(io::IO, hier_shape::HierarchicalShapeModel)
    print(io, "Hierarchical Shape Model\n")
    print(io, "------------------------\n")
    print(io, "Global shape:\n")
    print(io, "  - Nodes: $(length(hier_shape.global_shape.nodes))\n")
    print(io, "  - Faces: $(length(hier_shape.global_shape.faces))\n")
    print(io, "Faces with roughness: $(length(hier_shape.roughness_models)) / $(length(hier_shape.global_shape.faces))")
end

"""
    add_roughness_model!(
        hier_shape      ::HierarchicalShapeModel, 
        face_idx        ::Int,
        roughness_model ::ShapeModel,
        scale           ::Real
    )

Add a surface roughness model to a specific face of the hierarchical shape model.

# Arguments
- `hier_shape`      : The hierarchical shape model
- `face_idx`        : Index of the face to attach the roughness to
- `roughness_model` : The shape model representing the surface roughness
- `scale`           : Scale factor for the roughness model

# Notes
- The roughness model is automatically positioned at the face center
  with a north-aligned local coordinate system (x: East, y: North, z: Up).
- The transformation between global and local coordinates is computed
  on-the-fly based on the face geometry.
"""
function add_roughness_model!(
    hier_shape      ::HierarchicalShapeModel, 
    face_idx        ::Int,
    roughness_model ::ShapeModel,
    scale           ::Real
)
    @assert 1 ≤ face_idx ≤ length(hier_shape.global_shape.faces) "Invalid face index"
    @assert hier_shape.face_roughness_indices[face_idx] == 0 "Face already has a roughness model"
    
    # Add the roughness model and its metadata
    push!(hier_shape.roughness_models, roughness_model)
    push!(hier_shape.roughness_model_scales, Float64(scale))
    
    # Update the face-to-roughness mapping
    roughness_idx = length(hier_shape.roughness_models)
    hier_shape.face_roughness_indices[face_idx] = roughness_idx
    
    return nothing
end

"""
    get_roughness_model(hier_shape::HierarchicalShapeModel, face_idx::Int) -> Union{Nothing, ShapeModel}

Get the roughness model associated with a specific face.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face to query

# Returns
- `ShapeModel` : The roughness model for the specified face
- `nothing`    : If the face has no associated roughness model
"""
function get_roughness_model(hier_shape::HierarchicalShapeModel, face_idx::Int)::Union{Nothing, ShapeModel}
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    return roughness_idx == 0 ? nothing : hier_shape.roughness_models[roughness_idx]
end

"""
    get_roughness_model_scale(hier_shape::HierarchicalShapeModel, face_idx::Int) -> Union{Nothing, Float64}

Get the scale factor for the roughness model on a specific face.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face to query

# Returns
- `Float64` : The scale factor for the roughness model
- `nothing` : If the face has no associated roughness model
"""
function get_roughness_model_scale(hier_shape::HierarchicalShapeModel, face_idx::Int)::Union{Nothing, Float64}
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    return roughness_idx == 0 ? nothing : hier_shape.roughness_model_scales[roughness_idx]
end

"""
    has_roughness(hier_shape::HierarchicalShapeModel, face_idx::Int) -> Bool

Check if a face has an associated roughness model.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face to check

# Returns
- `true`  : If the face has an associated roughness model
- `false` : If the face has no roughness model
"""
function has_roughness(hier_shape::HierarchicalShapeModel, face_idx::Int)::Bool
    return hier_shape.face_roughness_indices[face_idx] != 0
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Coordinate Transformations                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    transform_point_global_to_local(
        hier_shape::HierarchicalShapeModel,
        face_idx::Int,
        point::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a point from global coordinates to local roughness model coordinates.

Returns the original point if the face has no roughness model.
"""
function transform_point_global_to_local(
    hier_shape::HierarchicalShapeModel, 
    face_idx::Int,
    point::StaticVector{3}
)
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    roughness_idx == 0 && return point
    
    # Compute transformation on-the-fly based on face geometry
    # TODO: Implement coordinate transformation based on face normal and geographic conventions
    # For now, return the original point
    return point
end

"""
    transform_point_local_to_global(
        hier_shape::HierarchicalShapeModel,
        face_idx::Int,
        point::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a point from local roughness model coordinates to global coordinates.

Returns the original point if the face has no roughness model.
"""
function transform_point_local_to_global(
    hier_shape::HierarchicalShapeModel,
    face_idx::Int,
    point::StaticVector{3}
)
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    roughness_idx == 0 && return point
    
    # Compute transformation on-the-fly based on face geometry
    # TODO: Implement coordinate transformation based on face normal and geographic conventions
    # For now, return the original point
    return point
end

"""
    transform_vector_global_to_local(
        hier_shape::HierarchicalShapeModel,
        face_idx::Int,
        vector::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a vector (direction) from global coordinates to local roughness model coordinates.
Vectors are not affected by translation, only rotation and scaling.

Returns the original vector if the face has no roughness model.
"""
function transform_vector_global_to_local(
    hier_shape::HierarchicalShapeModel,
    face_idx::Int,
    vector::StaticVector{3}
)
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    roughness_idx == 0 && return vector
    
    # Compute transformation on-the-fly based on face geometry
    # TODO: Implement coordinate transformation based on face normal and geographic conventions
    # For now, return the original vector
    return vector
end

"""
    transform_vector_local_to_global(
        hier_shape::HierarchicalShapeModel,
        face_idx::Int,
        vector::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a vector (direction) from local roughness model coordinates to global coordinates.
Vectors are not affected by translation, only rotation and scaling.

Returns the original vector if the face has no roughness model.
"""
function transform_vector_local_to_global(
    hier_shape::HierarchicalShapeModel,
    face_idx::Int,
    vector::StaticVector{3}
)
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    roughness_idx == 0 && return vector
    
    # Compute transformation on-the-fly based on face geometry
    # TODO: Implement coordinate transformation based on face normal and geographic conventions
    # For now, return the original vector
    return vector
end
