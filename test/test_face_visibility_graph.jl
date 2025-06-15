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
    
    @testset "From/To Adjacency List Conversion" begin
        # 簡単なテストケース
        visiblefacets = [
            [VisibleFacet(2, 0.1, 1.0, SA[1.0, 0.0, 0.0]), 
             VisibleFacet(3, 0.2, 2.0, SA[0.0, 1.0, 0.0])],
            [VisibleFacet(1, 0.1, 1.0, SA[-1.0, 0.0, 0.0])],
            [VisibleFacet(1, 0.2, 2.0, SA[0.0, -1.0, 0.0])]
        ]
        
        # 隣接リストからCSR形式へ変換
        graph = from_adjacency_list(visiblefacets)
        
        @test graph.nfaces == 3
        @test graph.nnz == 4
        @test graph.row_ptr == [1, 3, 4, 5]
        @test graph.col_idx == [2, 3, 1, 1]
        @test graph.view_factors ≈ [0.1, 0.2, 0.1, 0.2]
        @test graph.distances ≈ [1.0, 2.0, 1.0, 2.0]
        
        # CSR形式から隣接リストへ変換
        converted_back = to_adjacency_list(graph)
        
        @test length(converted_back) == length(visiblefacets)
        for i in eachindex(visiblefacets)
            @test length(converted_back[i]) == length(visiblefacets[i])
            for j in eachindex(visiblefacets[i])
                @test converted_back[i][j].id == visiblefacets[i][j].id
                @test converted_back[i][j].f ≈ visiblefacets[i][j].f
                @test converted_back[i][j].d ≈ visiblefacets[i][j].d
                @test converted_back[i][j].d̂ ≈ visiblefacets[i][j].d̂
            end
        end
    end
    
    @testset "Data Access Methods" begin
        visiblefacets = [
            [VisibleFacet(2, 0.1, 1.0, SA[1.0, 0.0, 0.0]), 
             VisibleFacet(3, 0.2, 2.0, SA[0.0, 1.0, 0.0])],
            [VisibleFacet(1, 0.3, 1.5, SA[-1.0, 0.0, 0.0]),
             VisibleFacet(3, 0.4, 2.5, SA[0.0, 0.0, 1.0])],
            VisibleFacet[]
        ]
        
        graph = from_adjacency_list(visiblefacets)
        
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
        
        graph = from_adjacency_list(visiblefacets)
        
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
        SA[1, 2, 3],
        SA[1, 2, 4],
        SA[1, 3, 4],
        SA[2, 3, 4]
    ]
    
    @testset "Legacy vs New Implementation" begin
        # レガシー実装
        shape_legacy = ShapeModel(nodes, faces)
        find_visiblefacets!(shape_legacy, use_visibility_graph=false)
        
        # 新実装
        shape_new = ShapeModel(nodes, faces)
        find_visiblefacets!(shape_new, use_visibility_graph=true)
        
        # visibility_graphが作成されていることを確認
        @test !isnothing(shape_new.visibility_graph)
        @test shape_new.visibility_graph.nfaces == length(faces)
        
        # 結果が一致することを確認
        for i in 1:length(faces)
            legacy_visible = shape_legacy.visiblefacets[i]
            new_visible = shape_new.visiblefacets[i]
            
            @test length(legacy_visible) == length(new_visible)
            
            # 同じ可視面を持つことを確認（順序は異なる可能性がある）
            legacy_ids = sort([vf.id for vf in legacy_visible])
            new_ids = sort([vf.id for vf in new_visible])
            @test legacy_ids == new_ids
            
            # ビューファクターも一致することを確認
            for vf_legacy in legacy_visible
                vf_new = findfirst(vf -> vf.id == vf_legacy.id, new_visible)
                @test !isnothing(vf_new)
                @test new_visible[vf_new].f ≈ vf_legacy.f
                @test new_visible[vf_new].d ≈ vf_legacy.d
                @test new_visible[vf_new].d̂ ≈ vf_legacy.d̂
            end
        end
    end
    
    @testset "isilluminated with FaceVisibilityGraph" begin
        shape = ShapeModel(nodes, faces)
        find_visiblefacets!(shape, use_visibility_graph=true)
        
        # 太陽の位置
        r_sun = SA[1.0, 1.0, 1.0]
        
        # 両方の実装で同じ結果を返すことを確認
        for i in 1:length(faces)
            # visibility_graphを使用
            illuminated_new = isilluminated(shape, r_sun, i)
            
            # 一時的にvisibility_graphをnothingにしてレガシー実装をテスト
            temp_graph = shape.visibility_graph
            shape.visibility_graph = nothing
            illuminated_legacy = isilluminated(shape, r_sun, i)
            shape.visibility_graph = temp_graph
            
            @test illuminated_new == illuminated_legacy
        end
    end
end

@testset "Performance and Memory Comparison" begin
    # より大きなテストケース（立方体）
    function create_cube()
        # 単位立方体を作成
        cube_nodes = [
            SA[-1.0, -1.0, -1.0], SA[1.0, -1.0, -1.0],
            SA[1.0, 1.0, -1.0], SA[-1.0, 1.0, -1.0],
            SA[-1.0, -1.0, 1.0], SA[1.0, -1.0, 1.0],
            SA[1.0, 1.0, 1.0], SA[-1.0, 1.0, 1.0]
        ]
        
        cube_faces = [
            SA[1, 2, 3], SA[1, 3, 4],  # bottom
            SA[5, 7, 6], SA[5, 8, 7],  # top
            SA[1, 5, 6], SA[1, 6, 2],  # front
            SA[3, 7, 8], SA[3, 8, 4],  # back
            SA[1, 4, 8], SA[1, 8, 5],  # left
            SA[2, 6, 7], SA[2, 7, 3]   # right
        ]
        
        return cube_nodes, cube_faces
    end
    
    nodes, faces = create_cube()
    
    # メモリ使用量の比較
    shape1 = ShapeModel(nodes, faces)
    find_visiblefacets!(shape1, use_visibility_graph=false)
    
    shape2 = ShapeModel(nodes, faces)
    find_visiblefacets!(shape2, use_visibility_graph=true)
    
    # FaceVisibilityGraphの方がメモリ効率が良いことを確認
    if !isnothing(shape2.visibility_graph)
        graph_memory = memory_usage(shape2.visibility_graph)
        
        # 隣接リストのメモリ使用量を推定
        adjacency_memory = 0
        for vf_list in shape1.visiblefacets
            adjacency_memory += sizeof(vf_list) + length(vf_list) * sizeof(VisibleFacet)
        end
        
        println("Memory usage comparison:")
        println("  Adjacency list: ~$(adjacency_memory) bytes")
        println("  FaceVisibilityGraph: $(graph_memory) bytes")
        
        # CSR形式の方が一般的に効率的であることを確認（特に大規模データで）
        # ただし、非常に小さなグラフでは必ずしもそうではない
    end
end