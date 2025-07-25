#=
    test_with_face_visibility.jl

Tests for face visibility and view factor calculations.
This file tests the visibility calculation between facets:
- Finding mutually visible facets in shape models
- Testing with convex shapes (no self-visibility)
- Testing with concave shapes (self-visibility expected)
- Verifying symmetry of visibility relationships
- Memory usage and performance characteristics

Ported from AsteroidThermoPhysicalModels.jl
=#
# Reference: https://github.com/Astroshaper/Astroshaper-examples/tree/main/TPM_Ryugu

@testset "with_face_visibility" begin
    msg = """\n
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    |                Test: with_face_visibility              |
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    """
    println(msg)

    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                        Ryugu Test Model                           ║
    # ╚═══════════════════════════════════════════════════════════════════╝
    # Test with a small version of the Ryugu asteroid shape model
    # This is a complex, irregular shape with many self-visible facets
    
    filepath = joinpath("shape", "ryugu_test.obj")
    println("========  $filepath  ========")
    shape = load_shape_obj(filepath; scale=1000, with_face_visibility=true)
    
    # Verify basic shape properties
    @test isa(shape, ShapeModel)
    @test length(shape.nodes) > 0
    @test length(shape.faces) > 0
    @test !isnothing(shape.face_visibility_graph)
    @test shape.face_visibility_graph.nfaces == length(shape.faces)
    
    # Display shape statistics
    println("Number of nodes: ", length(shape.nodes))
    println("Number of faces: ", length(shape.faces))
    println("Total visible face pairs: ", shape.face_visibility_graph.nnz)

    # Verify expected values for the test model
    @test length(shape.nodes) == 2976  # Expected number of nodes
    @test length(shape.faces) == 5932  # Expected number of faces
    @test shape.face_visibility_graph.nnz == 121516  # Expected visible pairs

    println()

    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                       Icosahedron Test                            ║
    # ╚═══════════════════════════════════════════════════════════════════╝
    # Test with a convex icosahedron
    # For a perfect convex shape, no face should see any other face
    # (all faces point outward)
    
    filepath = joinpath("shape", "icosahedron.obj")
    println("========  $filepath  ========")
    shape = load_shape_obj(filepath; scale=1, with_face_visibility=true)
    
    # Count total visible facets
    total_visible = shape.face_visibility_graph.nnz
    println("Total visible facet pairs: $total_visible")
    println("(It should be zero for a convex icosahedron.)")
    
    # Verify no self-visibility for convex shape
    @test total_visible == 0

    println()
    
    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║               Concave Spherical Segment (Crater)                  ║
    # ╚═══════════════════════════════════════════════════════════════════╝
    # Test with a crater-like shape generated using roughness functions
    # Faces at the bottom of the crater should see many other faces
    
    println("========  Concave spherical segment (crater)  ========")
    
    # Generate crater shape using imported roughness function
    xs, ys, zs = concave_spherical_segment(0.4, 0.2; Nx=2^5, Ny=2^5, xc=0.5, yc=0.5)
    shape = load_shape_grid(xs, ys, zs; scale=1.0, with_face_visibility=true)
    
    # Check visibility from crater center (face index 992 for this grid)
    # This face is at the bottom of the crater and should see many faces
    println("Number of faces visible from the crater center: ", num_visible_faces(shape.face_visibility_graph, 992))
    @test num_visible_faces(shape.face_visibility_graph, 992) == 1053  # Expected visibility count

    println()
    
    # ╔═══════════════════════════════════════════════════════════════════╗
    # ║                    Visibility Symmetry Test                       ║
    # ╚═══════════════════════════════════════════════════════════════════╝
    # Verify that visibility is symmetric:
    # If face i sees face j, then face j must also see face i
    
    println("========  Visibility symmetry test  ========")
    
    # Use the last loaded shape (crater) for symmetry test
    symmetric = true
    asymmetric_pairs = 0
    
    for i in 1:shape.face_visibility_graph.nfaces
        visible_faces = get_visible_face_indices(shape.face_visibility_graph, i)
        for j in visible_faces
            # Check if face i is visible from face j
            visible_from_j = get_visible_face_indices(shape.face_visibility_graph, j)
            if !(i in visible_from_j)
                symmetric = false
                asymmetric_pairs += 1
                if asymmetric_pairs == 1  # Only warn about first asymmetry
                    @warn "Asymmetric visibility: Face $i sees face $j, but not vice versa"
                end
            end
        end
    end
    
    if asymmetric_pairs > 0
        @warn "Total asymmetric visibility pairs: $asymmetric_pairs"
    else
        println("✓ All visibility relationships are symmetric")
    end
    
    @test symmetric
    
    println()
end
