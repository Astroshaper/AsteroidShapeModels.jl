# This file is kept for backward compatibility
# It simply includes the new type definition files in the correct order

include("type_definitions.jl")
# FaceVisibilityGraph is defined after this file in the module
# ShapeModel is included later after FaceVisibilityGraph is available