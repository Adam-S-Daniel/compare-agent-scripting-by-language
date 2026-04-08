# DatabaseSeed.Tests.ps1 - TDD tests for SQLite database seed script
# Uses Pester 5 for testing, Microsoft.Data.Sqlite for database access
# Approach: Red/Green/Refactor - each Describe block was written as a failing test first,
# then implementation code was added to make it pass.

BeforeAll {
    # Load the module under test
    . "$PSScriptRoot/DatabaseSeed.ps1"
}

# ---------------------------------------------------------------------------
# TDD CYCLE 1: Schema creation
# RED: These tests fail because DatabaseSeed.ps1 doesn't exist yet
# ---------------------------------------------------------------------------
Describe "Schema Creation" {
    BeforeAll {
        # Create a fresh in-memory database for schema tests
        $script:conn = New-SqliteConnection -DataSource ":memory:"
        Initialize-Schema -Connection $script:conn
    }

    AfterAll {
        if ($script:conn) { $script:conn.Close(); $script:conn.Dispose() }
    }

    It "Should create the users table" {
        $tables = Get-TableNames -Connection $script:conn
        $tables | Should -Contain "users"
    }

    It "Should create the products table" {
        $tables = Get-TableNames -Connection $script:conn
        $tables | Should -Contain "products"
    }

    It "Should create the orders table" {
        $tables = Get-TableNames -Connection $script:conn
        $tables | Should -Contain "orders"
    }

    It "Should have correct columns on users table" {
        $columns = Get-ColumnNames -Connection $script:conn -TableName "users"
        $columns | Should -Contain "id"
        $columns | Should -Contain "name"
        $columns | Should -Contain "email"
        $columns | Should -Contain "created_at"
    }

    It "Should have correct columns on products table" {
        $columns = Get-ColumnNames -Connection $script:conn -TableName "products"
        $columns | Should -Contain "id"
        $columns | Should -Contain "name"
        $columns | Should -Contain "price"
        $columns | Should -Contain "category"
    }

    It "Should have correct columns on orders table" {
        $columns = Get-ColumnNames -Connection $script:conn -TableName "orders"
        $columns | Should -Contain "id"
        $columns | Should -Contain "user_id"
        $columns | Should -Contain "product_id"
        $columns | Should -Contain "quantity"
        $columns | Should -Contain "order_date"
    }

    It "Should enforce foreign keys on orders.user_id" {
        $fkeys = Get-ForeignKeys -Connection $script:conn -TableName "orders"
        $fkeys | Where-Object { $_.from -eq "user_id" -and $_.table -eq "users" } | Should -Not -BeNullOrEmpty
    }

    It "Should enforce foreign keys on orders.product_id" {
        $fkeys = Get-ForeignKeys -Connection $script:conn -TableName "orders"
        $fkeys | Where-Object { $_.from -eq "product_id" -and $_.table -eq "products" } | Should -Not -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# TDD CYCLE 2: Deterministic data generation
# RED: Verify that seeded RNG produces identical data across runs
# ---------------------------------------------------------------------------
Describe "Deterministic Data Generation" {
    It "Should generate the same users with the same seed" {
        $rng1 = New-Object System.Random(42)
        $rng2 = New-Object System.Random(42)
        $users1 = New-MockUsers -Rng $rng1 -Count 10
        $users2 = New-MockUsers -Rng $rng2 -Count 10
        for ($i = 0; $i -lt 10; $i++) {
            $users1[$i].Name  | Should -BeExactly $users2[$i].Name
            $users1[$i].Email | Should -BeExactly $users2[$i].Email
        }
    }

    It "Should generate the same products with the same seed" {
        $rng1 = New-Object System.Random(99)
        $rng2 = New-Object System.Random(99)
        $products1 = New-MockProducts -Rng $rng1 -Count 10
        $products2 = New-MockProducts -Rng $rng2 -Count 10
        for ($i = 0; $i -lt 10; $i++) {
            $products1[$i].Name  | Should -BeExactly $products2[$i].Name
            $products1[$i].Price | Should -Be $products2[$i].Price
        }
    }

    It "Should generate the same orders with the same seed" {
        $rng1 = New-Object System.Random(7)
        $rng2 = New-Object System.Random(7)
        $orders1 = New-MockOrders -Rng $rng1 -Count 20 -MaxUserId 10 -MaxProductId 10
        $orders2 = New-MockOrders -Rng $rng2 -Count 20 -MaxUserId 10 -MaxProductId 10
        for ($i = 0; $i -lt 20; $i++) {
            $orders1[$i].UserId    | Should -Be $orders2[$i].UserId
            $orders1[$i].ProductId | Should -Be $orders2[$i].ProductId
            $orders1[$i].Quantity  | Should -Be $orders2[$i].Quantity
        }
    }

    It "Should produce different data with different seeds" {
        $rng1 = New-Object System.Random(1)
        $rng2 = New-Object System.Random(999)
        $users1 = New-MockUsers -Rng $rng1 -Count 10
        $users2 = New-MockUsers -Rng $rng2 -Count 10
        # At least one name should differ across the two runs
        $different = $false
        for ($i = 0; $i -lt 10; $i++) {
            if ($users1[$i].Name -ne $users2[$i].Name) { $different = $true; break }
        }
        $different | Should -BeTrue
    }

    It "Should generate the requested number of users" {
        $rng = New-Object System.Random(42)
        $users = New-MockUsers -Rng $rng -Count 25
        $users.Count | Should -Be 25
    }

    It "Should generate unique emails for all users" {
        $rng = New-Object System.Random(42)
        $users = New-MockUsers -Rng $rng -Count 20
        $emails = $users | ForEach-Object { $_.Email }
        ($emails | Select-Object -Unique).Count | Should -Be $users.Count
    }

    It "Should generate products with positive prices" {
        $rng = New-Object System.Random(42)
        $products = New-MockProducts -Rng $rng -Count 15
        foreach ($p in $products) {
            $p.Price | Should -BeGreaterThan 0
        }
    }

    It "Should generate orders with valid user/product references" {
        $rng = New-Object System.Random(42)
        $orders = New-MockOrders -Rng $rng -Count 30 -MaxUserId 20 -MaxProductId 15
        foreach ($o in $orders) {
            $o.UserId    | Should -BeGreaterOrEqual 1
            $o.UserId    | Should -BeLessOrEqual 20
            $o.ProductId | Should -BeGreaterOrEqual 1
            $o.ProductId | Should -BeLessOrEqual 15
            $o.Quantity  | Should -BeGreaterOrEqual 1
        }
    }
}

# ---------------------------------------------------------------------------
# TDD CYCLE 3: Data insertion with referential integrity
# RED: Tests insert data into a real in-memory database and verify counts & constraints
# ---------------------------------------------------------------------------
Describe "Data Insertion and Referential Integrity" {
    BeforeAll {
        $script:conn = New-SqliteConnection -DataSource ":memory:"
        Initialize-Schema -Connection $script:conn

        $rng = New-Object System.Random(42)
        $script:users    = New-MockUsers    -Rng $rng -Count 20
        $script:products = New-MockProducts -Rng $rng -Count 15
        $script:orders   = New-MockOrders   -Rng $rng -Count 50 -MaxUserId 20 -MaxProductId 15

        Insert-Users    -Connection $script:conn -Users $script:users
        Insert-Products -Connection $script:conn -Products $script:products
        Insert-Orders   -Connection $script:conn -Orders $script:orders
    }

    AfterAll {
        if ($script:conn) { $script:conn.Close(); $script:conn.Dispose() }
    }

    It "Should insert the correct number of users" {
        $count = Invoke-SqliteScalar -Connection $script:conn -Query "SELECT COUNT(*) FROM users;"
        [int]$count | Should -Be 20
    }

    It "Should insert the correct number of products" {
        $count = Invoke-SqliteScalar -Connection $script:conn -Query "SELECT COUNT(*) FROM products;"
        [int]$count | Should -Be 15
    }

    It "Should insert the correct number of orders" {
        $count = Invoke-SqliteScalar -Connection $script:conn -Query "SELECT COUNT(*) FROM orders;"
        [int]$count | Should -Be 50
    }

    It "Should store user emails correctly" {
        $dbEmails = Invoke-SqliteQuery -Connection $script:conn -Query "SELECT email FROM users ORDER BY id;"
        for ($i = 0; $i -lt $script:users.Count; $i++) {
            $dbEmails[$i].email | Should -BeExactly $script:users[$i].Email
        }
    }

    It "Should reject an order with a non-existent user_id" {
        # Foreign key constraint should prevent this insertion
        {
            $cmd = $script:conn.CreateCommand()
            $cmd.CommandText = "INSERT INTO orders (user_id, product_id, quantity, order_date) VALUES (9999, 1, 1, '2025-06-01');"
            $cmd.ExecuteNonQuery()
            $cmd.Dispose()
        } | Should -Throw
    }

    It "Should reject an order with a non-existent product_id" {
        {
            $cmd = $script:conn.CreateCommand()
            $cmd.CommandText = "INSERT INTO orders (user_id, product_id, quantity, order_date) VALUES (1, 9999, 1, '2025-06-01');"
            $cmd.ExecuteNonQuery()
            $cmd.Dispose()
        } | Should -Throw
    }

    It "Should reject a product with zero or negative price" {
        {
            $cmd = $script:conn.CreateCommand()
            $cmd.CommandText = "INSERT INTO products (name, price, category) VALUES ('Bad Product', 0, 'Test');"
            $cmd.ExecuteNonQuery()
            $cmd.Dispose()
        } | Should -Throw
    }

    It "Should reject an order with zero quantity" {
        {
            $cmd = $script:conn.CreateCommand()
            $cmd.CommandText = "INSERT INTO orders (user_id, product_id, quantity, order_date) VALUES (1, 1, 0, '2025-06-01');"
            $cmd.ExecuteNonQuery()
            $cmd.Dispose()
        } | Should -Throw
    }

    It "Should reject a duplicate email" {
        {
            $cmd = $script:conn.CreateCommand()
            $existingEmail = $script:users[0].Email
            $cmd.CommandText = "INSERT INTO users (name, email, created_at) VALUES ('Dup User', '$existingEmail', '2025-01-01');"
            $cmd.ExecuteNonQuery()
            $cmd.Dispose()
        } | Should -Throw
    }
}

# ---------------------------------------------------------------------------
# TDD CYCLE 4: Verification queries for data consistency
# RED: Tests the Get-VerificationResults function and the full Invoke-DatabaseSeed pipeline
# ---------------------------------------------------------------------------
Describe "Verification Queries" {
    BeforeAll {
        # Run the full seed pipeline with known seed
        $script:result = Invoke-DatabaseSeed -DataSource ":memory:" -Seed 42 `
            -UserCount 20 -ProductCount 15 -OrderCount 50
        $script:conn = $script:result.Connection
        $script:v    = $script:result.Verification
    }

    AfterAll {
        if ($script:conn) { $script:conn.Close(); $script:conn.Dispose() }
    }

    It "Should report correct user count" {
        $script:v.UserCount | Should -Be 20
    }

    It "Should report correct product count" {
        $script:v.ProductCount | Should -Be 15
    }

    It "Should report correct order count" {
        $script:v.OrderCount | Should -Be 50
    }

    It "Should find no orphan user references in orders" {
        $script:v.OrphanUserOrders | Should -Be 0
    }

    It "Should find no orphan product references in orders" {
        $script:v.OrphanProductOrders | Should -Be 0
    }

    It "Should have no duplicate emails" {
        $script:v.DuplicateEmails | Should -Be 0
    }

    It "Should have no invalid (non-positive) prices" {
        $script:v.InvalidPrices | Should -Be 0
    }

    It "Should have no invalid (non-positive) quantities" {
        $script:v.InvalidQuantities | Should -Be 0
    }

    It "Should calculate total revenue as a positive number" {
        $script:v.TotalRevenue | Should -BeGreaterThan 0
    }

    It "Should return orders-per-user for every user" {
        $script:v.OrdersPerUser.Count | Should -Be 20
    }

    It "Should return revenue-per-product for ordered products" {
        $script:v.RevenuePerProduct.Count | Should -BeGreaterThan 0
        foreach ($row in $script:v.RevenuePerProduct) {
            $row.total_revenue | Should -BeGreaterThan 0
        }
    }

    It "Should produce identical verification results on a second run with the same seed" {
        # Determinism check: a second seed with the same parameters must match
        $result2 = Invoke-DatabaseSeed -DataSource ":memory:" -Seed 42 `
            -UserCount 20 -ProductCount 15 -OrderCount 50
        $v2 = $result2.Verification

        $v2.UserCount         | Should -Be $script:v.UserCount
        $v2.ProductCount      | Should -Be $script:v.ProductCount
        $v2.OrderCount        | Should -Be $script:v.OrderCount
        $v2.TotalRevenue      | Should -Be $script:v.TotalRevenue
        $v2.DuplicateEmails   | Should -Be $script:v.DuplicateEmails

        $result2.Connection.Close(); $result2.Connection.Dispose()
    }
}
