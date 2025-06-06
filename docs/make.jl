using AsteroidShapeModels
using Documenter

DocMeta.setdocmeta!(AsteroidShapeModels, :DocTestSetup, :(using AsteroidShapeModels); recursive=true)

makedocs(;
    modules=[AsteroidShapeModels],
    authors="Masanori Kanamaru <kanamaru-masanori@hotmail.co.jp>",
    sitename="AsteroidShapeModels.jl",
    format=Documenter.HTML(;
        canonical="https://github.com/Astroshaper/AsteroidShapeModels.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "API Reference" => [
            "Types" => "api/types.md",
            "I/O Functions" => "api/io.md",
            "Geometric Operations" => "api/geometry.md",
            "Ray Intersection" => "api/raycast.md",
            "Visibility Analysis" => "api/visibility.md",
            "Surface Roughness" => "api/roughness.md",
        ],
    ],
)

deploydocs(;
    repo="github.com/Astroshaper/AsteroidShapeModels.jl",
    devbranch="main",
)