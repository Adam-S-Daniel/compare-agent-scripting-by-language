# Test fixture: major version bump from breaking change commits
@{
    Name            = "Major Bump"
    InitialVersion  = "2.0.0"
    ExpectedVersion = "3.0.0"
    ExpectedBump    = "major"
    Commits         = @(
        "feat!: redesign API response format"
        "feat: add new search endpoint"
        "fix: correct pagination logic"
    )
}
