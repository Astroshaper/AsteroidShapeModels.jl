#=
    hierarchical_shape_model.jl

Implements hierarchical shape models for multi-scale surface representation.
This allows detailed surface features (craters, boulders, roughness) to be
added to base shape models while maintaining computational efficiency.

The hierarchical structure uses:
- Base shape model (ShapeModel) for global geometry
- Surface roughness models (ShapeModel) attached to global shape's faces
- Scale factors for each roughness model
- Efficient indexing for O(1) access to face details
- On-the-fly computation of coordinate transformations

## Implementation Considerations

### Coordinate Transformations
The current implementation uses separate rotation matrix (R), translation vector (t), 
and scale factor for coordinate transformations. This approach is mathematically 
equivalent to using 4×4 affine transformation matrices but offers several advantages:

1. **Memory efficiency**: 13 Float64 values vs 16 for a 4×4 matrix (~23% savings)
2. **Computational efficiency**: Vector transformations can skip translation
3. **Clarity**: Physical meaning of each component is explicit
4. **Flexibility**: Easier to handle different scaling for physical quantities

Future implementations might consider using affine transformation matrices if:
- Uniform interface with other transformation libraries is needed
- Hardware acceleration for 4×4 matrix operations becomes available
- Multiple consecutive transformations need to be composed
- cf. CoordinateTransformations.jl for affine transformations

See `examples/affine_transform_example.jl` for a comparison of both approaches.
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
    get_roughness_model_scale(hier_shape::HierarchicalShapeModel, face_idx::Int) -> Float64

Get the scale factor for the roughness model on a specific face.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face to query

# Returns
- `Float64` : The scale factor for the roughness model (1.0 if no roughness model)
"""
function get_roughness_model_scale(hier_shape::HierarchicalShapeModel, face_idx::Int)::Float64
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    return roughness_idx == 0 ? 1.0 : hier_shape.roughness_model_scales[roughness_idx]
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

# Local coordinate center offset for transformations
const LOCAL_CENTER_OFFSET = SVector{3, Float64}(0.5, 0.5, 0.0)

"""
    compute_local_coordinate_system(hier_shape::HierarchicalShapeModel, face_idx::Int)
    -> (origin::SVector{3}, ê_x::SVector{3}, ê_y::SVector{3}, ê_z::SVector{3})

Compute the local coordinate system for a face's roughness model.

The local coordinate system follows geographic conventions:
- Origin : Face center
- ê_z    : Face normal unit vector (outward)
- ê_y    : Unit vector pointing north (projected onto the face plane)
- ê_x    : Unit vector pointing east (completing a right-handed system)

# Returns
A tuple containing:
- `origin` : The face center position
- `ê_x`    : Unit vector pointing east
- `ê_y`    : Unit vector pointing north
- `ê_z`    : Unit vector pointing up (face normal)
"""
function compute_local_coordinate_system(hier_shape::HierarchicalShapeModel, face_idx::Int)
    # Get precomputed face center and normal
    origin = hier_shape.global_shape.face_centers[face_idx]
    ê_z = hier_shape.global_shape.face_normals[face_idx]  # Already normalized outward normal
    
    # Define global north direction (assuming Z is up in global frame)
    global_north = SVector{3, Float64}(0, 0, 1)
    
    # Compute local X-axis (east) using cross product
    # ê_x = North × ê_z (perpendicular to both global north and face normal)
    ê_x = global_north × ê_z
    
    # Handle the case where the face normal is nearly parallel to global north
    if norm(ê_x) < 1e-10
        # Check if ê_z points up or down
        if ê_z ⋅ global_north > 0
            # Face normal points up: use global X and Y axes
            ê_x = SVector{3, Float64}(1, 0, 0)  # Global East
            ê_y = SVector{3, Float64}(0, 1, 0)  # Global North
            return (origin, ê_x, ê_y, ê_z)
        else
            # Face normal points down: flip X-axis to maintain right-handed system
            ê_x = SVector{3, Float64}(-1, 0, 0)  # Flipped East
            ê_y = SVector{3, Float64}(0, 1, 0)   # Global North
            return (origin, ê_x, ê_y, ê_z)
        end
    end
    
    # Normalize X-axis
    ê_x = normalize(ê_x)
    
    # Compute local Y-axis (north) using right-hand rule
    # ê_y = ê_z × ê_x (completes the right-handed coordinate system)
    ê_y = normalize(ê_z × ê_x)
    
    return (origin, ê_x, ê_y, ê_z)
end

"""
    compute_local_transform(hier_shape::HierarchicalShapeModel, face_idx::Int)
    -> (R::SMatrix{3,3}, t::SVector{3}, scale::Float64)

Compute the transformation parameters for converting between global and local coordinates.

# Returns
- `R`     : Rotation matrix for global-to-local transformation (rows are local unit vectors)
- `t`     : Translation vector (face center position)
- `scale` : Scale factor - local unit length in global coordinates (UV length 1.0 = scale units in global)

# Coordinate Transformations
- Global to local : `x_local = R * (x_global - t) / scale + LOCAL_CENTER_OFFSET`
- Local to global : `x_global = R' * (scale * (x_local - LOCAL_CENTER_OFFSET)) + t`
- Note: Local coordinates [0,1]×[0,1] with center at (0.5, 0.5, 0.0)
"""
function compute_local_transform(hier_shape::HierarchicalShapeModel, face_idx::Int)
    origin, ê_x, ê_y, ê_z = compute_local_coordinate_system(hier_shape, face_idx)
    
    # Build rotation matrix for global-to-local transformation
    # Rows are local unit vectors (projections onto local axes)
    R = SMatrix{3,3}(
        ê_x[1], ê_y[1], ê_z[1],
        ê_x[2], ê_y[2], ê_z[2],
        ê_x[3], ê_y[3], ê_z[3]
    )
    
    # Get scale factor (1.0 if no roughness model)
    scale = get_roughness_model_scale(hier_shape, face_idx)
    
    return (R, origin, scale)
end

"""
    transform_point_global_to_local(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        point      ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a point from global coordinates to local roughness model coordinates.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face (1-based)
- `point`      : Point in global coordinates

# Returns
- Point in local roughness model coordinates [0,1]×[0,1]×ℝ
- Original point if the face has no roughness model

# Notes
The local coordinate system has its origin at the face center, with:
- X-axis pointing east
- Y-axis pointing north  
- Z-axis pointing up (along face normal)
The UV coordinates [0,1]×[0,1] are centered at (0.5, 0.5).
"""
function transform_point_global_to_local(
    hier_shape ::HierarchicalShapeModel, 
    face_idx   ::Int,
    p_global   ::StaticVector{3}
)
    # If no roughness model, return the original point
    !has_roughness(hier_shape, face_idx) && return p_global
    
    # Get transformation parameters
    R, t, scale = compute_local_transform(hier_shape, face_idx)
    
    # Apply transformation: x_local = R * (x_global - t) / scale + (0.5, 0.5, 0)
    p_local = R * (p_global - t) / scale + LOCAL_CENTER_OFFSET
    
    return p_local
end

"""
    transform_point_local_to_global(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        point      ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a point from local roughness model coordinates to global coordinates.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face (1-based)
- `point`      : Point in local roughness model coordinates [0,1]×[0,1]×ℝ

# Returns
- Point in global coordinates
- Original point if the face has no roughness model

# Notes
Inverse transformation of `transform_point_global_to_local`.
Local coordinates are expected to be in the range [0,1]×[0,1] for UV,
with arbitrary Z values representing elevation above the face.
"""
function transform_point_local_to_global(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    p_local    ::StaticVector{3}
)
    # If no roughness model, return the original point
    !has_roughness(hier_shape, face_idx) && return p_local
    
    # Get transformation parameters
    R, t, scale = compute_local_transform(hier_shape, face_idx)
    
    # Apply transformation: x_global = R' * (scale * (x_local - (0.5, 0.5, 0))) + t
    p_global = R' * (scale * (p_local - LOCAL_CENTER_OFFSET)) + t

    return p_global
end

"""
    transform_vector_global_to_local(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        vector     ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a geometric vector from global coordinates to local roughness model coordinates.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face (1-based)
- `vector`     : Geometric vector in global coordinates

# Returns
- Vector in local roughness model coordinates (scaled)
- Original vector if the face has no roughness model

# Notes
This function applies both rotation and scaling, suitable for geometric vectors
such as displacements and velocities. The scaling ensures that a unit vector
in local coordinates corresponds to the physical scale of the roughness model.

For physical vectors (forces, torques) that should preserve magnitude,
use `transform_physical_vector_global_to_local` instead.
"""
function transform_vector_global_to_local(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    v_global   ::StaticVector{3}
)
    # If no roughness model, return the original vector
    !has_roughness(hier_shape, face_idx) && return v_global

    # Get transformation parameters (translation not needed for vectors)
    R, _, scale = compute_local_transform(hier_shape, face_idx)
    
    # Apply transformation: v_local = R * v_global / scale
    v_local = R * v_global / scale
    
    return v_local
end

"""
    transform_vector_local_to_global(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        vector     ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a geometric vector from local roughness model coordinates to global coordinates.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face (1-based)
- `vector`     : Geometric vector in local roughness model coordinates

# Returns
- Vector in global coordinates (scaled)
- Original vector if the face has no roughness model

# Notes
Inverse transformation of `transform_vector_global_to_local`.
This function applies both rotation and scaling, suitable for geometric vectors
such as displacements and velocities.

For physical vectors (forces, torques) that should preserve magnitude,
use `transform_physical_vector_local_to_global` instead.
"""
function transform_vector_local_to_global(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    v_local    ::StaticVector{3}
)
    !has_roughness(hier_shape, face_idx) && return v_local
    
    # Get transformation parameters (translation not needed for vectors)
    R, _, scale = compute_local_transform(hier_shape, face_idx)
    
    # Apply transformation: v_global = R' * (scale * v_local)
    v_global = R' * (scale * v_local)
    
    return v_global
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    Physical Vector Transformations                ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    transform_physical_vector_global_to_local(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        v_global   ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a physical vector (force, torque, angular velocity, etc.) from global to local coordinates.
Physical vectors are only rotated, not scaled, preserving their physical magnitude.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face
- `v_global`   : Physical vector in global coordinates

# Returns
- Physical vector in local coordinate frame

# Note
Use this for quantities where the physical magnitude must be preserved:
- Forces and torques
- Angular velocities
- Magnetic fields
- Any vector representing a physical quantity rather than a geometric displacement

For geometric vectors (displacements, velocities), use `transform_vector_global_to_local` instead.
"""
function transform_physical_vector_global_to_local(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    v_global   ::StaticVector{3}
)
    # If no roughness model, return the original vector
    !has_roughness(hier_shape, face_idx) && return v_global
    
    # Get rotation matrix only (scale not needed for physical vectors)
    R, _, _ = compute_local_transform(hier_shape, face_idx)
    
    # Apply pure rotation
    v_local = R * v_global
    
    return v_local
end

"""
    transform_physical_vector_local_to_global(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        v_local    ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a physical vector (force, torque, angular velocity, etc.) from local to global coordinates.
Physical vectors are only rotated, not scaled, preserving their physical magnitude.

# Arguments
- `hier_shape` : The hierarchical shape model
- `face_idx`   : Index of the face
- `v_local`    : Physical vector in local coordinates

# Returns
- Physical vector in global coordinate frame

# Note
Use this for quantities where the physical magnitude must be preserved:
- Forces and torques
- Angular velocities  
- Magnetic fields
- Any vector representing a physical quantity rather than a geometric displacement

For geometric vectors (displacements, velocities), use `transform_vector_local_to_global` instead.
"""
function transform_physical_vector_local_to_global(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    v_local    ::StaticVector{3}
)
    # If no roughness model, return the original vector
    !has_roughness(hier_shape, face_idx) && return v_local
    
    # Get rotation matrix only (scale not needed for physical vectors)
    R, _, _ = compute_local_transform(hier_shape, face_idx)
    
    # Apply pure rotation
    v_global = R' * v_local
    
    return v_global
end
