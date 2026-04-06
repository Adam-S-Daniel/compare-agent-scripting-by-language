# DatabaseSeed.Tests.ps1
# TDD tests for SQLite database seeding with deterministic mock data.
# Uses Pester 5+ for testing. Tests are structured in TDD order:
# 1. Schema creation (tables, foreign keys)
# 2. Deterministic data generation (seeded RNG)
# 3. Data insertion with referential integrity
# 4. Verification queries for data consistency

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test
    $modulePath = Join-Path $PSScriptRoot 'DatabaseSeed.psm1'
    Import-Module $modulePath -Force
}

Describe 'Schema Creation' {
    BeforeAll {
        # Create a fresh in-memory database for schema tests
        $script:conn = New-DatabaseConnection -DataSource ':memory:'
        Initialize-Schema -Connection $script:conn
    }

    AfterAll {
        if ($script:conn) {
            $script:conn.Close()
            $script:conn.Dispose()
        }
    }

    It 'should create the users table with correct columns' {
        $columns = Get-TableColumns -Connection $script:conn -TableName 'users'
        $columnNames = $columns | ForEach-Object { $_.Name }
        $columnNames | Should -Contain 'id'
        $columnNames | Should -Contain 'username'
        $columnNames | Should -Contain 'email'
        $columnNames | Should -Contain 'full_name'
        $columnNames | Should -Contain 'created_at'
    }

    It 'should create the products table with correct columns' {
        $columns = Get-TableColumns -Connection $script:conn -TableName 'products'
        $columnNames = $columns | ForEach-Object { $_.Name }
        $columnNames | Should -Contain 'id'
        $columnNames | Should -Contain 'name'
        $columnNames | Should -Contain 'description'
        $columnNames | Should -Contain 'price'
        $columnNames | Should -Contain 'category'
        $columnNames | Should -Contain 'stock_quantity'
    }

    It 'should create the orders table with correct columns' {
        $columns = Get-TableColumns -Connection $script:conn -TableName 'orders'
        $columnNames = $columns | ForEach-Object { $_.Name }
        $columnNames | Should -Contain 'id'
        $columnNames | Should -Contain 'user_id'
        $columnNames | Should -Contain 'product_id'
        $columnNames | Should -Contain 'quantity'
        $columnNames | Should -Contain 'total_price'
        $columnNames | Should -Contain 'order_date'
        $columnNames | Should -Contain 'status'
    }

    It 'should have users.id as INTEGER PRIMARY KEY' {
        $columns = Get-TableColumns -Connection $script:conn -TableName 'users'
        $idCol = $columns | Where-Object { $_.Name -eq 'id' }
        $idCol.Type | Should -Be 'INTEGER'
        $idCol.PrimaryKey | Should -BeTrue
    }

    It 'should have products.id as INTEGER PRIMARY KEY' {
        $columns = Get-TableColumns -Connection $script:conn -TableName 'products'
        $idCol = $columns | Where-Object { $_.Name -eq 'id' }
        $idCol.Type | Should -Be 'INTEGER'
        $idCol.PrimaryKey | Should -BeTrue
    }

    It 'should have orders.id as INTEGER PRIMARY KEY' {
        $columns = Get-TableColumns -Connection $script:conn -TableName 'orders'
        $idCol = $columns | Where-Object { $_.Name -eq 'id' }
        $idCol.Type | Should -Be 'INTEGER'
        $idCol.PrimaryKey | Should -BeTrue
    }

    It 'should enforce foreign key from orders.user_id to users.id' {
        $fkeys = Get-ForeignKeys -Connection $script:conn -TableName 'orders'
        $userFK = $fkeys | Where-Object { $_.From -eq 'user_id' }
        $userFK | Should -Not -BeNullOrEmpty
        $userFK.Table | Should -Be 'users'
        $userFK.To | Should -Be 'id'
    }

    It 'should enforce foreign key from orders.product_id to products.id' {
        $fkeys = Get-ForeignKeys -Connection $script:conn -TableName 'orders'
        $productFK = $fkeys | Where-Object { $_.From -eq 'product_id' }
        $productFK | Should -Not -BeNullOrEmpty
        $productFK.Table | Should -Be 'products'
        $productFK.To | Should -Be 'id'
    }

    It 'should have exactly 3 tables' {
        $tables = Get-AllTables -Connection $script:conn
        $tables.Count | Should -Be 3
    }
}

Describe 'Deterministic Data Generation' {
    It 'should generate the same users with the same seed' {
        $users1 = New-MockUsers -Seed 42 -Count 10
        $users2 = New-MockUsers -Seed 42 -Count 10
        $users1.Count | Should -Be 10
        for ($i = 0; $i -lt $users1.Count; $i++) {
            $users1[$i].Username | Should -Be $users2[$i].Username
            $users1[$i].Email | Should -Be $users2[$i].Email
            $users1[$i].FullName | Should -Be $users2[$i].FullName
        }
    }

    It 'should generate different users with different seeds' {
        $users1 = New-MockUsers -Seed 42 -Count 5
        $users2 = New-MockUsers -Seed 99 -Count 5
        # At least one user should differ
        $allSame = $true
        for ($i = 0; $i -lt $users1.Count; $i++) {
            if ($users1[$i].Username -ne $users2[$i].Username) {
                $allSame = $false
                break
            }
        }
        $allSame | Should -BeFalse
    }

    It 'should generate the requested number of users' {
        $users = New-MockUsers -Seed 1 -Count 25
        $users.Count | Should -Be 25
    }

    It 'should generate users with valid email format' {
        $users = New-MockUsers -Seed 42 -Count 10
        foreach ($user in $users) {
            $user.Email | Should -Match '^[^@]+@[^@]+\.[^@]+$'
        }
    }

    It 'should generate unique usernames' {
        $users = New-MockUsers -Seed 42 -Count 50
        $uniqueNames = $users | Select-Object -ExpandProperty Username -Unique
        $uniqueNames.Count | Should -Be 50
    }

    It 'should generate the same products with the same seed' {
        $products1 = New-MockProducts -Seed 42 -Count 10
        $products2 = New-MockProducts -Seed 42 -Count 10
        $products1.Count | Should -Be 10
        for ($i = 0; $i -lt $products1.Count; $i++) {
            $products1[$i].Name | Should -Be $products2[$i].Name
            $products1[$i].Price | Should -Be $products2[$i].Price
            $products1[$i].Category | Should -Be $products2[$i].Category
        }
    }

    It 'should generate products with positive prices' {
        $products = New-MockProducts -Seed 42 -Count 20
        foreach ($product in $products) {
            $product.Price | Should -BeGreaterThan 0
        }
    }

    It 'should generate products with non-negative stock' {
        $products = New-MockProducts -Seed 42 -Count 20
        foreach ($product in $products) {
            $product.StockQuantity | Should -BeGreaterOrEqual 0
        }
    }

    It 'should generate products with valid categories' {
        $validCategories = @('Electronics', 'Clothing', 'Books', 'Home', 'Sports', 'Food', 'Toys', 'Health')
        $products = New-MockProducts -Seed 42 -Count 20
        foreach ($product in $products) {
            $product.Category | Should -BeIn $validCategories
        }
    }

    It 'should generate the same orders with the same seed' {
        $orders1 = New-MockOrders -Seed 42 -Count 10 -MaxUserId 5 -MaxProductId 10
        $orders2 = New-MockOrders -Seed 42 -Count 10 -MaxUserId 5 -MaxProductId 10
        $orders1.Count | Should -Be 10
        for ($i = 0; $i -lt $orders1.Count; $i++) {
            $orders1[$i].UserId | Should -Be $orders2[$i].UserId
            $orders1[$i].ProductId | Should -Be $orders2[$i].ProductId
            $orders1[$i].Quantity | Should -Be $orders2[$i].Quantity
        }
    }

    It 'should generate orders with valid user and product references' {
        $maxUser = 10
        $maxProduct = 15
        $orders = New-MockOrders -Seed 42 -Count 30 -MaxUserId $maxUser -MaxProductId $maxProduct
        foreach ($order in $orders) {
            $order.UserId | Should -BeGreaterOrEqual 1
            $order.UserId | Should -BeLessOrEqual $maxUser
            $order.ProductId | Should -BeGreaterOrEqual 1
            $order.ProductId | Should -BeLessOrEqual $maxProduct
        }
    }

    It 'should generate orders with valid statuses' {
        $validStatuses = @('pending', 'processing', 'shipped', 'delivered', 'cancelled')
        $orders = New-MockOrders -Seed 42 -Count 20 -MaxUserId 5 -MaxProductId 10
        foreach ($order in $orders) {
            $order.Status | Should -BeIn $validStatuses
        }
    }

    It 'should generate orders with positive quantities' {
        $orders = New-MockOrders -Seed 42 -Count 20 -MaxUserId 5 -MaxProductId 10
        foreach ($order in $orders) {
            $order.Quantity | Should -BeGreaterThan 0
        }
    }
}

Describe 'Data Insertion with Referential Integrity' {
    BeforeAll {
        $script:conn = New-DatabaseConnection -DataSource ':memory:'
        Initialize-Schema -Connection $script:conn
        $script:seedResult = Import-SeedData -Connection $script:conn -Seed 42 -UserCount 20 -ProductCount 15 -OrderCount 50
    }

    AfterAll {
        if ($script:conn) {
            $script:conn.Close()
            $script:conn.Dispose()
        }
    }

    It 'should insert the correct number of users' {
        $count = Invoke-ScalarQuery -Connection $script:conn -Query 'SELECT COUNT(*) FROM users'
        [int]$count | Should -Be 20
    }

    It 'should insert the correct number of products' {
        $count = Invoke-ScalarQuery -Connection $script:conn -Query 'SELECT COUNT(*) FROM products'
        [int]$count | Should -Be 15
    }

    It 'should insert the correct number of orders' {
        $count = Invoke-ScalarQuery -Connection $script:conn -Query 'SELECT COUNT(*) FROM orders'
        [int]$count | Should -Be 50
    }

    It 'should return seed result with correct counts' {
        $script:seedResult.UsersInserted | Should -Be 20
        $script:seedResult.ProductsInserted | Should -Be 15
        $script:seedResult.OrdersInserted | Should -Be 50
    }

    It 'should not have orphaned orders (all user_ids exist)' {
        $orphanedUsers = Invoke-ScalarQuery -Connection $script:conn -Query '
            SELECT COUNT(*) FROM orders o
            LEFT JOIN users u ON o.user_id = u.id
            WHERE u.id IS NULL'
        [int]$orphanedUsers | Should -Be 0
    }

    It 'should not have orphaned orders (all product_ids exist)' {
        $orphanedProducts = Invoke-ScalarQuery -Connection $script:conn -Query '
            SELECT COUNT(*) FROM orders o
            LEFT JOIN products p ON o.product_id = p.id
            WHERE p.id IS NULL'
        [int]$orphanedProducts | Should -Be 0
    }

    It 'should produce the same data when seeded identically' {
        $conn2 = New-DatabaseConnection -DataSource ':memory:'
        try {
            Initialize-Schema -Connection $conn2
            Import-SeedData -Connection $conn2 -Seed 42 -UserCount 20 -ProductCount 15 -OrderCount 50

            # Compare first user
            $user1 = Invoke-QueryRows -Connection $script:conn -Query 'SELECT username, email FROM users WHERE id = 1'
            $user2 = Invoke-QueryRows -Connection $conn2 -Query 'SELECT username, email FROM users WHERE id = 1'
            $user1[0].username | Should -Be $user2[0].username
            $user1[0].email | Should -Be $user2[0].email
        }
        finally {
            $conn2.Close()
            $conn2.Dispose()
        }
    }

    It 'should store valid email addresses in the database' {
        $rows = Invoke-QueryRows -Connection $script:conn -Query 'SELECT email FROM users'
        foreach ($row in $rows) {
            $row.email | Should -Match '^[^@]+@[^@]+\.[^@]+$'
        }
    }

    It 'should have unique usernames in the database' {
        $totalCount = Invoke-ScalarQuery -Connection $script:conn -Query 'SELECT COUNT(*) FROM users'
        $uniqueCount = Invoke-ScalarQuery -Connection $script:conn -Query 'SELECT COUNT(DISTINCT username) FROM users'
        [int]$totalCount | Should -Be ([int]$uniqueCount)
    }

    It 'should reject insert with invalid foreign key' {
        # Try inserting an order referencing a non-existent user
        { Invoke-NonQuery -Connection $script:conn -Query "INSERT INTO orders (user_id, product_id, quantity, total_price, order_date, status) VALUES (9999, 1, 1, 10.00, '2024-01-01', 'pending')" } |
            Should -Throw
    }
}

Describe 'Verification Queries' {
    BeforeAll {
        $script:conn = New-DatabaseConnection -DataSource ':memory:'
        Initialize-Schema -Connection $script:conn
        Import-SeedData -Connection $script:conn -Seed 42 -UserCount 20 -ProductCount 15 -OrderCount 50
        $script:verification = Test-DataIntegrity -Connection $script:conn
    }

    AfterAll {
        if ($script:conn) {
            $script:conn.Close()
            $script:conn.Dispose()
        }
    }

    It 'should verify all tables exist' {
        $script:verification.TablesExist | Should -BeTrue
    }

    It 'should verify no orphaned foreign keys' {
        $script:verification.NoOrphanedOrders | Should -BeTrue
    }

    It 'should verify all order totals are positive' {
        $script:verification.AllTotalsPositive | Should -BeTrue
    }

    It 'should verify all products have valid prices' {
        $script:verification.AllPricesValid | Should -BeTrue
    }

    It 'should verify all usernames are unique' {
        $script:verification.UniqueUsernames | Should -BeTrue
    }

    It 'should report correct user count' {
        $script:verification.UserCount | Should -Be 20
    }

    It 'should report correct product count' {
        $script:verification.ProductCount | Should -Be 15
    }

    It 'should report correct order count' {
        $script:verification.OrderCount | Should -Be 50
    }

    It 'should calculate total revenue correctly' {
        $expectedRevenue = Invoke-ScalarQuery -Connection $script:conn -Query 'SELECT SUM(total_price) FROM orders'
        $script:verification.TotalRevenue | Should -Be ([double]$expectedRevenue)
    }

    It 'should identify the top-spending user' {
        $topSpender = Invoke-QueryRows -Connection $script:conn -Query '
            SELECT u.username, SUM(o.total_price) as total_spent
            FROM orders o JOIN users u ON o.user_id = u.id
            GROUP BY o.user_id ORDER BY total_spent DESC LIMIT 1'
        $script:verification.TopSpender | Should -Be $topSpender[0].username
    }

    It 'should identify the most ordered product' {
        $topProduct = Invoke-QueryRows -Connection $script:conn -Query '
            SELECT p.name, COUNT(o.id) as order_count
            FROM orders o JOIN products p ON o.product_id = p.id
            GROUP BY o.product_id ORDER BY order_count DESC LIMIT 1'
        $script:verification.MostOrderedProduct | Should -Be $topProduct[0].name
    }

    It 'should calculate average order value' {
        $avgValue = Invoke-ScalarQuery -Connection $script:conn -Query 'SELECT AVG(total_price) FROM orders'
        [math]::Round([double]$script:verification.AverageOrderValue, 2) |
            Should -Be ([math]::Round([double]$avgValue, 2))
    }

    It 'should report orders per status breakdown' {
        $script:verification.OrdersByStatus | Should -Not -BeNullOrEmpty
        $statusTotal = ($script:verification.OrdersByStatus.Values | Measure-Object -Sum).Sum
        [int]$statusTotal | Should -Be 50
    }
}

Describe 'Full Pipeline Integration' {
    It 'should seed and verify a database end-to-end using a file' {
        $tempDb = Join-Path ([System.IO.Path]::GetTempPath()) "test_seed_$(Get-Random).db"
        try {
            $conn = New-DatabaseConnection -DataSource $tempDb
            Initialize-Schema -Connection $conn
            $result = Import-SeedData -Connection $conn -Seed 123 -UserCount 10 -ProductCount 8 -OrderCount 30
            $verification = Test-DataIntegrity -Connection $conn

            $result.UsersInserted | Should -Be 10
            $result.ProductsInserted | Should -Be 8
            $result.OrdersInserted | Should -Be 30

            $verification.TablesExist | Should -BeTrue
            $verification.NoOrphanedOrders | Should -BeTrue
            $verification.UniqueUsernames | Should -BeTrue
            $verification.UserCount | Should -Be 10
            $verification.ProductCount | Should -Be 8
            $verification.OrderCount | Should -Be 30
            $conn.Close()
            $conn.Dispose()
        }
        finally {
            if (Test-Path $tempDb) { Remove-Item $tempDb -Force }
        }
    }

    It 'should produce reproducible results across separate databases' {
        $tempDb1 = Join-Path ([System.IO.Path]::GetTempPath()) "test_repro1_$(Get-Random).db"
        $tempDb2 = Join-Path ([System.IO.Path]::GetTempPath()) "test_repro2_$(Get-Random).db"
        try {
            $conn1 = New-DatabaseConnection -DataSource $tempDb1
            $conn2 = New-DatabaseConnection -DataSource $tempDb2

            Initialize-Schema -Connection $conn1
            Initialize-Schema -Connection $conn2

            Import-SeedData -Connection $conn1 -Seed 777 -UserCount 10 -ProductCount 5 -OrderCount 20
            Import-SeedData -Connection $conn2 -Seed 777 -UserCount 10 -ProductCount 5 -OrderCount 20

            $v1 = Test-DataIntegrity -Connection $conn1
            $v2 = Test-DataIntegrity -Connection $conn2

            $v1.TotalRevenue | Should -Be $v2.TotalRevenue
            $v1.TopSpender | Should -Be $v2.TopSpender
            $v1.MostOrderedProduct | Should -Be $v2.MostOrderedProduct

            $conn1.Close(); $conn1.Dispose()
            $conn2.Close(); $conn2.Dispose()
        }
        finally {
            if (Test-Path $tempDb1) { Remove-Item $tempDb1 -Force }
            if (Test-Path $tempDb2) { Remove-Item $tempDb2 -Force }
        }
    }
}
