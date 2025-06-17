"""
    FaceVisibilityGraph

CSR（Compressed Sparse Row）形式を採用した効率的な可視面グラフ構造。
隣接リスト形式と比較してメモリ効率が良く、キャッシュ局所性も優れている。

# Fields
- `row_ptr`: 各面の可視面データの開始インデックス（長さ: nfaces + 1）
- `col_idx`: 可視面のインデックス（CSR形式の列インデックス）
- `view_factors`: 各可視面ペアのビューファクター
- `distances`: 各可視面ペア間の距離
- `directions`: 各可視面ペア間の単位方向ベクトル
- `nfaces`: 総面数
- `nnz`: 非ゼロ要素数（可視面ペアの総数）

# 例
面1が面2,3と、面2が面1,3,4と可視の場合：
- row_ptr = [1, 3, 6, 7]
- col_idx = [2, 3, 1, 3, 4, ...]
"""
struct FaceVisibilityGraph
    row_ptr::Vector{Int}
    col_idx::Vector{Int}
    view_factors::Vector{Float64}
    distances::Vector{Float64}
    directions::Vector{SVector{3, Float64}}
    nfaces::Int
    nnz::Int
    
    function FaceVisibilityGraph(
        row_ptr::Vector{Int}, 
        col_idx::Vector{Int},
        view_factors::Vector{Float64},
        distances::Vector{Float64},
        directions::Vector{SVector{3, Float64}}
    )
        nfaces = length(row_ptr) - 1
        nnz = length(col_idx)
        
        # 妥当性チェック
        @assert row_ptr[1] == 1 "row_ptr must start with 1"
        @assert row_ptr[end] == nnz + 1 "row_ptr[end] must equal nnz + 1"
        @assert length(view_factors) == nnz "view_factors length must equal nnz"
        @assert length(distances) == nnz "distances length must equal nnz"
        @assert length(directions) == nnz "directions length must equal nnz"
        @assert all(1 .<= col_idx .<= nfaces) "col_idx must be in range [1, nfaces]"
        
        new(row_ptr, col_idx, view_factors, distances, directions, nfaces, nnz)
    end
end

"""
    FaceVisibilityGraph() -> FaceVisibilityGraph

空のFaceVisibilityGraphを作成。
"""
FaceVisibilityGraph() = FaceVisibilityGraph(Int[1], Int[], Float64[], Float64[], SVector{3, Float64}[])

"""
    FaceVisibilityGraph(nfaces::Int) -> FaceVisibilityGraph

指定された面数で空のFaceVisibilityGraphを作成。
"""
function FaceVisibilityGraph(nfaces::Int)
    row_ptr = ones(Int, nfaces + 1)
    FaceVisibilityGraph(row_ptr, Int[], Float64[], Float64[], SVector{3, Float64}[])
end

"""
    Base.show(io::IO, graph::FaceVisibilityGraph)

FaceVisibilityGraphの表示。
"""
function Base.show(io::IO, graph::FaceVisibilityGraph)
    print(io, "FaceVisibilityGraph:\n")
    print(io, "  Number of faces: $(graph.nfaces)\n")
    print(io, "  Number of visible pairs: $(graph.nnz)\n")
    if graph.nnz > 0
        avg_visible = graph.nnz / graph.nfaces
        print(io, "  Average visible faces per face: $(round(avg_visible, digits=2))\n")
    end
end

"""
    get_visible_faces(graph::FaceVisibilityGraph, face_id::Int) -> SubArray

指定された面の可視面インデックスを取得。
"""
function get_visible_faces(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    start_idx = graph.row_ptr[face_id]
    end_idx = graph.row_ptr[face_id + 1] - 1
    return @view graph.col_idx[start_idx:end_idx]
end

"""
    get_view_factors(graph::FaceVisibilityGraph, face_id::Int) -> SubArray

指定された面のビューファクターを取得。
"""
function get_view_factors(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    start_idx = graph.row_ptr[face_id]
    end_idx = graph.row_ptr[face_id + 1] - 1
    return @view graph.view_factors[start_idx:end_idx]
end

"""
    get_distances(graph::FaceVisibilityGraph, face_id::Int) -> SubArray

指定された面の距離情報を取得。
"""
function get_distances(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    start_idx = graph.row_ptr[face_id]
    end_idx = graph.row_ptr[face_id + 1] - 1
    return @view graph.distances[start_idx:end_idx]
end

"""
    get_directions(graph::FaceVisibilityGraph, face_id::Int) -> SubArray

指定された面の方向ベクトルを取得。
"""
function get_directions(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    start_idx = graph.row_ptr[face_id]
    end_idx = graph.row_ptr[face_id + 1] - 1
    return @view graph.directions[start_idx:end_idx]
end

"""
    get_visible_facet_data(graph::FaceVisibilityGraph, face_id::Int, idx::Int)

指定された面のidx番目の可視面データを取得。
"""
function get_visible_facet_data(graph::FaceVisibilityGraph, face_id::Int, idx::Int)
    visible_faces = get_visible_faces(graph, face_id)
    @boundscheck 1 <= idx <= length(visible_faces) || throw(BoundsError())
    
    base_idx = graph.row_ptr[face_id] + idx - 1
    return (
        id = graph.col_idx[base_idx],
        f = graph.view_factors[base_idx],
        d = graph.distances[base_idx],
        d̂ = graph.directions[base_idx]
    )
end

"""
    num_visible_faces(graph::FaceVisibilityGraph, face_id::Int) -> Int

指定された面の可視面数を取得。
"""
function num_visible_faces(graph::FaceVisibilityGraph, face_id::Int)
    @boundscheck 1 <= face_id <= graph.nfaces || throw(BoundsError(graph, face_id))
    return graph.row_ptr[face_id + 1] - graph.row_ptr[face_id]
end

"""
    FaceVisibilityGraph(visiblefacets::Vector{Vector{VisibleFacet}}) -> FaceVisibilityGraph

可視面データの隣接リスト形式からFaceVisibilityGraphを構築。

内部使用のみ。`find_visiblefacets!`から呼ばれる。
"""
function FaceVisibilityGraph(visiblefacets::Vector{Vector{VisibleFacet}})
    nfaces = length(visiblefacets)
    nnz = sum(length.(visiblefacets))
    
    # CSR形式のデータを構築
    row_ptr = Vector{Int}(undef, nfaces + 1)
    col_idx = Vector{Int}(undef, nnz)
    view_factors = Vector{Float64}(undef, nnz)
    distances = Vector{Float64}(undef, nnz)
    directions = Vector{SVector{3, Float64}}(undef, nnz)
    
    # row_ptrを構築
    row_ptr[1] = 1
    for i in 1:nfaces
        row_ptr[i + 1] = row_ptr[i] + length(visiblefacets[i])
    end
    
    # データをコピー
    idx = 1
    for i in 1:nfaces
        for vf in visiblefacets[i]
            col_idx[idx] = vf.id
            view_factors[idx] = vf.f
            distances[idx] = vf.d
            directions[idx] = vf.d̂
            idx += 1
        end
    end
    
    return FaceVisibilityGraph(row_ptr, col_idx, view_factors, distances, directions)
end

"""
    memory_usage(graph::FaceVisibilityGraph) -> Int

FaceVisibilityGraphのメモリ使用量をバイト単位で推定。
"""
function memory_usage(graph::FaceVisibilityGraph)
    row_ptr_size = sizeof(graph.row_ptr)
    col_idx_size = sizeof(graph.col_idx)
    view_factors_size = sizeof(graph.view_factors)
    distances_size = sizeof(graph.distances)
    directions_size = sizeof(graph.directions)
    
    return row_ptr_size + col_idx_size + view_factors_size + distances_size + directions_size
end