#=
    hierarchical_shape_model.jl

Implements hierarchical shape models for multi-scale surface representation.
This allows detailed surface features (e.g., craters, boulders, roughness) to be
added to base shape models while maintaining computational efficiency.

The hierarchical structure uses:
- Base shape model (ShapeModel) for global geometry
- Surface roughness models (ShapeModel) attached to global shape's faces
- Per-face scale factors and affine transformations

## Implementation Considerations

### Coordinate Transformations
The implementation now uses CoordinateTransformations.jl's `AffineMap` type for per-face
transformations, along with separate scale factors (`face_roughness_scales`).

The coordinate transformation approach:
- Each face stores a complete global-to-local AffineMap in `face_roughness_transforms`
- The AffineMap includes rotation, scaling, and translation in a single transformation
- Scale factors are stored separately in `face_roughness_scales` for efficient access

Note: `face_roughness_transforms` stores the global-to-local transformation for each face,
allowing custom positioning and orientation of roughness models.
=#

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                          Constants                                ║
# ╚═══════════════════════════════════════════════════════════════════╝

# Constants for transformations
const IDENTITY_MATRIX_3x3 = SMatrix{3, 3, Float64}(I)
const ZERO_VECTOR_3 = SVector{3, Float64}(0, 0, 0)
const IDENTITY_AFFINE_MAP = AffineMap(IDENTITY_MATRIX_3x3, ZERO_VECTOR_3)

const LOCAL_CENTER_OFFSET = SVector{3, Float64}(0.5, 0.5, 0.0)

# Type alias for 3D affine transformations
const AFFINE_MAP_TYPE = AffineMap{SMatrix{3, 3, Float64, 9}, SVector{3, Float64}}

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                        Type Definition                            ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    HierarchicalShapeModel <: AbstractShapeModel

A shape model that supports multi-scale surface representation through surface roughness models.

# Fields
- `global_shape`              : `ShapeModel` to represent the global shape of the asteroid
- `face_roughness_indices`    : Mapping from face index to roughness model index (0 = no roughness)
- `face_roughness_scales`     : Vector of scale factors for each face (1.0 = no roughness/identity)
- `face_roughness_transforms` : Vector of affine transformations (global to local) for each face (identity = no roughness)
- `roughness_models`          : Vector of `ShapeModel` objects representing surface roughness

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
add_roughness_models!(hier_shape, crater, face_idx; scale=0.01)
```

# Implementation Notes

The `face_roughness_transforms` field stores complete AffineMap transformations for each face,
providing efficient O(1) access to coordinate transformations. Custom transformations can be
provided via the `transform` parameter in `add_roughness_models!`, or they will be automatically
computed to align with the face's local coordinate system

See also: [`AbstractShapeModel`](@ref), [`ShapeModel`](@ref)
"""
mutable struct HierarchicalShapeModel <: AbstractShapeModel
    global_shape                ::ShapeModel
    face_roughness_indices      ::Vector{Int}
    face_roughness_scales       ::Vector{Float64}
    face_roughness_transforms   ::Vector{AFFINE_MAP_TYPE}
    roughness_models            ::Vector{ShapeModel}
    
    function HierarchicalShapeModel(global_shape::ShapeModel)
        nfaces = length(global_shape.faces)
        face_roughness_indices = zeros(Int, nfaces)    # Initialize with 0 (no roughness)
        face_roughness_scales = ones(Float64, nfaces)  # Initialize with 1.0 (no scaling)

        # Initialize with identity transformations
        face_roughness_transforms = [IDENTITY_AFFINE_MAP for _ in 1:nfaces]
        
        return new(
            global_shape,
            face_roughness_indices,
            face_roughness_scales,
            face_roughness_transforms,
            ShapeModel[]
        )
    end
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                      Display Functions                            ║
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
    
    # Count faces with roughness
    nfaces_with_roughness = count(!=(0), hier_shape.face_roughness_indices)
    print(io, "Faces with roughness    : $(nfaces_with_roughness)\n")
    print(io, "Unique roughness models : $(length(hier_shape.roughness_models))")
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Roughness Model Accessors                       ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    has_roughness_model(hier_shape::HierarchicalShapeModel, face_idx::Int) -> Bool

Check if a face has an associated roughness model.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face to check

# Returns
- `Bool` : `true` if the face has an associated roughness model, `false` otherwise
"""
function has_roughness_model(hier_shape::HierarchicalShapeModel, face_idx::Int)::Bool
    return hier_shape.face_roughness_indices[face_idx] != 0
end

"""
    get_roughness_model(hier_shape::HierarchicalShapeModel, face_idx::Int) -> Union{Nothing, ShapeModel}

Get the roughness model associated with a specific face.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face to query

# Returns
- `Union{Nothing, ShapeModel}` : The roughness model for the specified face, or `nothing` if no roughness model is associated
"""
function get_roughness_model(hier_shape::HierarchicalShapeModel, face_idx::Int)::Union{Nothing, ShapeModel}
    !has_roughness_model(hier_shape, face_idx) && return nothing
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    return hier_shape.roughness_models[roughness_idx]
end

"""
    get_roughness_model_scale(hier_shape::HierarchicalShapeModel, face_idx::Int) -> Float64

Get the scale factor for the roughness model on a specific face.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face to query

# Returns
- `Float64` : The scale factor for the roughness model (1.0 if no roughness model)
"""
function get_roughness_model_scale(hier_shape::HierarchicalShapeModel, face_idx::Int)::Float64
    return hier_shape.face_roughness_scales[face_idx]
end

"""
    get_roughness_model_transform(hier_shape::HierarchicalShapeModel, face_idx::Int) -> AffineMap

Get the affine transformation (global to local) for the roughness model on a specific face.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face to query

# Returns
- `AFFINE_MAP_TYPE` : The affine transformation from global to local coordinates
"""
function get_roughness_model_transform(hier_shape::HierarchicalShapeModel, face_idx::Int)::AFFINE_MAP_TYPE
    return hier_shape.face_roughness_transforms[face_idx]
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Roughness Model Management                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    clear_roughness_models!(hier_shape::HierarchicalShapeModel)

Remove all roughness models from all faces of the hierarchical shape model.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model

# Notes
This function clears all roughness model assignments but keeps the model's structure intact.
The roughness_models array is emptied to free memory.
"""
function clear_roughness_models!(hier_shape::HierarchicalShapeModel)
    
    hier_shape.face_roughness_indices .= 0                       # Reset all face indices to 0 (no roughness)
    hier_shape.face_roughness_scales .= 1.0                      # Reset all scales to 1.0 (identity)
    hier_shape.face_roughness_transforms .= IDENTITY_AFFINE_MAP  # Reset all transforms to identity
    
    empty!(hier_shape.roughness_models)  # Clear the roughness models array
    
    return nothing
end

"""
    clear_roughness_models!(hier_shape::HierarchicalShapeModel, face_idx::Int)

Remove the roughness model from a specific face.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face to clear

# Notes
This function clears the assignment for the specified face.
If the roughness model is no longer used by any face, it will be removed from memory.
"""
function clear_roughness_models!(hier_shape::HierarchicalShapeModel, face_idx::Int)
    @assert 1 ≤ face_idx ≤ length(hier_shape.global_shape.faces) "Invalid face index"
    
    # Get the model index before clearing
    roughness_idx = hier_shape.face_roughness_indices[face_idx]
    
    # Clear the face's roughness assignment
    hier_shape.face_roughness_indices[face_idx] = 0                       # Reset to no roughness
    hier_shape.face_roughness_scales[face_idx] = 1.0                      # Reset to identity scale
    hier_shape.face_roughness_transforms[face_idx] = IDENTITY_AFFINE_MAP  # Reset transform to identity
    
    # Check if this model is still used by other faces
    if roughness_idx > 0 && !(roughness_idx in hier_shape.face_roughness_indices)
        # Remove the unused model and update indices
        deleteat!(hier_shape.roughness_models, roughness_idx)

        # Update all face indices that point to models after the deleted one
        mask = hier_shape.face_roughness_indices .> roughness_idx
        hier_shape.face_roughness_indices[mask] .-= 1
    end
    
    return nothing
end

"""
    add_roughness_models!(
        hier_shape      ::HierarchicalShapeModel,
        roughness_model ::ShapeModel;
        scale           ::Float64 = 1.0,
    )

Add the same surface roughness model to all faces of the hierarchical shape model.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `roughness_model::ShapeModel`        : The shape model representing the surface roughness

# Keyword Arguments
- `scale::Float64`     : Scale factor for the roughness model (default: 1.0)

# Notes
- This function applies the roughness model to ALL faces, overwriting any existing assignments.
- All faces will share the same ShapeModel instance, making this memory-efficient.
- Appropriate transformations are automatically computed for each face using `compute_face_roughness_transform`.
- Use the face-specific version `add_roughness_models!(hier_shape, roughness_model, face_idx; scale, transform)`
  to selectively apply different models to individual faces or to provide custom transformations.
"""
function add_roughness_models!(
    hier_shape      ::HierarchicalShapeModel,
    roughness_model ::ShapeModel;
    scale           ::Float64 = 1.0,
)
    # Clear all existing roughness models first
    clear_roughness_models!(hier_shape)
    
    # Add the model to the list
    push!(hier_shape.roughness_models, roughness_model)
    roughness_idx = length(hier_shape.roughness_models)
    
    # Apply to all faces
    hier_shape.face_roughness_indices .= roughness_idx
    hier_shape.face_roughness_scales .= scale
    
    # Automatically compute appropriate transformation for each face
    for face_idx in eachindex(hier_shape.global_shape.faces)
        transform = compute_face_roughness_transform(hier_shape, face_idx; scale)
        hier_shape.face_roughness_transforms[face_idx] = transform
    end
    
    return nothing
end

"""
    add_roughness_models!(
        hier_shape      ::HierarchicalShapeModel,
        roughness_model ::ShapeModel,
        face_idx        ::Int;
        scale           ::Float64 = 1.0,
        transform       ::Union{Nothing, AFFINE_MAP_TYPE} = nothing,
    )

Add a surface roughness model to a specific face of the hierarchical shape model.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `roughness_model::ShapeModel`        : The shape model representing the surface roughness
- `face_idx::Int`                      : Index of the face to attach the roughness to

# Keyword Arguments
- `scale::Float64`                             : Scale factor for the roughness model (default: 1.0)
- `transform::Union{Nothing, AFFINE_MAP_TYPE}` :
        Affine transformation from global to local coordinates (optional).
        If `nothing` (default), automatically computes an appropriate transformation
        using `compute_face_roughness_transform`

# Notes
- If the face already has a roughness model, it will be replaced.
- When `transform` is `nothing`, the roughness model is automatically positioned 
  at the face center with a north-aligned local coordinate system (x: East, y: North, z: Up).
"""
function add_roughness_models!(
    hier_shape      ::HierarchicalShapeModel,
    roughness_model ::ShapeModel,
    face_idx        ::Int;
    scale           ::Float64 = 1.0,
    transform       ::Union{Nothing, AFFINE_MAP_TYPE} = nothing,
)
    @assert 1 ≤ face_idx ≤ length(hier_shape.global_shape.faces) "Invalid face index"
    
    # Find or add the roughness model
    # `something` uses lazy evaluation: the second argument (begin...end block) is only
    # evaluated if the first argument returns `nothing` (if no existing model found)
    roughness_idx = something(
        findfirst(existing_model -> existing_model === roughness_model, hier_shape.roughness_models),
        begin
            push!(hier_shape.roughness_models, roughness_model)
            length(hier_shape.roughness_models)
        end
    )
    
    # Update the face-to-roughness mapping and scale
    hier_shape.face_roughness_indices[face_idx] = roughness_idx
    hier_shape.face_roughness_scales[face_idx] = scale
    
    # If no transform is provided, compute the default transformation.
    if isnothing(transform)
        transform = compute_face_roughness_transform(hier_shape, face_idx; scale)        
    end
    hier_shape.face_roughness_transforms[face_idx] = transform
    
    return nothing
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                   Coordinate Transformations                      ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    compute_local_coordinate_system(hier_shape::HierarchicalShapeModel, face_idx::Int)
    -> (origin::SVector{3}, ê_x::SVector{3}, ê_y::SVector{3}, ê_z::SVector{3})

Compute the local coordinate system for a face's roughness model.

The local coordinate system follows geographic conventions:
- Origin : Face center
- ê_z    : Face normal unit vector (outward)
- ê_y    : Unit vector pointing north (projected onto the face plane)
- ê_x    : Unit vector pointing east (completing a right-handed system)

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face

# Returns
A tuple `(origin::SVector{3}, ê_x::SVector{3}, ê_y::SVector{3}, ê_z::SVector{3})` containing:
- `origin::SVector{3}` : The face center position
- `ê_x::SVector{3}`    : Unit vector pointing east
- `ê_y::SVector{3}`    : Unit vector pointing north
- `ê_z::SVector{3}`    : Unit vector pointing up (face normal)
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
    compute_face_roughness_transform(hier_shape::HierarchicalShapeModel, face_idx::Int; scale::Float64=1.0) -> AFFINE_MAP_TYPE

Compute the transformation for a face's roughness model.
This function creates an AffineMap that transforms points from global coordinates
to the roughness model's local UV coordinates [0,1]×[0,1]. The computed transformation
is intended to be stored in the `hier_shape.face_roughness_transforms` field.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face

# Keyword Arguments
- `scale::Float64` : Scale factor for the roughness model (default: 1.0).
                     A scale of 0.01 means 1 unit in the roughness model equals 0.01 units in global coordinates.

# Returns
- `AFFINE_MAP_TYPE` : The affine transformation from global to local coordinates

# Implementation Note
This function leverages the equivalence between active and passive transformations:
- Builds an active local-to-global transformation
- Returns it as the passive global-to-local transformation (they are equivalent)
- No inverse computation is needed

The transformation pipeline (as active local-to-global):
- 1. Offset from UV center (0.5, 0.5, 0.0) to local origin
- 2. Scale from local units to global units
- 3. Rotate from local coordinate system to global (north-aligned)
- 4. Translate from local origin to face center
"""
function compute_face_roughness_transform(hier_shape::HierarchicalShapeModel, face_idx::Int; scale::Float64=1.0)
    # Get local coordinate system
    origin, ê_x, ê_y, ê_z = compute_local_coordinate_system(hier_shape, face_idx)
    
    # Build "active local-to-global" transformation using CoordinateTransformations.jl,
    # which is equivalent to "passive global-to-local" transformation to be returned.
    
    # 1. Offset from UV center to local origin
    offset_from_uv_center = Translation(-LOCAL_CENTER_OFFSET)
    
    # 2. Scale transformation (from local units to global units)
    scale_transform = LinearMap(UniformScaling(scale))
    
    # 3. Rotation from local to global coordinates
    # Columns are local basis vectors for the active transformation
    R = SMatrix{3,3}(
        ê_x[1], ê_y[1], ê_z[1],  # Column 1: ê_x
        ê_x[2], ê_y[2], ê_z[2],  # Column 2: ê_y
        ê_x[3], ê_y[3], ê_z[3]   # Column 3: ê_z
    )
    rotate_to_global = LinearMap(R)
    
    # 4. Translation from local origin to face center
    translate_to_face_center = Translation(origin)
    
    # Compose "active local-to-global" transformation (applied right to left)
    active_local_to_global = translate_to_face_center ∘ rotate_to_global ∘ scale_transform ∘ offset_from_uv_center

    # "active local-to-global" transformation is equivalent to "passive global-to-local" transformation
    # (No inverse needed due to active/passive equivalence)
    passive_global_to_local = active_local_to_global
    
    return passive_global_to_local
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                  Geometric Point Transformations                  ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    transform_point_global_to_local(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        point      ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a point from global to local coordinates.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face (1-based)
- `point::StaticVector{3}`             : Point in global coordinates

# Returns
- `SVector{3, Float64}` : Point in local roughness model coordinates [0,1]×[0,1]×ℝ,
                          or original point if the face has no roughness model

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
    !has_roughness_model(hier_shape, face_idx) && return p_global
    
    # Get global-to-local transformation and apply it
    transform = get_roughness_model_transform(hier_shape, face_idx)
    p_local = transform(p_global)
    
    return p_local
end

"""
    transform_point_local_to_global(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        p_local    ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a point from local to global coordinates.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face (1-based)
- `p_local::StaticVector{3}`           : Point in local roughness model coordinates [0,1]×[0,1]×ℝ

# Returns
- `SVector{3, Float64}` : Point in global coordinates, or original point if the face has no roughness model

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
    !has_roughness_model(hier_shape, face_idx) && return p_local
    
    # Get global-to-local transformation, invert it, and apply it.
    transform = get_roughness_model_transform(hier_shape, face_idx)
    transform = inv(transform)  # Invert it to obtain local-to-global transformation
    p_global = transform(p_local)
    
    return p_global
end

# ╔═══════════════════════════════════════════════════════════════════╗
# ║                  Geometric Vector Transformations                 ║
# ╚═══════════════════════════════════════════════════════════════════╝

"""
    transform_geometric_vector_global_to_local(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        v_global   ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a geometric vector from global to local coordinates.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face (1-based)
- `v_global::StaticVector{3}`          : Geometric vector in global coordinates

# Returns
- `SVector{3, Float64}` : Vector in local roughness model coordinates (scaled),
                          or original vector if the face has no roughness model

# Notes
This function applies both rotation and scaling, suitable for geometric vectors
such as displacements and velocities. The scaling ensures that a unit vector
in local coordinates corresponds to the physical scale of the roughness model.

For physical vectors (e.g., forces, torques) that should preserve magnitude,
use `transform_physical_vector_global_to_local` instead.
"""
function transform_geometric_vector_global_to_local(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    v_global   ::StaticVector{3}
)
    # If no roughness model, return the original vector
    !has_roughness_model(hier_shape, face_idx) && return v_global

    # Get global-to-local transformation
    transform = get_roughness_model_transform(hier_shape, face_idx)
    
    # Extract the linear part of the transformation (rotation + scale)
    # For the geometric vector, we only need the linear transformation, not translation.
    v_local = transform.linear * v_global
    
    return v_local
end

"""
    transform_geometric_vector_local_to_global(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        v_local    ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a geometric vector from local to global coordinates.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face (1-based)
- `v_local::StaticVector{3}`           : Geometric vector in local roughness model coordinates

# Returns
- `SVector{3, Float64}` : Vector in global coordinates (scaled),
                          or original vector if the face has no roughness model

# Notes
Inverse transformation of `transform_geometric_vector_global_to_local`.
This function applies both rotation and scaling, suitable for geometric vectors
such as displacements and velocities.

For physical vectors (e.g., forces, torques) that should preserve magnitude,
use `transform_physical_vector_local_to_global` instead.
"""
function transform_geometric_vector_local_to_global(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    v_local    ::StaticVector{3}
)
    # If no roughness model, return the original vector
    !has_roughness_model(hier_shape, face_idx) && return v_local
    
    # Get global-to-local transformation
    transform = get_roughness_model_transform(hier_shape, face_idx)
    
    # Apply inverse linear transformation
    # For a geometric vector, we only need the inverse of the linear part.
    v_global = inv(transform.linear) * v_local
    
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

Transform a physical vector (e.g., force, torque, angular velocity) from global to local coordinates.
Physical vectors are only rotated, not scaled, preserving their physical magnitude.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face
- `v_global::StaticVector{3}`          : Physical vector in global coordinates

# Returns
- `SVector{3, Float64}` : Physical vector in local coordinate frame (not scaled),
                          or original vector if the face has no roughness model

# Note
Use this for quantities where the physical magnitude must be preserved:
- Forces and torques
- Angular velocities
- Magnetic fields
- Any vector representing a physical quantity rather than a geometric displacement

For geometric vectors (e.g., displacements, velocities),
use `transform_geometric_vector_global_to_local` instead.
"""
function transform_physical_vector_global_to_local(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    v_global   ::StaticVector{3}
)
    # If no roughness model, return the original vector
    !has_roughness_model(hier_shape, face_idx) && return v_global
    
    # Get global-to-local transformation
    transform = get_roughness_model_transform(hier_shape, face_idx)
    
    # Extract rotation part from the linear transformation
    # The linear part includes both rotation and scale, so we need to remove the scale
    # Since transform.linear = rotation * scale, we divide by scale to extract pure rotation
    scale = hier_shape.face_roughness_scales[face_idx]
    rotation = transform.linear / scale  # Extract pure rotation
    v_local = rotation * v_global        # Apply pure rotation
    
    return v_local
end

"""
    transform_physical_vector_local_to_global(
        hier_shape ::HierarchicalShapeModel,
        face_idx   ::Int,
        v_local    ::StaticVector{3}
    ) -> SVector{3, Float64}

Transform a physical vector (e.g., force, torque, angular velocity) from local to global coordinates.
Physical vectors are only rotated, not scaled, preserving their physical magnitude.

# Arguments
- `hier_shape::HierarchicalShapeModel` : The hierarchical shape model
- `face_idx::Int`                      : Index of the face
- `v_local::StaticVector{3}`           : Physical vector in local coordinates

# Returns
- `SVector{3, Float64}` : Physical vector in global coordinate frame (not scaled),
                          or original vector if the face has no roughness model

# Note
Use this for quantities where the physical magnitude must be preserved:
- Forces and torques
- Angular velocities  
- Magnetic fields
- Any vector representing a physical quantity rather than a geometric displacement

For geometric vectors (e.g., displacements, velocities),
use `transform_geometric_vector_local_to_global` instead.
"""
function transform_physical_vector_local_to_global(
    hier_shape ::HierarchicalShapeModel,
    face_idx   ::Int,
    v_local    ::StaticVector{3}
)
    # If no roughness model, return the original vector
    !has_roughness_model(hier_shape, face_idx) && return v_local
    
    # Get global-to-local transformation
    transform = get_roughness_model_transform(hier_shape, face_idx)
    
    # Extract rotation part from the linear transformation
    # Since transform.linear = rotation * scale, we divide by scale to extract pure rotation
    scale = hier_shape.face_roughness_scales[face_idx]
    rotation = transform.linear / scale  # Extract pure rotation
    v_global = rotation' * v_local       # Apply inverse rotation (transpose for orthogonal matrix)
    
    return v_global
end
