# ====================================================================
#                    Face Properties Tests
# ====================================================================
# This file tests the basic geometric properties of triangular faces:
# - Face center calculation
# - Face normal vector computation
# - Face area calculation

@testset "Face properties" begin

    # Define a simple triangle on the XY plane.
    #
    #      v3 (0,1,0)
    #       |╲
    #       | ╲
    #       |  ╲
    #       |   ╲ (hypotenuse = √2)
    #       |    ╲
    #       |_____╲
    #      v1      v2
    #   (0,0,0)  (1,0,0)
    
    v1 = @SVector [0.0, 0.0, 0.0]  # Origin
    v2 = @SVector [1.0, 0.0, 0.0]  # Unit distance along X
    v3 = @SVector [0.0, 1.0, 0.0]  # Unit distance along Y
    
    # ----------------------------------------------------------------
    #                    Face Center Test
    # ----------------------------------------------------------------

    # The centroid of a triangle is at the average of its vertices.
    center = face_center(v1, v2, v3)
    @test center ≈ @SVector [1/3, 1/3, 0.0]
    
    # ----------------------------------------------------------------
    #                    Face Normal Test
    # ----------------------------------------------------------------

    # For a triangle in the XY plane with vertices ordered counter-clockwise,
    # the normal should point in the positive Z direction.
    normal = face_normal(v1, v2, v3)
    @test normal ≈ @SVector [0.0, 0.0, 1.0]
    
    # ----------------------------------------------------------------
    #                     Face Area Test
    # ----------------------------------------------------------------

    # Area of the triangle = 1/2 × base (1) × height (1)
    area = face_area(v1, v2, v3)
    @test area ≈ 0.5
end
