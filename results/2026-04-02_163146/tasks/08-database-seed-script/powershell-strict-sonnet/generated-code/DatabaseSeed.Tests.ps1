# DatabaseSeed.Tests.ps1
# TDD test suite for SQLite database seed script
# RED/GREEN cycle: tests are written first, implementation follows

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Bootstrap: ensure Pester 5 and PSSQLite are available
# ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { [version]$_.Version -ge [version]'5.0.0' })) {
    Write-Host 'Installing Pester 5...'
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck
}

if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
    Write-Host 'Installing PSSQLite...'
    Install-Module -Name PSSQLite -Force -Scope CurrentUser
}

Import-Module Pester   -MinimumVersion 5.0.0 -Force
Import-Module PSSQLite -Force

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
[string]$script:ModulePath = Join-Path $PSScriptRoot 'DatabaseSeed.psm1'

function New-TestDatabasePath {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    return Join-Path ([System.IO.Path]::GetTempPath()) "test_seed_$([System.Guid]::NewGuid().ToString('N')).db"
}

# ===========================================================================
# PESTER SUITE
# ===========================================================================
Describe 'DatabaseSeed Module' {

    BeforeAll {
        # RED → GREEN: module must exist before this passes
        Import-Module $script:ModulePath -Force
    }

    # -----------------------------------------------------------------------
    # Stage 1 – Module structure (RED: module file missing → GREEN: created)
    # -----------------------------------------------------------------------
    Context 'Module exports the required functions' {

        It 'exports Initialize-DatabaseSchema' {
            Get-Command -Module DatabaseSeed -Name Initialize-DatabaseSchema |
                Should -Not -BeNullOrEmpty
        }

        It 'exports New-MockUsers' {
            Get-Command -Module DatabaseSeed -Name New-MockUsers |
                Should -Not -BeNullOrEmpty
        }

        It 'exports New-MockProducts' {
            Get-Command -Module DatabaseSeed -Name New-MockProducts |
                Should -Not -BeNullOrEmpty
        }

        It 'exports New-MockOrders' {
            Get-Command -Module DatabaseSeed -Name New-MockOrders |
                Should -Not -BeNullOrEmpty
        }

        It 'exports Import-SeedData' {
            Get-Command -Module DatabaseSeed -Name Import-SeedData |
                Should -Not -BeNullOrEmpty
        }

        It 'exports Invoke-VerificationQueries' {
            Get-Command -Module DatabaseSeed -Name Invoke-VerificationQueries |
                Should -Not -BeNullOrEmpty
        }
    }

    # -----------------------------------------------------------------------
    # Stage 2 – Schema creation
    # (RED: function missing → GREEN: tables created correctly)
    # -----------------------------------------------------------------------
    Context 'Initialize-DatabaseSchema' {

        BeforeEach {
            $dbPath = New-TestDatabasePath
        }

        AfterEach {
            if (Test-Path $dbPath) { Remove-Item $dbPath -Force }
        }

        It 'creates the users table' {
            Initialize-DatabaseSchema -DatabasePath $dbPath

            [array]$rows = Invoke-SqliteQuery -DataSource $dbPath `
                -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
            $rows.Count | Should -Be 1
        }

        It 'creates the products table' {
            Initialize-DatabaseSchema -DatabasePath $dbPath

            [array]$rows = Invoke-SqliteQuery -DataSource $dbPath `
                -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='products'"
            $rows.Count | Should -Be 1
        }

        It 'creates the orders table' {
            Initialize-DatabaseSchema -DatabasePath $dbPath

            [array]$rows = Invoke-SqliteQuery -DataSource $dbPath `
                -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='orders'"
            $rows.Count | Should -Be 1
        }

        It 'users table has required columns' {
            Initialize-DatabaseSchema -DatabasePath $dbPath

            [array]$cols = Invoke-SqliteQuery -DataSource $dbPath `
                -Query 'PRAGMA table_info(users)'
            [string[]]$names = $cols | ForEach-Object { [string]$_.name }
            $names | Should -Contain 'id'
            $names | Should -Contain 'username'
            $names | Should -Contain 'email'
            $names | Should -Contain 'full_name'
            $names | Should -Contain 'created_at'
            $names | Should -Contain 'is_active'
        }

        It 'products table has required columns' {
            Initialize-DatabaseSchema -DatabasePath $dbPath

            [array]$cols = Invoke-SqliteQuery -DataSource $dbPath `
                -Query 'PRAGMA table_info(products)'
            [string[]]$names = $cols | ForEach-Object { [string]$_.name }
            $names | Should -Contain 'id'
            $names | Should -Contain 'name'
            $names | Should -Contain 'description'
            $names | Should -Contain 'price'
            $names | Should -Contain 'stock_quantity'
            $names | Should -Contain 'category'
            $names | Should -Contain 'created_at'
        }

        It 'orders table has required columns with FK references' {
            Initialize-DatabaseSchema -DatabasePath $dbPath

            [array]$cols = Invoke-SqliteQuery -DataSource $dbPath `
                -Query 'PRAGMA table_info(orders)'
            [string[]]$names = $cols | ForEach-Object { [string]$_.name }
            $names | Should -Contain 'id'
            $names | Should -Contain 'user_id'
            $names | Should -Contain 'product_id'
            $names | Should -Contain 'quantity'
            $names | Should -Contain 'unit_price'
            $names | Should -Contain 'total_price'
            $names | Should -Contain 'status'
            $names | Should -Contain 'order_date'
        }

        It 'orders table declares foreign keys to users and products' {
            Initialize-DatabaseSchema -DatabasePath $dbPath

            [array]$fks = Invoke-SqliteQuery -DataSource $dbPath `
                -Query 'PRAGMA foreign_key_list(orders)'
            [string[]]$tables = $fks | ForEach-Object { [string]$_.table }
            $tables | Should -Contain 'users'
            $tables | Should -Contain 'products'
        }

        It 'is idempotent — running twice does not throw' {
            { Initialize-DatabaseSchema -DatabasePath $dbPath } | Should -Not -Throw
            { Initialize-DatabaseSchema -DatabasePath $dbPath } | Should -Not -Throw
        }
    }

    # -----------------------------------------------------------------------
    # Stage 3 – Mock data generation (deterministic / seeded)
    # (RED: functions missing → GREEN: return consistent data)
    # -----------------------------------------------------------------------
    Context 'New-MockUsers' {

        It 'returns the requested number of users' {
            [array]$users = New-MockUsers -Count 10 -Seed 42
            $users.Count | Should -Be 10
        }

        It 'each user has the required fields' {
            [array]$users = New-MockUsers -Count 5 -Seed 1
            foreach ($u in $users) {
                $u.username   | Should -Not -BeNullOrEmpty
                $u.email      | Should -Not -BeNullOrEmpty
                $u.full_name  | Should -Not -BeNullOrEmpty
                $u.created_at | Should -Not -BeNullOrEmpty
                $u.is_active  | Should -BeIn @(0, 1)
            }
        }

        It 'produces deterministic output with the same seed' {
            [array]$first  = New-MockUsers -Count 5 -Seed 99
            [array]$second = New-MockUsers -Count 5 -Seed 99
            $first[0].username | Should -Be $second[0].username
            $first[0].email    | Should -Be $second[0].email
        }

        It 'produces different output with different seeds' {
            [array]$a = New-MockUsers -Count 5 -Seed 1
            [array]$b = New-MockUsers -Count 5 -Seed 2
            # Extremely unlikely all usernames match under different seeds
            $a[0].username | Should -Not -Be $b[0].username
        }

        It 'usernames are unique within a batch' {
            [array]$users = New-MockUsers -Count 20 -Seed 7
            [string[]]$names = $users | ForEach-Object { [string]$_.username }
            $names.Count | Should -Be ($names | Select-Object -Unique).Count
        }

        It 'email addresses contain an @ sign' {
            [array]$users = New-MockUsers -Count 5 -Seed 3
            foreach ($u in $users) {
                $u.email | Should -Match '@'
            }
        }
    }

    Context 'New-MockProducts' {

        It 'returns the requested number of products' {
            [array]$products = New-MockProducts -Count 15 -Seed 42
            $products.Count | Should -Be 15
        }

        It 'each product has the required fields' {
            [array]$products = New-MockProducts -Count 3 -Seed 5
            foreach ($p in $products) {
                $p.name           | Should -Not -BeNullOrEmpty
                $p.price          | Should -BeGreaterThan 0
                $p.stock_quantity | Should -BeGreaterOrEqual 0
                $p.category       | Should -Not -BeNullOrEmpty
                $p.created_at     | Should -Not -BeNullOrEmpty
            }
        }

        It 'produces deterministic output with the same seed' {
            [array]$first  = New-MockProducts -Count 5 -Seed 55
            [array]$second = New-MockProducts -Count 5 -Seed 55
            $first[0].name  | Should -Be $second[0].name
            $first[0].price | Should -Be $second[0].price
        }
    }

    Context 'New-MockOrders' {

        It 'returns the requested number of orders' {
            [int[]]$userIds    = 1..5
            [int[]]$productIds = 1..10
            [array]$orders = New-MockOrders -Count 20 -Seed 42 -UserIds $userIds -ProductIds $productIds
            $orders.Count | Should -Be 20
        }

        It 'each order references valid user and product ids' {
            [int[]]$userIds    = 1..3
            [int[]]$productIds = 1..5
            [array]$orders = New-MockOrders -Count 10 -Seed 10 -UserIds $userIds -ProductIds $productIds
            foreach ($o in $orders) {
                $o.user_id    | Should -BeIn $userIds
                $o.product_id | Should -BeIn $productIds
            }
        }

        It 'total_price equals quantity multiplied by unit_price' {
            [int[]]$userIds    = 1..3
            [int[]]$productIds = 1..5
            [array]$orders = New-MockOrders -Count 10 -Seed 10 -UserIds $userIds -ProductIds $productIds
            foreach ($o in $orders) {
                [double]$expected = [double]$o.quantity * [double]$o.unit_price
                [double]$o.total_price | Should -BeApproximately $expected 0.01
            }
        }

        It 'status is one of the allowed values' {
            [int[]]$userIds    = 1..3
            [int[]]$productIds = 1..5
            [array]$orders = New-MockOrders -Count 20 -Seed 10 -UserIds $userIds -ProductIds $productIds
            [string[]]$allowed = @('pending', 'processing', 'shipped', 'delivered', 'cancelled')
            foreach ($o in $orders) {
                $o.status | Should -BeIn $allowed
            }
        }

        It 'produces deterministic output with the same seed' {
            [int[]]$userIds    = 1..5
            [int[]]$productIds = 1..10
            [array]$first  = New-MockOrders -Count 5 -Seed 77 -UserIds $userIds -ProductIds $productIds
            [array]$second = New-MockOrders -Count 5 -Seed 77 -UserIds $userIds -ProductIds $productIds
            $first[0].user_id    | Should -Be $second[0].user_id
            $first[0].product_id | Should -Be $second[0].product_id
            $first[0].quantity   | Should -Be $second[0].quantity
        }
    }

    # -----------------------------------------------------------------------
    # Stage 4 – Data insertion (respects referential integrity)
    # (RED: import missing → GREEN: rows inserted correctly)
    # -----------------------------------------------------------------------
    Context 'Import-SeedData' {

        BeforeEach {
            $dbPath = New-TestDatabasePath
            Initialize-DatabaseSchema -DatabasePath $dbPath
        }

        AfterEach {
            if (Test-Path $dbPath) { Remove-Item $dbPath -Force }
        }

        It 'inserts the specified number of users' {
            Import-SeedData -DatabasePath $dbPath -UserCount 10 -ProductCount 5 -OrderCount 20 -Seed 42

            [array]$rows = Invoke-SqliteQuery -DataSource $dbPath -Query 'SELECT COUNT(*) AS cnt FROM users'
            [int]$rows[0].cnt | Should -Be 10
        }

        It 'inserts the specified number of products' {
            Import-SeedData -DatabasePath $dbPath -UserCount 5 -ProductCount 8 -OrderCount 15 -Seed 42

            [array]$rows = Invoke-SqliteQuery -DataSource $dbPath -Query 'SELECT COUNT(*) AS cnt FROM products'
            [int]$rows[0].cnt | Should -Be 8
        }

        It 'inserts the specified number of orders' {
            Import-SeedData -DatabasePath $dbPath -UserCount 5 -ProductCount 8 -OrderCount 15 -Seed 42

            [array]$rows = Invoke-SqliteQuery -DataSource $dbPath -Query 'SELECT COUNT(*) AS cnt FROM orders'
            [int]$rows[0].cnt | Should -Be 15
        }

        It 'all order user_id values reference existing users' {
            Import-SeedData -DatabasePath $dbPath -UserCount 5 -ProductCount 5 -OrderCount 20 -Seed 1

            [array]$orphans = Invoke-SqliteQuery -DataSource $dbPath -Query @'
SELECT COUNT(*) AS cnt
FROM   orders o
WHERE  NOT EXISTS (SELECT 1 FROM users u WHERE u.id = o.user_id)
'@
            [int]$orphans[0].cnt | Should -Be 0
        }

        It 'all order product_id values reference existing products' {
            Import-SeedData -DatabasePath $dbPath -UserCount 5 -ProductCount 5 -OrderCount 20 -Seed 1

            [array]$orphans = Invoke-SqliteQuery -DataSource $dbPath -Query @'
SELECT COUNT(*) AS cnt
FROM   orders o
WHERE  NOT EXISTS (SELECT 1 FROM products p WHERE p.id = o.product_id)
'@
            [int]$orphans[0].cnt | Should -Be 0
        }

        It 'total_price in database matches quantity * unit_price' {
            Import-SeedData -DatabasePath $dbPath -UserCount 5 -ProductCount 5 -OrderCount 10 -Seed 2

            [array]$mismatches = Invoke-SqliteQuery -DataSource $dbPath -Query @'
SELECT COUNT(*) AS cnt
FROM   orders
WHERE  ABS(total_price - (quantity * unit_price)) > 0.01
'@
            [int]$mismatches[0].cnt | Should -Be 0
        }
    }

    # -----------------------------------------------------------------------
    # Stage 5 – Verification queries
    # (RED: function missing → GREEN: returns structured results)
    # -----------------------------------------------------------------------
    Context 'Invoke-VerificationQueries' {

        BeforeAll {
            $dbPath = New-TestDatabasePath
            Initialize-DatabaseSchema -DatabasePath $dbPath
            Import-SeedData -DatabasePath $dbPath -UserCount 20 -ProductCount 10 -OrderCount 50 -Seed 42
        }

        AfterAll {
            if (Test-Path $dbPath) { Remove-Item $dbPath -Force }
        }

        It 'returns a result object (non-null)' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result | Should -Not -BeNullOrEmpty
        }

        It 'result contains UserCount' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.UserCount | Should -BeGreaterThan 0
        }

        It 'result contains ProductCount' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.ProductCount | Should -BeGreaterThan 0
        }

        It 'result contains OrderCount' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.OrderCount | Should -BeGreaterThan 0
        }

        It 'result reports zero orphaned orders' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.OrphanedOrders | Should -Be 0
        }

        It 'result reports zero price calculation errors' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.PriceErrors | Should -Be 0
        }

        It 'result contains top spenders list' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.TopSpenders | Should -Not -BeNullOrEmpty
        }

        It 'result contains revenue by category list' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.RevenueByCategory | Should -Not -BeNullOrEmpty
        }

        It 'result contains active user percentage' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.ActiveUserPct | Should -BeGreaterOrEqual 0
            $result.ActiveUserPct | Should -BeLessOrEqual 100
        }

        It 'UserCount matches what was seeded' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.UserCount | Should -Be 20
        }

        It 'ProductCount matches what was seeded' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.ProductCount | Should -Be 10
        }

        It 'OrderCount matches what was seeded' {
            $result = Invoke-VerificationQueries -DatabasePath $dbPath
            $result.OrderCount | Should -Be 50
        }
    }
}
