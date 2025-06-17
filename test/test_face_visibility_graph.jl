using Test
using AsteroidShapeModels
using StaticArrays

@testset "FaceVisibilityGraph" begin
    
    @testset "Basic Construction" begin
        # 空のグラフ
        graph = FaceVisibilityGraph()
        @test graph.nfaces == 0
        @test graph.nnz == 0
        
        # 指定サイズの空グラフ
        graph = FaceVisibilityGraph(5)
        @test graph.nfaces == 5
        @test graph.nnz == 0
    end
    
    @testset "Construction from Adjacency List" begin
        # 簡単なテストケース
        visiblefacets = [
            [VisibleFacet(2, 0.1, 1.0, SA[1.0, 0.0, 0.0]), 
             VisibleFacet(3, 0.2, 2.0, SA[0.0, 1.0, 0.0])],
            [VisibleFacet(1, 0.1, 1.0, SA[-1.0, 0.0, 0.0])],
            [VisibleFacet(1, 0.2, 2.0, SA[0.0, -1.0, 0.0])]
        ]
        
        # 隣接リストからCSR形式へ変換
        graph = FaceVisibilityGraph(visiblefacets)
        
        @test graph.nfaces == 3
        @test graph.nnz == 4
        @test graph.row_ptr == [1, 3, 4, 5]
        @test graph.col_idx == [2, 3, 1, 1]
        @test graph.view_factors ≈ [0.1, 0.2, 0.1, 0.2]
        @test graph.distances ≈ [1.0, 2.0, 1.0, 2.0]
    end
    
    @testset "Data Access Methods" begin
        visiblefacets = [
            [VisibleFacet(2, 0.1, 1.0, SA[1.0, 0.0, 0.0]), 
             VisibleFacet(3, 0.2, 2.0, SA[0.0, 1.0, 0.0])],
            [VisibleFacet(1, 0.3, 1.5, SA[-1.0, 0.0, 0.0]),
             VisibleFacet(3, 0.4, 2.5, SA[0.0, 0.0, 1.0])],
            VisibleFacet[]
        ]
        
        graph = FaceVisibilityGraph(visiblefacets)
        
        # get_visible_faces
        @test collect(get_visible_faces(graph, 1)) == [2, 3]
        @test collect(get_visible_faces(graph, 2)) == [1, 3]
        @test collect(get_visible_faces(graph, 3)) == []
        
        # get_view_factors
        @test collect(get_view_factors(graph, 1)) ≈ [0.1, 0.2]
        @test collect(get_view_factors(graph, 2)) ≈ [0.3, 0.4]
        @test collect(get_view_factors(graph, 3)) == []
        
        # get_distances
        @test collect(get_distances(graph, 1)) ≈ [1.0, 2.0]
        @test collect(get_distances(graph, 2)) ≈ [1.5, 2.5]
        
        # get_directions
        @test collect(get_directions(graph, 1))[1] ≈ SA[1.0, 0.0, 0.0]
        @test collect(get_directions(graph, 1))[2] ≈ SA[0.0, 1.0, 0.0]
        
        # num_visible_faces
        @test num_visible_faces(graph, 1) == 2
        @test num_visible_faces(graph, 2) == 2
        @test num_visible_faces(graph, 3) == 0
        
        # get_visible_facet_data
        data = get_visible_facet_data(graph, 1, 1)
        @test data.id == 2
        @test data.f ≈ 0.1
        @test data.d ≈ 1.0
        @test data.d̂ ≈ SA[1.0, 0.0, 0.0]
    end
    
    @testset "Memory Usage" begin
        # 大きめのグラフでメモリ使用量を確認
        n = 100
        visiblefacets = [VisibleFacet[] for _ in 1:n]
        
        # 各面が平均10個の可視面を持つ
        for i in 1:n
            for j in 1:10
                target = mod1(i + j, n)
                push!(visiblefacets[i], VisibleFacet(target, 0.1, 1.0, SA[0.0, 0.0, 1.0]))
            end
        end
        
        graph = FaceVisibilityGraph(visiblefacets)
        
        @test graph.nfaces == n
        @test graph.nnz == n * 10
        
        # メモリ使用量の計算
        mem_usage = memory_usage(graph)
        expected_min = sizeof(Int) * (n + 1 + n * 10) + sizeof(Float64) * (n * 10 * 2) + sizeof(SVector{3, Float64}) * n * 10
        @test mem_usage >= expected_min
    end
    
    @testset "Bounds Checking" begin
        graph = FaceVisibilityGraph(3)
        
        # 境界外アクセスのテスト
        @test_throws BoundsError get_visible_faces(graph, 0)
        @test_throws BoundsError get_visible_faces(graph, 4)
        @test_throws BoundsError get_view_factors(graph, 0)
        @test_throws BoundsError num_visible_faces(graph, 4)
    end
end

@testset "ShapeModel with FaceVisibilityGraph" begin
    # 簡単な四面体のテスト
    nodes = [
        SA[0.0, 0.0, 0.0],
        SA[1.0, 0.0, 0.0],
        SA[0.0, 1.0, 0.0],
        SA[0.0, 0.0, 1.0]
    ]
    faces = [
        SA[1, 3, 2],  # 底面（法線を外向きに）
        SA[1, 2, 4],  # 側面1
        SA[1, 4, 3],  # 側面2（法線を外向きに）
        SA[2, 3, 4]   # 側面3
    ]
    
    @testset "Visibility Computation" begin
        shape = ShapeModel(nodes, faces)
        find_visiblefacets!(shape)
        
        # visibility_graphが作成されていることを確認
        @test !isnothing(shape.visibility_graph)
        @test shape.visibility_graph.nfaces == length(faces)
        
        # 凸形状（四面体）の場合、どの面からも他の面は見えない
        total_visible = shape.visibility_graph.nnz
        @test total_visible == 0  # 凸形状なので可視面はゼロ
        
        for i in 1:length(faces)
            visible_faces = collect(get_visible_faces(shape.visibility_graph, i))
            @test length(visible_faces) == 0  # どの面も他の面を見ない
        end
    end
    
    @testset "isilluminated with FaceVisibilityGraph" begin
        shape = ShapeModel(nodes, faces)
        find_visiblefacets!(shape)
        
        # 太陽の位置
        r_sun = SA[1.0, 1.0, 1.0]
        
        # 各面の照明状態をテスト
        for i in 1:length(faces)
            illuminated = isilluminated(shape, r_sun, i)
            # 四面体の場合、少なくともいくつかの面は照らされる
            @test illuminated isa Bool
        end
        
        # visibility_graphが計算されていない場合のエラーテスト
        shape_no_vis = ShapeModel(nodes, faces)
        # 面4は太陽に向いているため、visibility_graphのチェックに到達する
        @test_throws ErrorException isilluminated(shape_no_vis, r_sun, 4)
    end
end

