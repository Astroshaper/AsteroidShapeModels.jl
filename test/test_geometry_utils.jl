#=
    test_geometry_utils.jl

Tests for geometry utility functions.
This file tests utility functions for geometric calculations:
- Angle calculations between vectors (in radians and degrees)
- Solar geometry calculations (phase angle, elongation angle)
- Vector algebra utilities
=#

@testset "Geometry Utility Functions (FOVSimulator ported tests)" begin
    
    # ----------------------------------------------------------------
    #                    Basic Angle Functions
    # ----------------------------------------------------------------

    @testset "Angle calculations in degrees" begin
        # Test perpendicular vectors (90°)
        #   Y
        #   ^
        #   |
        #   +---> X
        @test angle_deg([1, 0, 0], [0, 1, 0]) ≈ 90
        
        # Test parallel vectors (0°)
        @test angle_deg([1, 0, 0], [1, 0, 0]) ≈ 0
        
        # Test opposite vectors (180°)
        #   <----+---->
        @test angle_deg([1, 0, 0], [-1, 0, 0]) ≈ 180
    end

    @testset "Angle calculations in radians" begin
        # Test perpendicular vectors (π/2)
        @test angle_rad([1, 0, 0], [0, 1, 0]) ≈ π/2
        
        # Test parallel vectors (0)
        @test angle_rad([1, 0, 0], [1, 0, 0]) ≈ 0
        
        # Test opposite vectors (π)
        @test angle_rad([1, 0, 0], [-1, 0, 0]) ≈ π
    end

    # ----------------------------------------------------------------
    #                   Solar Geometry Functions
    # ----------------------------------------------------------------

    @testset "Solar geometry calculations" begin
        # Define a simple configuration:
        # - Sun along positive X axis
        # - Target at origin
        # - Observer along positive Y axis
        #
        #     Observer
        #     (0,1,0)
        #        |
        #        |
        #        +------ (1,0,0) Sun
        #     (0,0,0)
        #     Target
        
        sun = [1, 0, 0]
        tgt = [0, 0, 0]
        obs = [0, 1, 0]

        # Solar phase angle: angle at target between sun and observer
        # This situation creates a 90° phase angle.
        @test solar_phase_angle(sun, tgt, obs) ≈ deg2rad(90)
        
        # Solar elongation angle: angle at observer between sun and target
        # In this configuration, it's 45°.
        @test solar_elongation_angle(sun, obs, tgt) ≈ deg2rad(45)
    end

    # ----------------------------------------------------------------
    #                      Edge Cases
    # ----------------------------------------------------------------

    @testset "Edge cases and vector magnitude independence" begin
        # Same vector should give 0° angle
        @test angle_deg([1, 1, 0], [1, 1, 0]) ≈ 0 atol=1e-5
        
        # Perpendicular vectors in XZ plane
        @test angle_deg([1, 0, 0], [0, 0, 1]) ≈ 90
        
        # Test that angle calculation is independent of vector magnitude
        @test angle_deg([2, 0, 0], [0, 3, 0]) ≈ 90           # Different magnitudes
        @test angle_deg([5, 0, 0], [5, 0, 0]) ≈ 0 atol=1e-5  # Same direction, different magnitude
    end
end
