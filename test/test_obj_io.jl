#=
    test_obj_io.jl

Tests for Wavefront OBJ file I/O operations.
This file verifies:
- Loading vertices and faces from OBJ files
- Handling of different OBJ file formats
- Scaling transformations during loading
- File path validation
- Integration with shape model construction
=#

@testset "OBJ I/O Tests" begin
    
    @testset "File Extension Checking" begin
        @testset "Valid OBJ files" begin
            @test isobj("model.obj") == true
            @test isobj("my_asteroid.obj") == true
            @test isobj("path/to/model.obj") == true
            @test isobj("/absolute/path/model.obj") == true
        end
        
        @testset "Invalid extensions" begin
            @test isobj("model.OBJ") == false  # Case sensitive
            @test isobj("model.stl") == false
            @test isobj("model.ply") == false
            @test isobj("modelobj") == false   # No dot
            @test isobj("model.obj.txt") == false
            @test isobj("") == false
            @test isobj("noextension") == false
        end
        
        @testset "Edge cases" begin
            @test isobj(".obj")       == false  # Just extension (splitext returns ("", ".obj"))
            @test isobj("..obj")      == true   # Double dot
            @test isobj("model..obj") == true   # Double dot
            @test isobj("model.")     == false  # Trailing dot
        end
    end
    
    @testset "OBJ Loading" begin
        @testset "Non-existent file" begin
            # Should throw an error when file doesn't exist
            @test_throws Exception load_obj("nonexistent_file.obj")
            @test_throws Exception load_obj("/path/to/nowhere/model.obj")
        end
        
        @testset "Scale parameter" begin
            # Create a temporary test file
            test_obj_content = """
            v 1.0 0.0 0.0
            v 0.0 1.0 0.0
            v 0.0 0.0 1.0
            f 1 2 3
            """
            
            # Write to temporary file
            temp_file = tempname() * ".obj"
            open(temp_file, "w") do io
                write(io, test_obj_content)
            end
            
            try
                # Load with default scale
                nodes1, faces1 = load_obj(temp_file)
                @test length(nodes1) == 3
                @test length(faces1) == 1
                @test nodes1[1] ≈ SA[1.0, 0.0, 0.0]
                
                # Load with scale = 2
                nodes2, faces2 = load_obj(temp_file, scale=2.0)
                @test length(nodes2) == 3
                @test nodes2[1] ≈ SA[2.0, 0.0, 0.0]
                @test nodes2[2] ≈ SA[0.0, 2.0, 0.0]
                @test nodes2[3] ≈ SA[0.0, 0.0, 2.0]
                
                # Load with scale = 0.5
                nodes3, faces3 = load_obj(temp_file, scale=0.5)
                @test nodes3[1] ≈ SA[0.5, 0.0, 0.0]
                
                # Face indices should not change with scale
                @test faces1 == faces2 == faces3
            finally
                # Clean up
                rm(temp_file, force=true)
            end
        end
        
        @testset "Basic loading" begin
            # Create a temporary test file
            test_obj_content = """
            v 1.0 0.0 0.0
            v 0.0 1.0 0.0
            v 0.0 0.0 1.0
            f 1 2 3
            """
            
            temp_file = tempname() * ".obj"
            open(temp_file, "w") do io
                write(io, test_obj_content)
            end
            
            try
                # Test basic loading
                nodes, faces = load_obj(temp_file)
                @test length(nodes) == 3
                @test length(faces) == 1
            finally
                rm(temp_file, force=true)
            end
        end
        
        @testset "Complex OBJ features" begin
            # Test with comments and empty lines
            test_obj_content = """
            # This is a comment
            v 1.0 0.0 0.0
            v 0.0 1.0 0.0
            
            # Another comment
            v 0.0 0.0 1.0
            f 1 2 3
            """
            
            temp_file = tempname() * ".obj"
            open(temp_file, "w") do io
                write(io, test_obj_content)
            end
            
            try
                nodes, faces = load_obj(temp_file)
                @test length(nodes) == 3
                @test length(faces) == 1
            finally
                rm(temp_file, force=true)
            end
        end
        
        @testset "Multiple faces" begin
            test_obj_content = """
            v 0.0 0.0 0.0
            v 1.0 0.0 0.0
            v 1.0 1.0 0.0
            v 0.0 1.0 0.0
            f 1 2 3
            f 1 3 4
            """
            
            temp_file = tempname() * ".obj"
            open(temp_file, "w") do io
                write(io, test_obj_content)
            end
            
            try
                nodes, faces = load_obj(temp_file)
                @test length(nodes) == 4
                @test length(faces) == 2
                @test faces[1] == SA[1, 2, 3]
                @test faces[2] == SA[1, 3, 4]
            finally
                rm(temp_file, force=true)
            end
        end
    end
    
    @testset "Invalid OBJ content" begin
        @testset "Malformed vertex" begin
            # Missing coordinate
            test_obj_content = """
            v 1.0 0.0
            v 0.0 1.0 0.0
            v 0.0 0.0 1.0
            f 1 2 3
            """
            
            temp_file = tempname() * ".obj"
            open(temp_file, "w") do io
                write(io, test_obj_content)
            end
            
            try
                # Should throw an error or handle gracefully
                # Redirect stderr to suppress FileIO error messages
                redirect_stderr(devnull) do
                    @test_throws Exception load_obj(temp_file)
                end
            finally
                rm(temp_file, force=true)
            end
        end
        
        @testset "Invalid face indices" begin
            # Face referencing non-existent vertex
            test_obj_content = """
            v 1.0 0.0 0.0
            v 0.0 1.0 0.0
            v 0.0 0.0 1.0
            f 1 2 4
            """
            
            temp_file = tempname() * ".obj"
            open(temp_file, "w") do io
                write(io, test_obj_content)
            end
            
            try
                # This should throw an error because vertex 4 doesn't exist
                # Redirect stderr to suppress FileIO error messages
                redirect_stderr(devnull) do
                    @test_throws Exception load_obj(temp_file)
                end
            finally
                rm(temp_file, force=true)
            end
        end
        
        @testset "Empty file" begin
            temp_file = tempname() * ".obj"
            open(temp_file, "w") do io
                # Empty file
            end
            
            try
                nodes, faces = load_obj(temp_file)
                @test length(nodes) == 0
                @test length(faces) == 0
            finally
                rm(temp_file, force=true)
            end
        end
    end
    
    @testset "Real OBJ files from test directory" begin
        test_dir = joinpath(dirname(@__FILE__), "shape")
        
        if isdir(test_dir)
            # Test only ryugu_test.obj
            obj_file = "ryugu_test.obj"
            filepath = joinpath(test_dir, obj_file)
            
            if isfile(filepath)
                @testset "Loading $obj_file" begin
                    # Test that file can be loaded
                    nodes, faces = load_obj(filepath)
                    
                    # Basic sanity checks
                    @test length(nodes) > 0
                    @test length(faces) > 0
                    
                    # Check validity using helper function
                    validation = validate_shape_model(nodes, faces)
                    @test validation.valid_indices
                    @test validation.valid_dimensions
                    @test validation.all_triangular
                    
                    # Summary information (not a test, just informative)
                    println("  ✓ Loaded $obj_file: $(length(nodes)) vertices, $(length(faces)) faces")
                end
            else
                @warn "Test file not found: $filepath"
            end
        else
            @warn "Test shape directory not found: $test_dir"
        end
    end
end