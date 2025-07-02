# Contributing to AsteroidShapeModels.jl

Thank you for your interest in contributing to AsteroidShapeModels.jl! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Documentation](#documentation)
- [Getting Help](#getting-help)

## Code of Conduct

By participating in this project, you agree to abide by our code of conduct: be respectful, inclusive, and constructive in all interactions.

## Getting Started

### Prerequisites

- Julia 1.10 or later
- Git
- GitHub account

### Setting Up Your Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/AsteroidShapeModels.jl.git
   cd AsteroidShapeModels.jl
   ```

3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/Astroshaper/AsteroidShapeModels.jl.git
   ```

4. Install dependencies:
   ```julia
   julia> ]
   pkg> activate .
   pkg> instantiate
   ```

## Development Process

### Check the Roadmap

Before starting work on a new feature, please check our [Development Roadmap](ROADMAP.md) to understand the project's direction and priorities.

### Create an Issue First

For significant changes, please create an issue first to discuss your proposal. This helps ensure your contribution aligns with the project's goals.

### Work on a Feature Branch

Always work on a feature branch:
```bash
git checkout -b feature/your-feature-name
```

## Making Changes

### Code Style

- Follow Julia's official [style guide](https://docs.julialang.org/en/v1/manual/style-guide/)
- Use 4 spaces for indentation (no tabs)
- Keep line length under 120 characters when possible
- Use descriptive variable names
- Add docstrings to all exported functions

### Documentation

- Add docstrings following Julia's documentation standards
- Update relevant documentation in `docs/` if needed
- Include examples in docstrings where appropriate

### Performance Considerations

- This package is performance-critical for asteroid analysis
- Consider memory allocations and type stability
- Add benchmarks for performance-critical changes

## Testing

### Running Tests

Run the test suite before submitting:
```julia
julia> ]
pkg> test
```

### Writing Tests

- Add tests for new functionality
- Ensure all tests pass locally before submitting
- Test edge cases and error conditions
- Place tests in appropriate files under `test/`

### Benchmarking

For performance-related changes:
```julia
julia> ]
pkg> activate benchmark
pkg> instantiate
julia> include("benchmark/benchmarks.jl")
```

## Submitting Changes

### Commit Messages

Follow these conventions for commit messages:
- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Keep the first line under 50 characters
- Reference issues and PRs when relevant

Example:
```
Add BVH acceleration for ray tracing

- Implement ImplicitBVH integration
- Add batch ray processing capability
- Update documentation with performance comparisons

Fixes #123
```

### Pull Request Process

1. Update your fork with the latest upstream changes:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. Push your changes to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

3. Create a Pull Request on GitHub with:
   - Clear title and description
   - Reference to any related issues
   - Summary of changes
   - Test results (if applicable)

4. Ensure all CI checks pass

5. Address review feedback promptly

### Pull Request Checklist

- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] PR description explains the changes
- [ ] Related issues are referenced

## Coding Standards

### Type Annotations

- Use type annotations for function arguments where it improves clarity
- Ensure type stability for performance-critical functions

### Error Handling

- Use descriptive error messages
- Validate inputs appropriately
- Document error conditions in docstrings

### Exports

- Only export functions that are part of the public API
- Document all exported functions thoroughly

## Documentation

### Docstring Format

```julia
"""
    function_name(arg1::Type1, arg2::Type2) -> ReturnType

Brief description of what the function does.

# Arguments
- `arg1`: Description of first argument
- `arg2`: Description of second argument

# Returns
- Description of return value

# Examples
```julia
result = function_name(value1, value2)
```

# Notes
Any additional information or caveats.
"""
```

### Documentation Updates

- Update `docs/src/` for API changes
- Update examples in `README.md` if needed
- Keep the changelog updated

## Getting Help

If you need help:

1. Check existing issues and discussions
2. Create a new issue with your question
3. Use the "question" label for general inquiries

## Recognition

Contributors will be acknowledged in:
- The project's contributors list
- Release notes for significant contributions

Thank you for contributing to AsteroidShapeModels.jl!