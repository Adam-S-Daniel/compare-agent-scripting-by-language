# DatabaseSeed.Tests.ps1
# TDD tests for SQLite database seed script
# Using Pester framework - run with: Invoke-Pester

# Ensure Pester is available
#Requires -Version 5.1

BeforeAll {
    # Install PSSQLite module if not present (needed for SQLite support)
    if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
        Write-Host "Installing PSSQLite module..." -ForegroundColor Yellow
        Install-Module -Name PSSQLite -Force -Scope CurrentUser -SkipPublisherCheck
    }

    # Source the main script
    . "$PSScriptRoot/DatabaseSeed.ps1"

    # Test database path - use temp file to isolate tests
    $script:TestDbPath = Join-Path $TestDrive "test_seed.db"
}

AfterAll {
    # Clean up test database
    if (Test-Path $script:TestDbPath) {
        Remove-Item $script:TestDbPath -Force
    }
}

# =============================================================================
# RED/GREEN TDD CYCLE 1: Schema Creation
# =============================================================================

Describe "Schema Creation" {
    BeforeEach {
        # Fresh database for each test
        if (Test-Path $script:TestDbPath) {
            Remove-Item $script:TestDbPath -Force
        }
    }

    It "should create a new SQLite database file" {
        # RED: This test will fail until Initialize-Database is implemented
        Initialize-Database -DbPath $script:TestDbPath
        Test-Path $script:TestDbPath | Should -Be $true
    }

    It "should create the users table with correct columns" {
        Initialize-Database -DbPath $script:TestDbPath
        $tables = Get-TableSchema -DbPath $script:TestDbPath -TableName "users"
        $tables | Should -Not -BeNullOrEmpty
        $colNames = $tables.name
        $colNames | Should -Contain "id"
        $colNames | Should -Contain "username"
        $colNames | Should -Contain "email"
        $colNames | Should -Contain "created_at"
    }

    It "should create the products table with correct columns" {
        Initialize-Database -DbPath $script:TestDbPath
        $tables = Get-TableSchema -DbPath $script:TestDbPath -TableName "products"
        $tables | Should -Not -BeNullOrEmpty
        $colNames = $tables.name
        $colNames | Should -Contain "id"
        $colNames | Should -Contain "name"
        $colNames | Should -Contain "price"
        $colNames | Should -Contain "stock_quantity"
    }

    It "should create the orders table with correct columns" {
        Initialize-Database -DbPath $script:TestDbPath
        $tables = Get-TableSchema -DbPath $script:TestDbPath -TableName "orders"
        $tables | Should -Not -BeNullOrEmpty
        $colNames = $tables.name
        $colNames | Should -Contain "id"
        $colNames | Should -Contain "user_id"
        $colNames | Should -Contain "product_id"
        $colNames | Should -Contain "quantity"
        $colNames | Should -Contain "total_price"
        $colNames | Should -Contain "order_date"
    }

    It "should enforce foreign key constraints on orders table" {
        Initialize-Database -DbPath $script:TestDbPath
        # Use Add-Orders which enables FK enforcement on its connection;
        # referencing non-existent user_id 9999 should throw
        $badOrder = [PSCustomObject]@{
            user_id     = 9999
            product_id  = 9999
            quantity    = 1
            total_price = 9.99
            order_date  = '2024-01-01'
        }
        { Add-Orders -DbPath $script:TestDbPath -Orders @($badOrder) } | Should -Throw
    }
}

# =============================================================================
# RED/GREEN TDD CYCLE 2: Deterministic Data Generation (Seeded RNG)
# =============================================================================

Describe "Deterministic Data Generation" {

    It "should generate the same user data for the same seed" {
        $users1 = New-MockUsers -Count 5 -Seed 42
        $users2 = New-MockUsers -Count 5 -Seed 42
        $users1[0].username | Should -Be $users2[0].username
        $users1[2].email    | Should -Be $users2[2].email
    }

    It "should generate different user data for different seeds" {
        $users1 = New-MockUsers -Count 5 -Seed 1
        $users2 = New-MockUsers -Count 5 -Seed 99
        # Very unlikely (but possible) that first usernames match — check at least one differs
        $anyDifference = $false
        for ($i = 0; $i -lt 5; $i++) {
            if ($users1[$i].username -ne $users2[$i].username) { $anyDifference = $true; break }
        }
        $anyDifference | Should -Be $true
    }

    It "should generate users with required fields" {
        $users = New-MockUsers -Count 3 -Seed 7
        foreach ($u in $users) {
            $u.username  | Should -Not -BeNullOrEmpty
            $u.email     | Should -Not -BeNullOrEmpty
            $u.email     | Should -Match '@'
            $u.full_name | Should -Not -BeNullOrEmpty
        }
    }

    It "should generate the same product data for the same seed" {
        $p1 = New-MockProducts -Count 4 -Seed 42
        $p2 = New-MockProducts -Count 4 -Seed 42
        $p1[0].name  | Should -Be $p2[0].name
        $p1[0].price | Should -Be $p2[0].price
    }

    It "should generate products with valid price and stock" {
        $products = New-MockProducts -Count 5 -Seed 13
        foreach ($p in $products) {
            $p.name           | Should -Not -BeNullOrEmpty
            $p.price          | Should -BeGreaterThan 0
            $p.stock_quantity | Should -BeGreaterOrEqual 0
        }
    }

    It "should generate the same order data for the same seed" {
        $orders1 = New-MockOrders -Count 6 -UserCount 3 -ProductCount 4 -Seed 42
        $orders2 = New-MockOrders -Count 6 -UserCount 3 -ProductCount 4 -Seed 42
        $orders1[0].user_id    | Should -Be $orders2[0].user_id
        $orders1[0].product_id | Should -Be $orders2[0].product_id
    }

    It "should generate orders whose user_id is within valid user range" {
        $userCount    = 5
        $productCount = 4
        $orders = New-MockOrders -Count 10 -UserCount $userCount -ProductCount $productCount -Seed 77
        foreach ($o in $orders) {
            $o.user_id    | Should -BeGreaterOrEqual 1
            $o.user_id    | Should -BeLessOrEqual $userCount
            $o.product_id | Should -BeGreaterOrEqual 1
            $o.product_id | Should -BeLessOrEqual $productCount
            $o.quantity   | Should -BeGreaterThan 0
        }
    }
}

# =============================================================================
# RED/GREEN TDD CYCLE 3: Data Insertion with Referential Integrity
# =============================================================================

Describe "Data Insertion" {
    BeforeEach {
        if (Test-Path $script:TestDbPath) { Remove-Item $script:TestDbPath -Force }
        Initialize-Database -DbPath $script:TestDbPath
    }

    It "should insert users and return correct count" {
        $users = New-MockUsers -Count 10 -Seed 42
        $inserted = Add-Users -DbPath $script:TestDbPath -Users $users
        $inserted | Should -Be 10
        $count = Invoke-SqlScalar -DbPath $script:TestDbPath -Query "SELECT COUNT(*) FROM users"
        $count | Should -Be 10
    }

    It "should insert products and return correct count" {
        $products = New-MockProducts -Count 8 -Seed 42
        $inserted = Add-Products -DbPath $script:TestDbPath -Products $products
        $inserted | Should -Be 8
        $count = Invoke-SqlScalar -DbPath $script:TestDbPath -Query "SELECT COUNT(*) FROM products"
        $count | Should -Be 8
    }

    It "should insert orders respecting foreign key constraints" {
        $users    = New-MockUsers    -Count 5  -Seed 42
        $products = New-MockProducts -Count 5  -Seed 42
        Add-Users    -DbPath $script:TestDbPath -Users    $users
        Add-Products -DbPath $script:TestDbPath -Products $products

        $orders = New-MockOrders -Count 15 -UserCount 5 -ProductCount 5 -Seed 42
        $inserted = Add-Orders -DbPath $script:TestDbPath -Orders $orders
        $inserted | Should -Be 15

        $count = Invoke-SqlScalar -DbPath $script:TestDbPath -Query "SELECT COUNT(*) FROM orders"
        $count | Should -Be 15
    }

    It "should seed the full database in one call" {
        $result = Invoke-DatabaseSeed -DbPath $script:TestDbPath -UserCount 10 -ProductCount 10 -OrderCount 20 -Seed 42
        $result.UsersInserted    | Should -Be 10
        $result.ProductsInserted | Should -Be 10
        $result.OrdersInserted   | Should -Be 20
    }

    It "should produce identical data when seeded twice" {
        $db1 = Join-Path $TestDrive "seed1.db"
        $db2 = Join-Path $TestDrive "seed2.db"

        Invoke-DatabaseSeed -DbPath $db1 -UserCount 5 -ProductCount 5 -OrderCount 10 -Seed 99
        Invoke-DatabaseSeed -DbPath $db2 -UserCount 5 -ProductCount 5 -OrderCount 10 -Seed 99

        $users1 = Invoke-SqlQuery -DbPath $db1 -Query "SELECT username FROM users ORDER BY id"
        $users2 = Invoke-SqlQuery -DbPath $db2 -Query "SELECT username FROM users ORDER BY id"
        $users1[0].username | Should -Be $users2[0].username
    }
}

# =============================================================================
# RED/GREEN TDD CYCLE 4: Verification Queries (Data Consistency)
# =============================================================================

Describe "Verification Queries" {
    BeforeAll {
        # Seed once for all verification tests
        $script:VerifyDbPath = Join-Path $TestDrive "verify.db"
        Invoke-DatabaseSeed -DbPath $script:VerifyDbPath -UserCount 10 -ProductCount 10 -OrderCount 25 -Seed 42
    }

    It "should have no orphaned orders (all user_ids exist in users)" {
        $orphans = Invoke-SqlScalar -DbPath $script:VerifyDbPath -Query @"
            SELECT COUNT(*) FROM orders o
            LEFT JOIN users u ON o.user_id = u.id
            WHERE u.id IS NULL
"@
        $orphans | Should -Be 0
    }

    It "should have no orphaned orders (all product_ids exist in products)" {
        $orphans = Invoke-SqlScalar -DbPath $script:VerifyDbPath -Query @"
            SELECT COUNT(*) FROM orders o
            LEFT JOIN products p ON o.product_id = p.id
            WHERE p.id IS NULL
"@
        $orphans | Should -Be 0
    }

    It "should have unique emails in users table" {
        $duplicates = Invoke-SqlScalar -DbPath $script:VerifyDbPath -Query @"
            SELECT COUNT(*) FROM (
                SELECT email FROM users GROUP BY email HAVING COUNT(*) > 1
            )
"@
        $duplicates | Should -Be 0
    }

    It "should have unique usernames in users table" {
        $duplicates = Invoke-SqlScalar -DbPath $script:VerifyDbPath -Query @"
            SELECT COUNT(*) FROM (
                SELECT username FROM users GROUP BY username HAVING COUNT(*) > 1
            )
"@
        $duplicates | Should -Be 0
    }

    It "should have orders with positive total_price" {
        $badOrders = Invoke-SqlScalar -DbPath $script:VerifyDbPath -Query @"
            SELECT COUNT(*) FROM orders WHERE total_price <= 0
"@
        $badOrders | Should -Be 0
    }

    It "should have orders with positive quantity" {
        $badOrders = Invoke-SqlScalar -DbPath $script:VerifyDbPath -Query @"
            SELECT COUNT(*) FROM orders WHERE quantity <= 0
"@
        $badOrders | Should -Be 0
    }

    It "should return correct order totals per user" {
        $results = Test-OrderTotalsConsistency -DbPath $script:VerifyDbPath
        $results.IsConsistent | Should -Be $true
    }

    It "should return user order summary with correct structure" {
        $summary = Get-UserOrderSummary -DbPath $script:VerifyDbPath
        $summary | Should -Not -BeNullOrEmpty
        $summary[0].PSObject.Properties.Name | Should -Contain "username"
        $summary[0].PSObject.Properties.Name | Should -Contain "order_count"
        $summary[0].PSObject.Properties.Name | Should -Contain "total_spent"
    }

    It "should return product sales summary with correct structure" {
        $summary = Get-ProductSalesSummary -DbPath $script:VerifyDbPath
        $summary | Should -Not -BeNullOrEmpty
        $summary[0].PSObject.Properties.Name | Should -Contain "product_name"
        $summary[0].PSObject.Properties.Name | Should -Contain "times_ordered"
        $summary[0].PSObject.Properties.Name | Should -Contain "total_revenue"
    }

    It "should pass all verification checks in one call" {
        $report = Invoke-VerificationSuite -DbPath $script:VerifyDbPath
        $report.AllPassed | Should -Be $true
        $report.Checks    | Should -Not -BeNullOrEmpty
    }
}
