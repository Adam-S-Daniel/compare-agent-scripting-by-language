# Test fixture: minor version bump from feat commits
@{
    Name            = "Minor Bump"
    InitialVersion  = "1.1.0"
    ExpectedVersion = "1.2.0"
    ExpectedBump    = "minor"
    Commits         = @(
        "feat: add user authentication"
        "fix: resolve login redirect issue"
    )
}
