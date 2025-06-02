@testset "Geometry Utility Functions (FOVSimulator ported tests)" begin
    # Test angle functions
    @test angle_deg([1, 0, 0], [ 0, 1, 0]) ≈ 90
    @test angle_deg([1, 0, 0], [ 1, 0, 0]) ≈ 0
    @test angle_deg([1, 0, 0], [-1, 0, 0]) ≈ 180

    @test angle_rad([1, 0, 0], [ 0, 1, 0]) ≈ π/2
    @test angle_rad([1, 0, 0], [ 1, 0, 0]) ≈ 0
    @test angle_rad([1, 0, 0], [-1, 0, 0]) ≈ π

    # Test solar geometry functions
    sun = [1, 0, 0]
    tgt = [0, 0, 0]
    obs = [0, 1, 0]

    @test solar_phase_angle(sun, tgt, obs) ≈ deg2rad(90)
    @test solar_elongation_angle(sun, obs, tgt) ≈ deg2rad(45)

    # Test edge cases
    @test angle_deg([1, 1, 0], [1, 1, 0]) ≈ 0 atol=1e-5  # Same vector
    @test angle_deg([1, 0, 0], [0, 0, 1]) ≈ 90           # Perpendicular vectors
    
    # Test with different vector magnitudes
    @test angle_deg([2, 0, 0], [0, 3, 0]) ≈ 90           # Perpendicular vectors
    @test angle_deg([5, 0, 0], [5, 0, 0]) ≈ 0 atol=1e-5  # Same vector
end
