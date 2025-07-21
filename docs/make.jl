using AsteroidShapeModels
using Documenter

DocMeta.setdocmeta!(AsteroidShapeModels, :DocTestSetup, :(using AsteroidShapeModels); recursive=true)

makedocs(;
    modules=[AsteroidShapeModels],
    authors="Masanori Kanamaru <kanamaru-masanori@hotmail.co.jp>",
    sitename="AsteroidShapeModels.jl",
    format=Documenter.HTML(;
        canonical="https://astroshaper.github.io/AsteroidShapeModels.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "Guides" => [
            "BVH Usage" => "guides/bvh_usage.md",
        ],
        "API Reference" => [
            "Types" => "api/types.md",
            "I/O Functions" => "api/io.md",
            "Geometric Operations" => "api/geometry.md",
            "Ray Intersection" => "api/raycast.md",
            "Visibility Analysis" => "api/visibility.md",
            "Surface Roughness" => "api/roughness.md",
        ],
        "Benchmarks" => [
            "v0.2.0 Face Visibility Graph" => "benchmarks/v0.2.0_face_visibility_graph.md",
            "v0.4.2 Face Max Elevations" => "benchmarks/v0.4.2_face_max_elevations.md",
        ],
    ],
    checkdocs=:exports,
)

deploydocs(;
    repo="github.com/Astroshaper/AsteroidShapeModels.jl",
    devbranch="main",
    push_preview=true,
    versions=["stable" => "v^", "v#.#", "dev" => "dev"],
)