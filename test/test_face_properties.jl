@testset "Face properties" begin
    v1 = @SVector [0.0, 0.0, 0.0]
    v2 = @SVector [1.0, 0.0, 0.0]
    v3 = @SVector [0.0, 1.0, 0.0]
    
    center = face_center(v1, v2, v3)
    @test center ≈ @SVector [1/3, 1/3, 0.0]
    
    normal = face_normal(v1, v2, v3)
    @test normal ≈ @SVector [0.0, 0.0, 1.0]
    
    area = face_area(v1, v2, v3)
    @test area ≈ 0.5
end
