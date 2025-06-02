@testset "find_visiblefacets" begin
    msg = """\n
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    |                Test: find_visiblefacets                |
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    """
    println(msg)

    ##= Shape model of Ryugu =##
    filepath = joinpath("shape", "ryugu_test.obj")  # Small model for test
    println("========  $filepath  ========")
    shape = load_shape_obj(filepath; scale=1000, find_visible_facets=true)
    
    # Basic checks
    @test isa(shape, ShapeModel)
    @test length(shape.nodes) > 0
    @test length(shape.faces) > 0
    @test length(shape.visiblefacets) == length(shape.faces)
    
    println("Number of nodes: ", length(shape.nodes))
    println("Number of faces: ", length(shape.faces))
    println("Total visible facet pairs: ", sum(length.(shape.visiblefacets)))

    @test length(shape.nodes) == 2976  # Expected number of nodes in the test model
    @test length(shape.faces) == 5932  # Expected number of faces in the test model
    @test sum(length.(shape.visiblefacets)) == 121516  # Expected number of pairs of visible facets

    println()

    ##= Icosahedron =##
    filepath = joinpath("shape", "icosahedron.obj")
    println("========  $filepath  ========")
    shape = load_shape_obj(filepath; scale=1, find_visible_facets=true)
    
    # For a convex icosahedron, no face should see any other face
    total_visible = sum(length.(shape.visiblefacets))
    println("Number of total visible facets: $total_visible")
    println("(It should be zero for a convex icosahedron.)")
    @test total_visible == 0  # This should be zero for a convex icosahedron

    println()
    
    ##= Concave spherical segment (crater) =##    
    println("========  Concave spherical segment (crater)  ========")
    xs, ys, zs = concave_spherical_segment(0.4, 0.2; Nx=2^5, Ny=2^5, xc=0.5, yc=0.5)
    shape = load_shape_grid(xs, ys, zs; scale=1.0, find_visible_facets=true)
    
    println("Number of faces visible from the crater center: ", length(shape.visiblefacets[992]))
    @test length(shape.visiblefacets[992]) == 1053  # There should be visible facets from the crater center.

    println()
end
