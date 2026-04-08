# DatabaseSeed.Tests.ps1 - TDD tests for SQLite database seed script
# Using Pester 5.x with strict mode throughout

BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Import the module under test
    . "$PSScriptRoot/DatabaseSeed.ps1"
}

Describe 'Schema Creation' {
    BeforeEach {
        # Use an in-memory database for each test for isolation
        $script:TestDbPath = Join-Path $TestDrive "test_$(New-Guid).db"
    }

    AfterEach {
        if (Test-Path $script:TestDbPath) {
            Remove-Item $script:TestDbPath -Force
        }
    }

    It 'Should create a users table with correct columns' {
        Initialize-Database -DatabasePath $script:TestDbPath

        $columns = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "PRAGMA table_info(users);"
        $columnNames = @($columns | ForEach-Object { $_.name })

        $columnNames | Should -Contain 'id'
        $columnNames | Should -Contain 'username'
        $columnNames | Should -Contain 'email'
        $columnNames | Should -Contain 'first_name'
        $columnNames | Should -Contain 'last_name'
        $columnNames | Should -Contain 'created_at'
    }

    It 'Should create a products table with correct columns' {
        Initialize-Database -DatabasePath $script:TestDbPath

        $columns = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "PRAGMA table_info(products);"
        $columnNames = @($columns | ForEach-Object { $_.name })

        $columnNames | Should -Contain 'id'
        $columnNames | Should -Contain 'name'
        $columnNames | Should -Contain 'description'
        $columnNames | Should -Contain 'price'
        $columnNames | Should -Contain 'stock_quantity'
        $columnNames | Should -Contain 'category'
    }

    It 'Should create an orders table with correct columns' {
        Initialize-Database -DatabasePath $script:TestDbPath

        $columns = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "PRAGMA table_info(orders);"
        $columnNames = @($columns | ForEach-Object { $_.name })

        $columnNames | Should -Contain 'id'
        $columnNames | Should -Contain 'user_id'
        $columnNames | Should -Contain 'product_id'
        $columnNames | Should -Contain 'quantity'
        $columnNames | Should -Contain 'total_price'
        $columnNames | Should -Contain 'order_date'
        $columnNames | Should -Contain 'status'
    }

    It 'Should enforce foreign keys on the orders table' {
        Initialize-Database -DatabasePath $script:TestDbPath

        # Use a single connection so PRAGMA foreign_keys persists for the INSERT
        [System.Data.SQLite.SQLiteConnection]$conn = New-SqliteConnection -DataSource $script:TestDbPath
        try {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query "PRAGMA foreign_keys = ON;"
            {
                Invoke-SqliteQuery -SQLiteConnection $conn -Query @"
                    INSERT INTO orders (user_id, product_id, quantity, total_price, order_date, status)
                    VALUES (9999, 9999, 1, 10.00, '2025-01-01', 'pending');
"@ -ErrorAction Stop
            } | Should -Throw
        }
        finally {
            $conn.Close()
            $conn.Dispose()
        }
    }

    It 'Should have users.id as INTEGER PRIMARY KEY' {
        Initialize-Database -DatabasePath $script:TestDbPath

        $columns = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "PRAGMA table_info(users);"
        $idCol = $columns | Where-Object { $_.name -eq 'id' }

        [string]$idCol.type | Should -BeExactly 'INTEGER'
        [int]$idCol.pk | Should -Be 1
    }

    It 'Should have unique constraint on users.email' {
        Initialize-Database -DatabasePath $script:TestDbPath

        # Insert a user
        Invoke-SqliteQuery -DataSource $script:TestDbPath -Query @"
            INSERT INTO users (username, email, first_name, last_name, created_at)
            VALUES ('testuser', 'test@example.com', 'Test', 'User', '2025-01-01');
"@

        # Inserting duplicate email should fail
        {
            Invoke-SqliteQuery -DataSource $script:TestDbPath -Query @"
                INSERT INTO users (username, email, first_name, last_name, created_at)
                VALUES ('testuser2', 'test@example.com', 'Test2', 'User2', '2025-01-01');
"@ -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should have unique constraint on users.username' {
        Initialize-Database -DatabasePath $script:TestDbPath

        Invoke-SqliteQuery -DataSource $script:TestDbPath -Query @"
            INSERT INTO users (username, email, first_name, last_name, created_at)
            VALUES ('testuser', 'test1@example.com', 'Test', 'User', '2025-01-01');
"@

        {
            Invoke-SqliteQuery -DataSource $script:TestDbPath -Query @"
                INSERT INTO users (username, email, first_name, last_name, created_at)
                VALUES ('testuser', 'test2@example.com', 'Test2', 'User2', '2025-01-01');
"@ -ErrorAction Stop
        } | Should -Throw
    }
}

Describe 'Deterministic Data Generation' {
    It 'Should generate the same users given the same seed' {
        [hashtable[]]$users1 = New-MockUsers -Seed 42 -Count 5
        [hashtable[]]$users2 = New-MockUsers -Seed 42 -Count 5

        $users1.Count | Should -Be 5
        for ([int]$i = 0; $i -lt $users1.Count; $i++) {
            [string]$users1[$i].username | Should -BeExactly ([string]$users2[$i].username)
            [string]$users1[$i].email | Should -BeExactly ([string]$users2[$i].email)
            [string]$users1[$i].first_name | Should -BeExactly ([string]$users2[$i].first_name)
            [string]$users1[$i].last_name | Should -BeExactly ([string]$users2[$i].last_name)
        }
    }

    It 'Should generate different users with different seeds' {
        [hashtable[]]$users1 = New-MockUsers -Seed 42 -Count 3
        [hashtable[]]$users2 = New-MockUsers -Seed 99 -Count 3

        # At least one username should differ between the two sets
        [bool]$anyDifferent = $false
        for ([int]$i = 0; $i -lt $users1.Count; $i++) {
            if ([string]$users1[$i].username -ne [string]$users2[$i].username) {
                $anyDifferent = $true
                break
            }
        }
        $anyDifferent | Should -BeTrue
    }

    It 'Should generate users with valid email format' {
        [hashtable[]]$users = New-MockUsers -Seed 42 -Count 10

        foreach ($user in $users) {
            [string]$user.email | Should -Match '^[^@]+@[^@]+\.[^@]+$'
        }
    }

    It 'Should generate unique usernames and emails' {
        [hashtable[]]$users = New-MockUsers -Seed 42 -Count 20

        [string[]]$usernames = $users | ForEach-Object { [string]$_.username }
        [string[]]$emails = $users | ForEach-Object { [string]$_.email }

        ($usernames | Select-Object -Unique).Count | Should -Be $usernames.Count
        ($emails | Select-Object -Unique).Count | Should -Be $emails.Count
    }

    It 'Should generate the same products given the same seed' {
        [hashtable[]]$products1 = New-MockProducts -Seed 42 -Count 5
        [hashtable[]]$products2 = New-MockProducts -Seed 42 -Count 5

        $products1.Count | Should -Be 5
        for ([int]$i = 0; $i -lt $products1.Count; $i++) {
            [string]$products1[$i].name | Should -BeExactly ([string]$products2[$i].name)
            [double]$products1[$i].price | Should -Be ([double]$products2[$i].price)
        }
    }

    It 'Should generate products with positive prices and non-negative stock' {
        [hashtable[]]$products = New-MockProducts -Seed 42 -Count 10

        foreach ($product in $products) {
            [double]$product.price | Should -BeGreaterThan 0
            [int]$product.stock_quantity | Should -BeGreaterOrEqual 0
        }
    }

    It 'Should generate the same orders given the same seed' {
        [hashtable[]]$orders1 = New-MockOrders -Seed 42 -UserCount 5 -ProductCount 5 -Count 10
        [hashtable[]]$orders2 = New-MockOrders -Seed 42 -UserCount 5 -ProductCount 5 -Count 10

        $orders1.Count | Should -Be 10
        for ([int]$i = 0; $i -lt $orders1.Count; $i++) {
            [int]$orders1[$i].user_id | Should -Be ([int]$orders2[$i].user_id)
            [int]$orders1[$i].product_id | Should -Be ([int]$orders2[$i].product_id)
            [int]$orders1[$i].quantity | Should -Be ([int]$orders2[$i].quantity)
        }
    }

    It 'Should generate orders with valid foreign key references' {
        [int]$userCount = 5
        [int]$productCount = 8
        [hashtable[]]$orders = New-MockOrders -Seed 42 -UserCount $userCount -ProductCount $productCount -Count 20

        foreach ($order in $orders) {
            [int]$order.user_id | Should -BeGreaterOrEqual 1
            [int]$order.user_id | Should -BeLessOrEqual $userCount
            [int]$order.product_id | Should -BeGreaterOrEqual 1
            [int]$order.product_id | Should -BeLessOrEqual $productCount
        }
    }

    It 'Should generate orders with valid status values' {
        [hashtable[]]$orders = New-MockOrders -Seed 42 -UserCount 5 -ProductCount 5 -Count 15

        [string[]]$validStatuses = @('pending', 'shipped', 'delivered', 'cancelled')
        foreach ($order in $orders) {
            [string]$order.status | Should -BeIn $validStatuses
        }
    }
}

Describe 'Data Insertion' {
    BeforeEach {
        $script:TestDbPath = Join-Path $TestDrive "test_insert_$(New-Guid).db"
    }

    AfterEach {
        if (Test-Path $script:TestDbPath) {
            Remove-Item $script:TestDbPath -Force
        }
    }

    It 'Should insert users into the database' {
        Initialize-Database -DatabasePath $script:TestDbPath
        [hashtable[]]$users = New-MockUsers -Seed 42 -Count 10

        Import-MockUsers -DatabasePath $script:TestDbPath -Users $users

        $result = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "SELECT COUNT(*) AS cnt FROM users;"
        [int]$result.cnt | Should -Be 10
    }

    It 'Should insert products into the database' {
        Initialize-Database -DatabasePath $script:TestDbPath
        [hashtable[]]$products = New-MockProducts -Seed 42 -Count 8

        Import-MockProducts -DatabasePath $script:TestDbPath -Products $products

        $result = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "SELECT COUNT(*) AS cnt FROM products;"
        [int]$result.cnt | Should -Be 8
    }

    It 'Should insert orders with valid foreign keys' {
        Initialize-Database -DatabasePath $script:TestDbPath
        [int]$userCount = 5
        [int]$productCount = 6
        [hashtable[]]$users = New-MockUsers -Seed 42 -Count $userCount
        [hashtable[]]$products = New-MockProducts -Seed 42 -Count $productCount
        [hashtable[]]$orders = New-MockOrders -Seed 42 -UserCount $userCount -ProductCount $productCount -Count 15

        Import-MockUsers -DatabasePath $script:TestDbPath -Users $users
        Import-MockProducts -DatabasePath $script:TestDbPath -Products $products
        Import-MockOrders -DatabasePath $script:TestDbPath -Orders $orders

        $result = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "SELECT COUNT(*) AS cnt FROM orders;"
        [int]$result.cnt | Should -Be 15
    }

    It 'Should preserve user data fields correctly after insertion' {
        Initialize-Database -DatabasePath $script:TestDbPath
        [hashtable[]]$users = New-MockUsers -Seed 42 -Count 3

        Import-MockUsers -DatabasePath $script:TestDbPath -Users $users

        $rows = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "SELECT * FROM users ORDER BY id;"
        [string]$rows[0].username | Should -BeExactly ([string]$users[0].username)
        [string]$rows[0].email | Should -BeExactly ([string]$users[0].email)
        [string]$rows[0].first_name | Should -BeExactly ([string]$users[0].first_name)
    }

    It 'Should preserve product price accurately after insertion' {
        Initialize-Database -DatabasePath $script:TestDbPath
        [hashtable[]]$products = New-MockProducts -Seed 42 -Count 3

        Import-MockProducts -DatabasePath $script:TestDbPath -Products $products

        $rows = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "SELECT * FROM products ORDER BY id;"
        [double]$rows[0].price | Should -Be ([double]$products[0].price)
    }

    It 'Should run full seed pipeline via Invoke-DatabaseSeed' {
        [hashtable]$result = Invoke-DatabaseSeed -DatabasePath $script:TestDbPath -Seed 42 -UserCount 10 -ProductCount 8 -OrderCount 20

        [int]$result.Users | Should -Be 10
        [int]$result.Products | Should -Be 8
        [int]$result.Orders | Should -Be 20

        # Verify actual counts in the database match
        $dbUsers = Invoke-SqliteQuery -DataSource $script:TestDbPath -Query "SELECT COUNT(*) AS cnt FROM users;"
        [int]$dbUsers.cnt | Should -Be 10
    }
}

Describe 'Verification Queries' {
    BeforeAll {
        # Seed a shared database for all verification tests
        $script:VerifyDbPath = Join-Path $TestDrive "verify_$(New-Guid).db"
        Invoke-DatabaseSeed -DatabasePath $script:VerifyDbPath -Seed 42 -UserCount 15 -ProductCount 10 -OrderCount 30
    }

    AfterAll {
        if (Test-Path $script:VerifyDbPath) {
            Remove-Item $script:VerifyDbPath -Force
        }
    }

    It 'Should return correct table row counts via Get-TableCounts' {
        [hashtable]$counts = Get-TableCounts -DatabasePath $script:VerifyDbPath

        [int]$counts.users | Should -Be 15
        [int]$counts.products | Should -Be 10
        [int]$counts.orders | Should -Be 30
    }

    It 'Should verify all orders reference existing users via Test-ReferentialIntegrity' {
        [hashtable]$integrity = Test-ReferentialIntegrity -DatabasePath $script:VerifyDbPath

        [int]$integrity.OrphanedUserOrders | Should -Be 0
        [int]$integrity.OrphanedProductOrders | Should -Be 0
    }

    It 'Should compute order statistics via Get-OrderStatistics' {
        [hashtable]$stats = Get-OrderStatistics -DatabasePath $script:VerifyDbPath

        # Total revenue should be sum of all order total_prices
        $manualTotal = Invoke-SqliteQuery -DataSource $script:VerifyDbPath -Query "SELECT SUM(total_price) AS total FROM orders;"
        [double]$stats.TotalRevenue | Should -Be ([double]$manualTotal.total)

        # Average order value
        $manualAvg = Invoke-SqliteQuery -DataSource $script:VerifyDbPath -Query "SELECT AVG(total_price) AS avg_val FROM orders;"
        [math]::Round([double]$stats.AverageOrderValue, 2) | Should -Be ([math]::Round([double]$manualAvg.avg_val, 2))

        # Order count by status should sum to total orders
        [int]$statusSum = 0
        foreach ($key in $stats.OrdersByStatus.Keys) {
            $statusSum += [int]$stats.OrdersByStatus[$key]
        }
        $statusSum | Should -Be 30
    }

    It 'Should return top customers by order count via Get-TopCustomers' {
        [array]$topCustomers = Get-TopCustomers -DatabasePath $script:VerifyDbPath -Limit 5

        $topCustomers.Count | Should -BeLessOrEqual 5
        $topCustomers.Count | Should -BeGreaterThan 0

        # Results should be sorted descending by order count
        for ([int]$i = 1; $i -lt $topCustomers.Count; $i++) {
            [int]$topCustomers[$i].order_count | Should -BeLessOrEqual ([int]$topCustomers[$i - 1].order_count)
        }
    }

    It 'Should return product sales summary via Get-ProductSalesSummary' {
        [array]$summary = Get-ProductSalesSummary -DatabasePath $script:VerifyDbPath

        $summary.Count | Should -BeGreaterThan 0

        # Each entry should have product_name, total_quantity, and total_revenue
        foreach ($row in $summary) {
            [string]$row.product_name | Should -Not -BeNullOrEmpty
            [int]$row.total_quantity | Should -BeGreaterThan 0
            [double]$row.total_revenue | Should -BeGreaterThan 0
        }
    }

    It 'Should run all verifications via Invoke-VerificationQueries without errors' {
        [hashtable]$verification = Invoke-VerificationQueries -DatabasePath $script:VerifyDbPath

        [int]$verification.TableCounts.users | Should -Be 15
        [int]$verification.Integrity.OrphanedUserOrders | Should -Be 0
        [int]$verification.Integrity.OrphanedProductOrders | Should -Be 0
        [double]$verification.Statistics.TotalRevenue | Should -BeGreaterThan 0
        $verification.TopCustomers.Count | Should -BeGreaterThan 0
        $verification.ProductSales.Count | Should -BeGreaterThan 0
    }
}
