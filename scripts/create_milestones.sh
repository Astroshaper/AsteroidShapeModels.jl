#!/bin/bash
# Script to create GitHub milestones for AsteroidShapeModels.jl
# This script uses the GitHub CLI (gh) to create milestones

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Creating GitHub Milestones for AsteroidShapeModels.jl${NC}"
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it first:"
    echo "https://cli.github.com/"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "This script must be run from within the git repository."
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo -e "Repository: ${YELLOW}$REPO${NC}"
echo ""

# Create milestones
echo "Creating milestone: v0.4.0 - BVH Integration and Optimization"
gh api repos/$REPO/milestones \
  --method POST \
  -f title="v0.4.0 - BVH Integration and Optimization" \
  -f description="Full integration of ImplicitBVH.jl with breaking changes. Target: July 2025" \
  -f due_on="2025-07-31T23:59:59Z" \
  -f state="open" || echo "Milestone v0.4.0 might already exist"

echo ""
echo "Creating milestone: v0.5.0 - Advanced Surface Modeling"
gh api repos/$REPO/milestones \
  --method POST \
  -f title="v0.5.0 - Advanced Surface Modeling" \
  -f description="Hierarchical surface roughness model and performance enhancements. Target: August 2025" \
  -f due_on="2025-08-31T23:59:59Z" \
  -f state="open" || echo "Milestone v0.5.0 might already exist"

echo ""
echo "Creating milestone: v0.6.0 - High-Performance Computing Support"
gh api repos/$REPO/milestones \
  --method POST \
  -f title="v0.6.0 - High-Performance Computing Support" \
  -f description="GPU acceleration and advanced parallelization. Target: October 2025" \
  -f due_on="2025-10-31T23:59:59Z" \
  -f state="open" || echo "Milestone v0.6.0 might already exist"

echo ""
echo -e "${GREEN}Milestones creation complete!${NC}"
echo ""
echo "You can view the milestones at: https://github.com/$REPO/milestones"