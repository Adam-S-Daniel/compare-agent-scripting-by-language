# Test fixture: patch version bump from fix commits
@{
    Name            = "Patch Bump"
    InitialVersion  = "1.0.0"
    ExpectedVersion = "1.0.1"
    ExpectedBump    = "patch"
    Commits         = @(
        "fix: correct null pointer in parser"
        "fix(api): handle timeout errors gracefully"
    )
}
