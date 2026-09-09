# Types

```@meta
CurrentModule = AsteroidShapeModels
```

## Core Types

```@docs
AbstractShapeModel
ShapeModel
SurfaceRoughness
Ray
Sphere
```

## Result Types

```@docs
RayTriangleIntersectionResult
RayShapeIntersectionResult
RaySphereIntersectionResult
```

## Face-Face Visibility Types

```@docs
FaceVisibilityGraph
```

## Optional-Field Predicates

```@docs
has_face_visibility_graph
has_face_max_elevations
has_bvh
```

## Functions to accelerate ray tracing

```@docs
build_bvh!
```