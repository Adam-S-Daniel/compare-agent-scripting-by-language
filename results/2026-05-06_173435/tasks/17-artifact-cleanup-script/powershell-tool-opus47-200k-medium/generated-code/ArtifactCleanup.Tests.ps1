# Pester tests for ArtifactCleanup.ps1.
# Built up red/green: each Describe block was written before its function
# existed. Tests cover individual policies, combined policies, dry-run, and
# fixture-driven end-to-end behavior.

BeforeAll {
    . "$PSScriptRoot/ArtifactCleanup.ps1"

    function New-Artifact {
        param([string]$Name, [long]$Size, [string]$CreatedAt, [string]$WorkflowRunId)
        [PSCustomObject]@{
            Name = $Name; Size = $Size
            CreatedAt = [DateTime]::Parse($CreatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
            WorkflowRunId = $WorkflowRunId
        }
    }

    $script:Now = [DateTime]::Parse('2026-05-08T00:00:00Z', $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
    $script:Sample = @(
        (New-Artifact -Name 'a-old'    -Size 100 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'wf1')
        (New-Artifact -Name 'a-mid'    -Size 200 -CreatedAt '2026-04-01T00:00:00Z' -WorkflowRunId 'wf1')
        (New-Artifact -Name 'a-new'    -Size 300 -CreatedAt '2026-05-07T00:00:00Z' -WorkflowRunId 'wf1')
        (New-Artifact -Name 'b-old'    -Size 400 -CreatedAt '2026-02-01T00:00:00Z' -WorkflowRunId 'wf2')
        (New-Artifact -Name 'b-new'    -Size 500 -CreatedAt '2026-05-06T00:00:00Z' -WorkflowRunId 'wf2')
    )
}

Describe 'Get-ArtifactsToDelete' {
    It 'returns nothing when no policies set' {
        $r = Get-ArtifactsToDelete -Artifacts $script:Sample -Now $script:Now
        $r.Count | Should -Be 0
    }

    It 'deletes artifacts older than MaxAgeDays' {
        $r = Get-ArtifactsToDelete -Artifacts $script:Sample -MaxAgeDays 30 -Now $script:Now
        ($r | ForEach-Object Name) | Should -Be @('a-old','a-mid','b-old')
    }

    It 'keeps only N latest per workflow' {
        $r = Get-ArtifactsToDelete -Artifacts $script:Sample -KeepLatestPerWorkflow 1 -Now $script:Now
        $names = $r | ForEach-Object Name | Sort-Object
        $names | Should -Be @('a-mid','a-old','b-old')
    }

    It 'enforces total-size cap by deleting oldest first' {
        # Survivors sorted newest->oldest: a-new(300), b-new(500), b-old(400), a-mid(200), a-old(100)
        # Cap at 800 keeps a-new+b-new (=800), deletes the rest.
        $r = Get-ArtifactsToDelete -Artifacts $script:Sample -MaxTotalBytes 800 -Now $script:Now
        ($r | ForEach-Object Name | Sort-Object) | Should -Be @('a-mid','a-old','b-old')
    }

    It 'unions multiple policies' {
        $r = Get-ArtifactsToDelete -Artifacts $script:Sample -MaxAgeDays 30 -KeepLatestPerWorkflow 1 -Now $script:Now
        ($r | ForEach-Object Name | Sort-Object) | Should -Be @('a-mid','a-old','b-old')
    }

    It 'throws on missing required property' {
        $bad = @([PSCustomObject]@{ Name='x'; Size=1; CreatedAt=$script:Now })
        { Get-ArtifactsToDelete -Artifacts $bad -Now $script:Now } | Should -Throw '*WorkflowRunId*'
    }

    It 'throws on negative size' {
        $bad = @([PSCustomObject]@{ Name='x'; Size=-1; CreatedAt=$script:Now; WorkflowRunId='wf' })
        { Get-ArtifactsToDelete -Artifacts $bad -Now $script:Now } | Should -Throw '*negative*'
    }
}

Describe 'New-DeletionPlan' {
    It 'computes summary and reclaimed bytes' {
        $plan = New-DeletionPlan -Artifacts $script:Sample -MaxAgeDays 30 -Now $script:Now
        $plan.TotalArtifacts | Should -Be 5
        $plan.DeletedCount   | Should -Be 3
        $plan.RetainedCount  | Should -Be 2
        $plan.BytesReclaimed | Should -Be 700  # 100+200+400
        $plan.DryRun         | Should -BeFalse
    }

    It 'preserves DryRun flag' {
        $plan = New-DeletionPlan -Artifacts $script:Sample -MaxAgeDays 30 -DryRun -Now $script:Now
        $plan.DryRun | Should -BeTrue
    }
}

Describe 'Format-PlanSummary' {
    It 'includes mode and counts' {
        $plan = New-DeletionPlan -Artifacts $script:Sample -MaxAgeDays 30 -DryRun -Now $script:Now
        $text = Format-PlanSummary -Plan $plan
        $text | Should -Match 'Mode: DRY-RUN'
        $text | Should -Match 'Bytes reclaimed: 700'
        $text | Should -Match 'DELETE: a-old'
        $text | Should -Match 'KEEP:   a-new'
    }
}

Describe 'Invoke-ArtifactCleanup (fixture-driven)' {
    BeforeAll {
        $script:FixturePath = Join-Path $TestDrive 'fixture.json'
        $data = $script:Sample | ForEach-Object {
            [PSCustomObject]@{
                Name          = $_.Name
                Size          = $_.Size
                CreatedAt     = $_.CreatedAt.ToString('o')
                WorkflowRunId = $_.WorkflowRunId
            }
        }
        $data | ConvertTo-Json | Set-Content -Path $script:FixturePath
    }

    It 'reads fixture and produces the expected plan' {
        $plan = Invoke-ArtifactCleanup -FixturePath $script:FixturePath -MaxAgeDays 30 -Now $script:Now -DryRun 6>$null
        $plan.DeletedCount   | Should -Be 3
        $plan.BytesReclaimed | Should -Be 700
    }

    It 'errors clearly when fixture missing' {
        { Invoke-ArtifactCleanup -FixturePath (Join-Path $TestDrive 'missing.json') -MaxAgeDays 1 -Now $script:Now } |
            Should -Throw '*not found*'
    }
}
