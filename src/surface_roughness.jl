#=
    surface_roughness.jl

Implements management of surface roughness models attached to the faces of a
`ShapeModel`, enabling multi-scale surface representation. This allows detailed
surface features (e.g., craters, boulders, roughness) to be added to base shape
models while maintaining computational efficiency.

The multi-scale structure uses:
- Base shape model (`ShapeModel`) for global geometry
- Surface roughness models (`ShapeModel`) attached to the global shape's faces
- Per-face affine transformations

The roughness data is stored in the `roughness` field of `ShapeModel` as a
`SurfaceRoughness` struct (defined in shape_model.jl); `nothing` means a smooth
surface.

## Implementation Considerations

### Coordinate Transformations
The implementation uses CoordinateTransformations.jl's `AffineMap` type for per-face
transformations. Each face stores a complete global-to-local AffineMap in
`face_roughness_transforms`, which encodes rotation, scaling, and translation.

The scale factor for a face can be recovered on demand from the transform's linear part:
`scale = 1 / norm(transform.linear[:, 1])`, since `transform.linear = (1/scale) * R'`.

Note: `face_roughness_transforms` stores the global-to-local transformation for each face,
allowing custom positioning and orientation of roughness models.
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Roughness Model Accessors                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    has_roughness(shape::ShapeModel) -> Bool
    has_roughness(shape::ShapeModel, face_idx::Int) -> Bool

Check for surface roughness on the shape model.

- `has_roughness(shape)` checks if the shape carries any surface roughness data
  (i.e., `shape.roughness !== nothing`).
- `has_roughness(shape, face_idx)` checks if the specified face has an associated
  roughness model (always `false` if the shape has no roughness data at all).

# Arguments
- `shape::ShapeModel` : The shape model to check
- `face_idx::Int`     : Index of the face to check (optional)

# Returns
- `Bool` : `true` if the shape (or the specified face) has surface roughness, `false` otherwise

See also: [`add_roughness_models!`](@ref), [`get_roughness_model`](@ref)
"""
has_roughness(shape::ShapeModel)::Bool = !isnothing(shape.roughness)

function has_roughness(shape::ShapeModel, face_idx::Int)::Bool
    !has_roughness(shape) && return false
    return shape.roughness.face_roughness_indices[face_idx] != 0
end

# Internal: throw unless the shape carries roughness data
function _require_roughness(shape::ShapeModel)
    has_roughness(shape) ||
        throw(ArgumentError("Shape has no surface roughness data. Add roughness models with `add_roughness_models!` first."))
    return nothing
end

"""
    get_roughness_model(shape::ShapeModel, face_idx::Int) -> Union{Nothing, ShapeModel}

Get the roughness model associated with a specific face.

# Arguments
- `shape::ShapeModel` : The shape model
- `face_idx::Int`     : Index of the face to query

# Returns
- `Union{Nothing, ShapeModel}` : The roughness model for the specified face, or `nothing` if no roughness model is associated
"""
function get_roughness_model(shape::ShapeModel, face_idx::Int)::Union{Nothing, ShapeModel}
    !has_roughness(shape, face_idx) && return nothing
    roughness_idx = shape.roughness.face_roughness_indices[face_idx]
    return shape.roughness.roughness_models[roughness_idx]
end

"""
    get_roughness_model_scale(shape::ShapeModel, face_idx::Int) -> Float64

Get the scale factor for the roughness model on a specific face.

# Arguments
- `shape::ShapeModel` : The shape model
- `face_idx::Int`     : Index of the face to query

# Returns
- `Float64` : The scale factor for the roughness model (1.0 if no roughness model)

# Throws
- `ArgumentError` : If the shape has no roughness data at all (`shape.roughness === nothing`)
"""
function get_roughness_model_scale(shape::ShapeModel, face_idx::Int)::Float64
    _require_roughness(shape)
    # Recover scale from transform: transform.linear = (1/scale) * R', so ‖column‖ = 1/scale
    return 1.0 / norm(shape.roughness.face_roughness_transforms[face_idx].linear[:, 1])
end

"""
    get_roughness_model_transform(shape::ShapeModel, face_idx::Int) -> AffineMap

Get the affine transformation (global to local) for the roughness model on a specific face.

# Arguments
- `shape::ShapeModel` : The shape model
- `face_idx::Int`     : Index of the face to query

# Returns
- `AFFINE_MAP_TYPE` : The affine transformation from global to local coordinates

# Throws
- `ArgumentError` : If the shape has no roughness data at all (`shape.roughness === nothing`)
"""
function get_roughness_model_transform(shape::ShapeModel, face_idx::Int)::AFFINE_MAP_TYPE
    _require_roughness(shape)
    return shape.roughness.face_roughness_transforms[face_idx]
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Roughness Model Management                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    clear_roughness_models!(shape::ShapeModel)

Remove all roughness models from all faces of the shape model,
resetting `shape.roughness` to `nothing` (smooth surface).

# Arguments
- `shape::ShapeModel` : The shape model
"""
function clear_roughness_models!(shape::ShapeModel)
    shape.roughness = nothing
    return nothing
end

"""
    clear_roughness_models!(shape::ShapeModel, face_idx::Int)

Remove the roughness model from a specific face.

# Arguments
- `shape::ShapeModel` : The shape model
- `face_idx::Int`     : Index of the face to clear

# Notes
- This function clears the assignment for the specified face.
  If the roughness model is no longer used by any face, it will be removed from memory.
- If no roughness models remain after clearing, `shape.roughness` is reset to `nothing`.
- Does nothing if the shape has no roughness data.
"""
function clear_roughness_models!(shape::ShapeModel, face_idx::Int)
    1 ≤ face_idx ≤ length(shape.faces) || throw(BoundsError(shape.faces, face_idx))
    !has_roughness(shape) && return nothing
    roughness = shape.roughness

    # Get the model index before clearing
    roughness_idx = roughness.face_roughness_indices[face_idx]

    # Clear the face's roughness assignment
    roughness.face_roughness_indices[face_idx]    = 0                    # Reset to no roughness
    roughness.face_roughness_transforms[face_idx] = IDENTITY_AFFINE_MAP  # Reset transform to identity

    # Check if this model is still used by other faces
    if roughness_idx > 0 && !(roughness_idx in roughness.face_roughness_indices)
        # Remove the unused model and update indices
        deleteat!(roughness.roughness_models, roughness_idx)

        # Update all face indices that point to models after the deleted one
        mask = roughness.face_roughness_indices .> roughness_idx
        roughness.face_roughness_indices[mask] .-= 1
    end

    # If no models remain, reset to a smooth surface
    isempty(roughness.roughness_models) && (shape.roughness = nothing)

    return nothing
end

"""
    add_roughness_models!(
        shape           ::ShapeModel,
        roughness_model ::ShapeModel;
        scale           ::Float64 = 1.0,
    )

Add the same surface roughness model to all faces of the shape model.
On the first call, `shape.roughness` (a `SurfaceRoughness` struct) is constructed.

# Arguments
- `shape::ShapeModel`           : The shape model to attach roughness to
- `roughness_model::ShapeModel` : The shape model representing the surface roughness

# Keyword Arguments
- `scale::Float64` : Scale factor for the roughness model (default: 1.0)

# Throws
- `ArgumentError` : If `scale` is not positive, or if `roughness_model` itself has
  roughness data (nested roughness is not supported)

# Notes
- This function applies the roughness model to ALL faces, overwriting any existing assignments.
- All faces will share the same `ShapeModel` instance, making this memory-efficient.
- Appropriate transformations are automatically computed for each face using `compute_face_roughness_transform`.
- Use the face-specific version `add_roughness_models!(shape, roughness_model, face_idx; scale, transform)`
  to selectively apply different models to individual faces or to provide custom transformations.
"""
function add_roughness_models!(
    shape           ::ShapeModel,
    roughness_model ::ShapeModel;
    scale           ::Float64 = 1.0,
)
    scale > 0 || throw(ArgumentError("scale must be positive, got $scale"))
    has_roughness(roughness_model) &&
        throw(ArgumentError("Roughness model must be a smooth `ShapeModel` (its `roughness` field must be `nothing`). Nested roughness is not supported."))

    # Rebuild the roughness data from scratch
    roughness = SurfaceRoughness{ShapeModel}(length(shape.faces))
    shape.roughness = roughness

    # Add the model to the list
    push!(roughness.roughness_models, roughness_model)
    roughness_idx = length(roughness.roughness_models)

    # Apply to all faces
    roughness.face_roughness_indices .= roughness_idx

    # Automatically compute appropriate transformation for each face
    for face_idx in eachindex(shape.faces)
        transform = compute_face_roughness_transform(shape, face_idx; scale)
        roughness.face_roughness_transforms[face_idx] = transform
    end

    return nothing
end

"""
    add_roughness_models!(
        shape           ::ShapeModel,
        roughness_model ::ShapeModel,
        face_idx        ::Int;
        scale           ::Float64 = 1.0,
        transform       ::Union{Nothing, AFFINE_MAP_TYPE} = nothing,
    )

Add a surface roughness model to a specific face of the shape model.
On the first call, `shape.roughness` (a `SurfaceRoughness` struct) is constructed.

# Arguments
- `shape::ShapeModel`           : The shape model to attach roughness to
- `roughness_model::ShapeModel` : The shape model representing the surface roughness
- `face_idx::Int`               : Index of the face to attach the roughness to

# Keyword Arguments
- `scale::Float64`                             : Scale factor for the roughness model (default: 1.0)
- `transform::Union{Nothing, AFFINE_MAP_TYPE}` :
        Affine transformation from global to local coordinates (optional).
        If `nothing` (default), automatically computes an appropriate transformation
        using `compute_face_roughness_transform`

# Throws
- `BoundsError`   : If `face_idx` is out of bounds
- `ArgumentError` : If `scale` is not positive, or if `roughness_model` itself has
  roughness data (nested roughness is not supported)

# Notes
- If the face already has a roughness model, it will be replaced.
- When `transform` is `nothing`, the roughness model is automatically positioned
  at the face center with a north-aligned local coordinate system (x: East, y: North, z: Up).
"""
function add_roughness_models!(
    shape           ::ShapeModel,
    roughness_model ::ShapeModel,
    face_idx        ::Int;
    scale           ::Float64 = 1.0,
    transform       ::Union{Nothing, AFFINE_MAP_TYPE} = nothing,
)
    1 ≤ face_idx ≤ length(shape.faces) || throw(BoundsError(shape.faces, face_idx))
    scale > 0 || throw(ArgumentError("scale must be positive, got $scale"))
    has_roughness(roughness_model) &&
        throw(ArgumentError("Roughness model must be a smooth `ShapeModel` (its `roughness` field must be `nothing`). Nested roughness is not supported."))

    # Construct the roughness data on first use
    if !has_roughness(shape)
        shape.roughness = SurfaceRoughness{ShapeModel}(length(shape.faces))
    end
    roughness = shape.roughness

    # Find or add the roughness model (the same instance is shared, not duplicated)
    roughness_idx = findfirst(existing_model -> existing_model === roughness_model, roughness.roughness_models)
    if isnothing(roughness_idx)
        push!(roughness.roughness_models, roughness_model)
        roughness_idx = length(roughness.roughness_models)
    end

    # Update the face-to-roughness mapping
    roughness.face_roughness_indices[face_idx] = roughness_idx

    # If no transform is provided, compute the default transformation.
    if isnothing(transform)
        transform = compute_face_roughness_transform(shape, face_idx; scale)
    end
    roughness.face_roughness_transforms[face_idx] = transform

    return nothing
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Coordinate Transformations                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    compute_local_coordinate_system(shape::ShapeModel, face_idx::Int)
    -> (origin::SVector{3}, ê_x::SVector{3}, ê_y::SVector{3}, ê_z::SVector{3})

Compute the local coordinate system for a face's roughness model.

The local coordinate system follows geographic conventions:
- Origin : Face center
- ê_z    : Face normal unit vector (outward)
- ê_y    : Unit vector pointing north (projected onto the face plane)
- ê_x    : Unit vector pointing east (completing a right-handed system)

# Arguments
- `shape::ShapeModel` : The shape model
- `face_idx::Int`     : Index of the face

# Returns
A tuple `(origin::SVector{3}, ê_x::SVector{3}, ê_y::SVector{3}, ê_z::SVector{3})` containing:
- `origin::SVector{3}` : The face center position
- `ê_x::SVector{3}`    : Unit vector pointing east
- `ê_y::SVector{3}`    : Unit vector pointing north
- `ê_z::SVector{3}`    : Unit vector pointing up (face normal)
"""
function compute_local_coordinate_system(shape::ShapeModel, face_idx::Int)
    # Get precomputed face center and normal
    origin = shape.face_centers[face_idx]
    ê_z = shape.face_normals[face_idx]  # Already normalized outward normal

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
    compute_face_roughness_transform(shape::ShapeModel, face_idx::Int; scale::Float64=1.0) -> AFFINE_MAP_TYPE

Compute the transformation for a face's roughness model.
This function creates an AffineMap that transforms points from global coordinates
to the roughness model's local UV coordinates [0,1]×[0,1]. The computed transformation
is intended to be stored in the `shape.roughness.face_roughness_transforms` field.

# Arguments
- `shape::ShapeModel` : The shape model
- `face_idx::Int`     : Index of the face

# Keyword Arguments
- `scale::Float64` : Scale factor for the roughness model (default: 1.0).
                     A scale of 0.01 means 1 unit in the roughness model equals 0.01 units in global coordinates.

# Returns
- `AFFINE_MAP_TYPE` : The affine transformation from global to local coordinates

# Implementation Note
This function constructs the desired passive global→local transformation
via an intermediate active local→global transformation:

The transformation pipeline:
- 1. Offset from UV center (0.5, 0.5, 0.0) to local origin
- 2. Scale from local units to global units
- 3. Rotate from local coordinate system to global (north-aligned)
- 4. Translate from local origin to face center
- 5. Compose active local→global transformation
- 6. Invert the above to obtain passive global→local transformation
"""
function compute_face_roughness_transform(shape::ShapeModel, face_idx::Int; scale::Float64=1.0)
    # Get local coordinate system
    origin, ê_x, ê_y, ê_z = compute_local_coordinate_system(shape, face_idx)

    # 1. Offset from UV center to local origin
    offset_from_uv_center = Translation(-LOCAL_CENTER_OFFSET)

    # 2. Scale transformation (from local units to global units)
    scale_transform = LinearMap(UniformScaling(scale))

    # 3. Rotation from local to global coordinates
    # Columns are local basis vectors for the active transformation (column-major)
    R = SMatrix{3,3}(
        ê_x[1], ê_x[2], ê_x[3],  # Column 1: ê_x
        ê_y[1], ê_y[2], ê_y[3],  # Column 2: ê_y
        ê_z[1], ê_z[2], ê_z[3]   # Column 3: ê_z
    )
    rotate_to_global = LinearMap(R)

    # 4. Translation from local origin to face center
    translate_to_face_center = Translation(origin)

    # 5. Compose active local→global transformation (applied right to left)
    active_local_to_global = translate_to_face_center ∘ rotate_to_global ∘ scale_transform ∘ offset_from_uv_center

    # 6. Invert this to get passive global→local transformation
    passive_global_to_local = inv(active_local_to_global)

    return passive_global_to_local
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                  Geometric Point Transformations                  ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    transform_point_global_to_local(
        shape    ::ShapeModel,
        face_idx ::Int,
        p_global ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a point from global to local coordinates.

# Arguments
- `shape::ShapeModel`         : The shape model
- `face_idx::Int`             : Index of the face (1-based)
- `p_global::StaticVector{3}` : Point in global coordinates

# Returns
- `SVector{3, Float64}` : Point in local roughness model coordinates [0,1]×[0,1]×ℝ

# Throws
- `ArgumentError` : If the specified face has no roughness model
- `BoundsError`   : If `face_idx` is out of bounds

# Notes
The local coordinate system has its origin at the face center, with:
- X-axis pointing east
- Y-axis pointing north
- Z-axis pointing up (along face normal)
The UV coordinates [0,1]×[0,1] are centered at (0.5, 0.5).

!!! warning "Requires roughness model"
    This function requires the face to have an assigned roughness model.
    Always check with `has_roughness(shape, face_idx)` before calling.

# Usage
```julia
if has_roughness(shape, face_idx)
    p_local = transform_point_global_to_local(shape, face_idx, p_global)
end
```
"""
function transform_point_global_to_local(
    shape    ::ShapeModel,
    face_idx ::Int,
    p_global ::StaticVector{3}
)::SVector{3, Float64}
    !has_roughness(shape, face_idx) &&
        throw(ArgumentError("Face $face_idx has no roughness model. Cannot transform to local coordinates."))
    transform = get_roughness_model_transform(shape, face_idx)
    return transform(p_global)
end

"""
    transform_point_local_to_global(
        shape    ::ShapeModel,
        face_idx ::Int,
        p_local  ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a point from local to global coordinates.

# Arguments
- `shape::ShapeModel`        : The shape model
- `face_idx::Int`            : Index of the face (1-based)
- `p_local::StaticVector{3}` : Point in local roughness model coordinates [0,1]×[0,1]×ℝ

# Returns
- `SVector{3, Float64}` : Point in global coordinates

# Throws
- `ArgumentError` : If the specified face has no roughness model
- `BoundsError`   : If face_idx is out of bounds

# Notes
Inverse transformation of `transform_point_global_to_local`.

!!! warning "Requires roughness model"
    This function requires the face to have an assigned roughness model.
    Always check with `has_roughness(shape, face_idx)` before calling.

# Usage
```julia
if has_roughness(shape, face_idx)
    p_global = transform_point_local_to_global(shape, face_idx, p_local)
end
```
"""
function transform_point_local_to_global(
    shape    ::ShapeModel,
    face_idx ::Int,
    p_local  ::StaticVector{3}
)::SVector{3, Float64}
    !has_roughness(shape, face_idx) &&
        throw(ArgumentError("Face $face_idx has no roughness model. Cannot transform from local coordinates."))
    transform = get_roughness_model_transform(shape, face_idx)
    return inv(transform)(p_local)
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                  Geometric Vector Transformations                 ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    transform_geometric_vector_global_to_local(
        shape    ::ShapeModel,
        face_idx ::Int,
        v_global ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a geometric vector (displacement, velocity) from global to local coordinates.
Applies both rotation and scaling.

# Arguments
- `shape::ShapeModel`         : The shape model
- `face_idx::Int`             : Index of the face (1-based)
- `v_global::StaticVector{3}` : Geometric vector in global coordinates

# Returns
- `SVector{3, Float64}` : Vector in local roughness model coordinates (scaled)

# Throws
- `ArgumentError` : If the specified face has no roughness model
- `BoundsError`   : If face_idx is out of bounds

# Notes
For physical vectors (forces, torques) that should preserve magnitude,
use `transform_physical_vector_global_to_local` instead.

!!! warning "Requires roughness model"
    This function requires the face to have an assigned roughness model.
    Always check with `has_roughness(shape, face_idx)` before calling.

# Usage
```julia
if has_roughness(shape, face_idx)
    v_local = transform_geometric_vector_global_to_local(shape, face_idx, v_global)
end
```
"""
function transform_geometric_vector_global_to_local(
    shape    ::ShapeModel,
    face_idx ::Int,
    v_global ::StaticVector{3}
)::SVector{3, Float64}
    !has_roughness(shape, face_idx) &&
        throw(ArgumentError("Face $face_idx has no roughness model. Cannot transform to local coordinates."))
    transform = get_roughness_model_transform(shape, face_idx)
    return transform.linear * v_global
end

"""
    transform_geometric_vector_local_to_global(
        shape    ::ShapeModel,
        face_idx ::Int,
        v_local  ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a geometric vector (displacement, velocity) from local to global coordinates.
Applies both rotation and scaling.

# Arguments
- `shape::ShapeModel`        : The shape model
- `face_idx::Int`            : Index of the face (1-based)
- `v_local::StaticVector{3}` : Geometric vector in local roughness model coordinates

# Returns
- `SVector{3, Float64}` : Vector in global coordinates (scaled)

# Throws
- `ArgumentError` : If the specified face has no roughness model
- `BoundsError`   : If face_idx is out of bounds

# Notes
For physical vectors (forces, torques) that should preserve magnitude,
use `transform_physical_vector_local_to_global` instead.

!!! warning "Requires roughness model"
    This function requires the face to have an assigned roughness model.
    Always check with `has_roughness(shape, face_idx)` before calling.

# Usage
```julia
if has_roughness(shape, face_idx)
    v_global = transform_geometric_vector_local_to_global(shape, face_idx, v_local)
end
```
"""
function transform_geometric_vector_local_to_global(
    shape    ::ShapeModel,
    face_idx ::Int,
    v_local  ::StaticVector{3}
)::SVector{3, Float64}
    !has_roughness(shape, face_idx) &&
        throw(ArgumentError("Face $face_idx has no roughness model. Cannot transform from local coordinates."))
    transform = get_roughness_model_transform(shape, face_idx)
    return inv(transform.linear) * v_local
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                    Physical Vector Transformations                ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    transform_physical_vector_global_to_local(
        shape    ::ShapeModel,
        face_idx ::Int,
        v_global ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a physical vector (force, torque, angular velocity) from global to local
coordinates. Physical vectors are only rotated, not scaled, preserving their magnitude.

# Arguments
- `shape::ShapeModel`         : The shape model
- `face_idx::Int`             : Index of the face
- `v_global::StaticVector{3}` : Physical vector in global coordinates

# Returns
- `SVector{3, Float64}` : Physical vector in local coordinate frame (not scaled)

# Throws
- `ArgumentError` : If the specified face has no roughness model
- `BoundsError`   : If face_idx is out of bounds

# Notes
Use this for quantities where physical magnitude must be preserved (forces, torques,
angular velocities, magnetic fields). For geometric vectors use
`transform_geometric_vector_global_to_local` instead.

!!! warning "Requires roughness model"
    This function requires the face to have an assigned roughness model.
    Always check with `has_roughness(shape, face_idx)` before calling.

# Usage
```julia
if has_roughness(shape, face_idx)
    v_local = transform_physical_vector_global_to_local(shape, face_idx, v_global)
end
```
"""
function transform_physical_vector_global_to_local(
    shape    ::ShapeModel,
    face_idx ::Int,
    v_global ::StaticVector{3}
)::SVector{3, Float64}
    !has_roughness(shape, face_idx) &&
        throw(ArgumentError("Face $face_idx has no roughness model. Cannot transform to local coordinates."))
    transform = get_roughness_model_transform(shape, face_idx)
    # transform.linear = (1/scale) * R'; multiply by scale to recover pure rotation R'
    scale = get_roughness_model_scale(shape, face_idx)
    rotation = transform.linear * scale
    return rotation * v_global
end

"""
    transform_physical_vector_local_to_global(
        shape    ::ShapeModel,
        face_idx ::Int,
        v_local  ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a physical vector (force, torque, angular velocity) from local to global
coordinates. Physical vectors are only rotated, not scaled, preserving their magnitude.

# Arguments
- `shape::ShapeModel`        : The shape model
- `face_idx::Int`            : Index of the face
- `v_local::StaticVector{3}` : Physical vector in local coordinates

# Returns
- `SVector{3, Float64}` : Physical vector in global coordinate frame (not scaled)

# Throws
- `ArgumentError` : If the specified face has no roughness model
- `BoundsError`   : If face_idx is out of bounds

# Notes
Use this for quantities where physical magnitude must be preserved (forces, torques,
angular velocities, magnetic fields). For geometric vectors use
`transform_geometric_vector_local_to_global` instead.

!!! warning "Requires roughness model"
    This function requires the face to have an assigned roughness model.
    Always check with `has_roughness(shape, face_idx)` before calling.

# Usage
```julia
if has_roughness(shape, face_idx)
    v_global = transform_physical_vector_local_to_global(shape, face_idx, v_local)
end
```
"""
function transform_physical_vector_local_to_global(
    shape    ::ShapeModel,
    face_idx ::Int,
    v_local  ::StaticVector{3}
)::SVector{3, Float64}
    !has_roughness(shape, face_idx) &&
        throw(ArgumentError("Face $face_idx has no roughness model. Cannot transform from local coordinates."))
    transform = get_roughness_model_transform(shape, face_idx)
    # transform.linear = (1/scale) * R'; multiply by scale to recover pure rotation R'
    scale = get_roughness_model_scale(shape, face_idx)
    rotation = transform.linear * scale
    return rotation' * v_local
end
