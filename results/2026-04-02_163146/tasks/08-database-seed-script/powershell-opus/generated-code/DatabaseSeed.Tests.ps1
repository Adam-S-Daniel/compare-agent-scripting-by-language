# DatabaseSeed.Tests.ps1 - Pester tests for the SQLite database seed script
# Tests follow red/green TDD: each Describe block covers a specific piece of functionality
# that was first written as a failing test, then made to pass.

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/DatabaseSeed.ps1"
}

Describe 'Schema Creation' {
    # TDD RED: These tests were written first to define the expected schema.
    # TDD GREEN: New-DatabaseSchema was then implemented to satisfy them.

    BeforeAll {
        $script:testDb = Join-Path $TestDrive 'schema_test.db'
        New-DatabaseSchema -DatabasePath $script:testDb
    }

    It 'Should create the database file' {
        $script:testDb | Should -Exist
    }

    It 'Should create the users table' {
        $tables = Invoke-SqliteQuery -DataSource $script:testDb -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='users';"
        $tables.name | Should -Be 'users'
    }

    It 'Should create the products table' {
        $tables = Invoke-SqliteQuery -DataSource $script:testDb -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='products';"
        $tables.name | Should -Be 'products'
    }

    It 'Should create the orders table' {
        $tables = Invoke-SqliteQuery -DataSource $script:testDb -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='orders';"
        $tables.name | Should -Be 'orders'
    }

    It 'Should have correct columns in users table' {
        $columns = Invoke-SqliteQuery -DataSource $script:testDb -Query "PRAGMA table_info(users);"
        $colNames = $columns.name
        $colNames | Should -Contain 'id'
        $colNames | Should -Contain 'username'
        $colNames | Should -Contain 'email'
        $colNames | Should -Contain 'first_name'
        $colNames | Should -Contain 'last_name'
        $colNames | Should -Contain 'created_at'
    }

    It 'Should have correct columns in products table' {
        $columns = Invoke-SqliteQuery -DataSource $script:testDb -Query "PRAGMA table_info(products);"
        $colNames = $columns.name
        $colNames | Should -Contain 'id'
        $colNames | Should -Contain 'name'
        $colNames | Should -Contain 'description'
        $colNames | Should -Contain 'price'
        $colNames | Should -Contain 'stock_quantity'
        $colNames | Should -Contain 'category'
    }

    It 'Should have correct columns in orders table' {
        $columns = Invoke-SqliteQuery -DataSource $script:testDb -Query "PRAGMA table_info(orders);"
        $colNames = $columns.name
        $colNames | Should -Contain 'id'
        $colNames | Should -Contain 'user_id'
        $colNames | Should -Contain 'product_id'
        $colNames | Should -Contain 'quantity'
        $colNames | Should -Contain 'total_price'
        $colNames | Should -Contain 'order_date'
        $colNames | Should -Contain 'status'
    }

    It 'Should have foreign keys on orders table' {
        $fks = Invoke-SqliteQuery -DataSource $script:testDb -Query "PRAGMA foreign_key_list(orders);"
        $referencedTables = $fks.table
        $referencedTables | Should -Contain 'users'
        $referencedTables | Should -Contain 'products'
    }

    It 'Should have NOT NULL constraints on required user fields' {
        $columns = Invoke-SqliteQuery -DataSource $script:testDb -Query "PRAGMA table_info(users);"
        # notnull column: 1 = NOT NULL, 0 = nullable
        ($columns | Where-Object { $_.name -eq 'username' }).notnull | Should -Be 1
        ($columns | Where-Object { $_.name -eq 'email' }).notnull | Should -Be 1
        ($columns | Where-Object { $_.name -eq 'first_name' }).notnull | Should -Be 1
        ($columns | Where-Object { $_.name -eq 'last_name' }).notnull | Should -Be 1
    }

    It 'Should have NOT NULL constraint on product price' {
        $columns = Invoke-SqliteQuery -DataSource $script:testDb -Query "PRAGMA table_info(products);"
        ($columns | Where-Object { $_.name -eq 'price' }).notnull | Should -Be 1
    }

    It 'Should be idempotent (CREATE IF NOT EXISTS)' {
        # Calling again should not throw
        { New-DatabaseSchema -DatabasePath $script:testDb } | Should -Not -Throw
    }
}

Describe 'Deterministic Mock Data Generation' {
    # TDD RED: Tests were written to verify that the same seed always produces the same data.
    # TDD GREEN: New-MockUsers/Products/Orders were implemented with seeded System.Random.

    Context 'User generation' {
        It 'Should generate the requested number of users' {
            $users = New-MockUsers -Seed 42 -Count 10
            $users.Count | Should -Be 10
        }

        It 'Should produce deterministic results with the same seed' {
            $users1 = New-MockUsers -Seed 42 -Count 5
            $users2 = New-MockUsers -Seed 42 -Count 5
            for ($i = 0; $i -lt 5; $i++) {
                $users1[$i].username | Should -Be $users2[$i].username
                $users1[$i].email | Should -Be $users2[$i].email
                $users1[$i].first_name | Should -Be $users2[$i].first_name
                $users1[$i].last_name | Should -Be $users2[$i].last_name
            }
        }

        It 'Should produce different results with different seeds' {
            $users1 = New-MockUsers -Seed 42 -Count 5
            $users2 = New-MockUsers -Seed 99 -Count 5
            # At least one username should differ
            $allSame = $true
            for ($i = 0; $i -lt 5; $i++) {
                if ($users1[$i].username -ne $users2[$i].username) {
                    $allSame = $false
                    break
                }
            }
            $allSame | Should -BeFalse
        }

        It 'Should generate unique usernames' {
            $users = New-MockUsers -Seed 42 -Count 15
            $usernames = $users | ForEach-Object { $_.username }
            ($usernames | Select-Object -Unique).Count | Should -Be $usernames.Count
        }

        It 'Should generate unique emails' {
            $users = New-MockUsers -Seed 42 -Count 15
            $emails = $users | ForEach-Object { $_.email }
            ($emails | Select-Object -Unique).Count | Should -Be $emails.Count
        }

        It 'Should generate valid email format' {
            $users = New-MockUsers -Seed 42 -Count 10
            foreach ($user in $users) {
                $user.email | Should -Match '^[^@]+@[^@]+\.[^@]+$'
            }
        }

        It 'Should populate all required fields' {
            $users = New-MockUsers -Seed 42 -Count 5
            foreach ($user in $users) {
                $user.username | Should -Not -BeNullOrEmpty
                $user.email | Should -Not -BeNullOrEmpty
                $user.first_name | Should -Not -BeNullOrEmpty
                $user.last_name | Should -Not -BeNullOrEmpty
                $user.created_at | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Product generation' {
        It 'Should generate the requested number of products' {
            $products = New-MockProducts -Seed 43 -Count 15
            $products.Count | Should -Be 15
        }

        It 'Should produce deterministic results with the same seed' {
            $products1 = New-MockProducts -Seed 43 -Count 5
            $products2 = New-MockProducts -Seed 43 -Count 5
            for ($i = 0; $i -lt 5; $i++) {
                $products1[$i].name | Should -Be $products2[$i].name
                $products1[$i].price | Should -Be $products2[$i].price
                $products1[$i].category | Should -Be $products2[$i].category
            }
        }

        It 'Should generate positive prices' {
            $products = New-MockProducts -Seed 43 -Count 15
            foreach ($product in $products) {
                $product.price | Should -BeGreaterThan 0
            }
        }

        It 'Should generate non-negative stock quantities' {
            $products = New-MockProducts -Seed 43 -Count 15
            foreach ($product in $products) {
                $product.stock_quantity | Should -BeGreaterOrEqual 0
            }
        }

        It 'Should assign valid categories' {
            $validCategories = @('Electronics', 'Books', 'Clothing', 'Home & Garden', 'Sports')
            $products = New-MockProducts -Seed 43 -Count 15
            foreach ($product in $products) {
                $product.category | Should -BeIn $validCategories
            }
        }

        It 'Should generate unique product names' {
            $products = New-MockProducts -Seed 43 -Count 15
            $names = $products | ForEach-Object { $_.name }
            ($names | Select-Object -Unique).Count | Should -Be $names.Count
        }
    }

    Context 'Order generation' {
        BeforeAll {
            $script:products = New-MockProducts -Seed 43 -Count 15
        }

        It 'Should generate the requested number of orders' {
            $orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25
            $orders.Count | Should -Be 25
        }

        It 'Should produce deterministic results with the same seed' {
            $orders1 = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 10
            $orders2 = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 10
            for ($i = 0; $i -lt 10; $i++) {
                $orders1[$i].user_id | Should -Be $orders2[$i].user_id
                $orders1[$i].product_id | Should -Be $orders2[$i].product_id
                $orders1[$i].quantity | Should -Be $orders2[$i].quantity
                $orders1[$i].total_price | Should -Be $orders2[$i].total_price
            }
        }

        It 'Should reference valid user IDs (1 to UserCount)' {
            $orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25
            foreach ($order in $orders) {
                $order.user_id | Should -BeGreaterOrEqual 1
                $order.user_id | Should -BeLessOrEqual 10
            }
        }

        It 'Should reference valid product IDs (1 to ProductCount)' {
            $orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25
            foreach ($order in $orders) {
                $order.product_id | Should -BeGreaterOrEqual 1
                $order.product_id | Should -BeLessOrEqual 15
            }
        }

        It 'Should have positive quantities' {
            $orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25
            foreach ($order in $orders) {
                $order.quantity | Should -BeGreaterThan 0
            }
        }

        It 'Should have positive total prices' {
            $orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25
            foreach ($order in $orders) {
                $order.total_price | Should -BeGreaterThan 0
            }
        }

        It 'Should calculate total_price as price * quantity' {
            $orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25
            foreach ($order in $orders) {
                $expectedPrice = [math]::Round($script:products[$order.product_id - 1].price * $order.quantity, 2)
                $order.total_price | Should -Be $expectedPrice
            }
        }

        It 'Should assign valid statuses' {
            $validStatuses = @('pending', 'processing', 'shipped', 'delivered', 'cancelled')
            $orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25
            foreach ($order in $orders) {
                $order.status | Should -BeIn $validStatuses
            }
        }
    }
}

Describe 'Data Insertion with Referential Integrity' {
    # TDD RED: Tests verify data gets properly inserted and FK constraints hold.
    # TDD GREEN: Import-MockData was implemented to insert in dependency order.

    BeforeAll {
        $script:testDb = Join-Path $TestDrive 'insert_test.db'
        New-DatabaseSchema -DatabasePath $script:testDb

        $script:users = New-MockUsers -Seed 42 -Count 10
        $script:products = New-MockProducts -Seed 43 -Count 15
        $script:orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25

        Import-MockData -DatabasePath $script:testDb -Users $script:users -Products $script:products -Orders $script:orders
    }

    It 'Should insert all users' {
        $count = (Invoke-SqliteQuery -DataSource $script:testDb -Query "SELECT COUNT(*) as cnt FROM users;").cnt
        $count | Should -Be 10
    }

    It 'Should insert all products' {
        $count = (Invoke-SqliteQuery -DataSource $script:testDb -Query "SELECT COUNT(*) as cnt FROM products;").cnt
        $count | Should -Be 15
    }

    It 'Should insert all orders' {
        $count = (Invoke-SqliteQuery -DataSource $script:testDb -Query "SELECT COUNT(*) as cnt FROM orders;").cnt
        $count | Should -Be 25
    }

    It 'Should store correct user data' {
        $firstUser = $script:users[0]
        $dbUser = Invoke-SqliteQuery -DataSource $script:testDb -Query "SELECT * FROM users WHERE username = @username;" -SqlParameters @{
            username = $firstUser.username
        }
        $dbUser.email | Should -Be $firstUser.email
        $dbUser.first_name | Should -Be $firstUser.first_name
        $dbUser.last_name | Should -Be $firstUser.last_name
    }

    It 'Should store correct product data' {
        $firstProduct = $script:products[0]
        $dbProduct = Invoke-SqliteQuery -DataSource $script:testDb -Query "SELECT * FROM products WHERE name = @name;" -SqlParameters @{
            name = $firstProduct.name
        }
        $dbProduct.price | Should -Be $firstProduct.price
        $dbProduct.category | Should -Be $firstProduct.category
    }

    It 'Should enforce unique username constraint' {
        $dupQuery = "INSERT INTO users (username, email, first_name, last_name) VALUES ('$($script:users[0].username)', 'dup@test.com', 'Dup', 'User');"
        { Invoke-SqliteQuery -DataSource $script:testDb -Query $dupQuery } | Should -Throw
    }

    It 'Should enforce unique email constraint' {
        $dupQuery = "INSERT INTO users (username, email, first_name, last_name) VALUES ('unique_user', '$($script:users[0].email)', 'Dup', 'User');"
        { Invoke-SqliteQuery -DataSource $script:testDb -Query $dupQuery } | Should -Throw
    }

    It 'Should have no orphaned orders (all user_ids valid)' {
        $orphans = (Invoke-SqliteQuery -DataSource $script:testDb -Query @"
SELECT COUNT(*) as cnt FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE u.id IS NULL;
"@).cnt
        $orphans | Should -Be 0
    }

    It 'Should have no orphaned orders (all product_ids valid)' {
        $orphans = (Invoke-SqliteQuery -DataSource $script:testDb -Query @"
SELECT COUNT(*) as cnt FROM orders o
LEFT JOIN products p ON o.product_id = p.id
WHERE p.id IS NULL;
"@).cnt
        $orphans | Should -Be 0
    }

    It 'Should have all order user_ids matching existing users' {
        # Verify every order user_id exists in the users table
        $result = Invoke-SqliteQuery -DataSource $script:testDb -Query @"
SELECT COUNT(*) as cnt FROM orders
WHERE user_id NOT IN (SELECT id FROM users);
"@
        $result.cnt | Should -Be 0
    }

    It 'Should have all order product_ids matching existing products' {
        # Verify every order product_id exists in the products table
        $result = Invoke-SqliteQuery -DataSource $script:testDb -Query @"
SELECT COUNT(*) as cnt FROM orders
WHERE product_id NOT IN (SELECT id FROM products);
"@
        $result.cnt | Should -Be 0
    }
}

Describe 'Verification Queries' {
    # TDD RED: Tests validate that Test-DataConsistency returns correct aggregation results.
    # TDD GREEN: Test-DataConsistency was implemented with comprehensive SQL queries.

    BeforeAll {
        $script:testDb = Join-Path $TestDrive 'verify_test.db'
        New-DatabaseSchema -DatabasePath $script:testDb

        $script:users = New-MockUsers -Seed 42 -Count 10
        $script:products = New-MockProducts -Seed 43 -Count 15
        $script:orders = New-MockOrders -Seed 44 -UserCount 10 -ProductCount 15 -Products $script:products -Count 25

        Import-MockData -DatabasePath $script:testDb -Users $script:users -Products $script:products -Orders $script:orders

        $script:verification = Test-DataConsistency -DatabasePath $script:testDb
    }

    It 'Should report correct user count' {
        $script:verification.UserCount | Should -Be 10
    }

    It 'Should report correct product count' {
        $script:verification.ProductCount | Should -Be 15
    }

    It 'Should report correct order count' {
        $script:verification.OrderCount | Should -Be 25
    }

    It 'Should report zero orphaned user orders' {
        $script:verification.OrphanUserOrders | Should -Be 0
    }

    It 'Should report zero orphaned product orders' {
        $script:verification.OrphanProductOrders | Should -Be 0
    }

    It 'Should report positive total revenue' {
        $script:verification.TotalRevenue | Should -BeGreaterThan 0
    }

    It 'Should report positive average order value' {
        $script:verification.AverageOrderValue | Should -BeGreaterThan 0
    }

    It 'Should report zero invalid price orders' {
        $script:verification.InvalidPriceOrders | Should -Be 0
    }

    It 'Should report zero invalid status orders' {
        $script:verification.InvalidStatusOrders | Should -Be 0
    }

    It 'Should report zero duplicate usernames' {
        $script:verification.DuplicateUsernames | Should -Be 0
    }

    It 'Should report zero duplicate emails' {
        $script:verification.DuplicateEmails | Should -Be 0
    }

    It 'Should have orders grouped by status' {
        $script:verification.OrdersByStatus.Keys.Count | Should -BeGreaterThan 0
        # Sum of all status counts should equal total orders
        $statusSum = ($script:verification.OrdersByStatus.Values | Measure-Object -Sum).Sum
        $statusSum | Should -Be 25
    }

    It 'Should return top spenders' {
        $script:verification.TopSpenders | Should -Not -BeNullOrEmpty
        # Top spenders should have at most 5 entries
        @($script:verification.TopSpenders).Count | Should -BeLessOrEqual 5
    }

    It 'Should return category statistics' {
        $script:verification.CategoryStats | Should -Not -BeNullOrEmpty
    }

    It 'Should have total revenue equal to sum of all order total_prices' {
        # Manually compute expected total from the mock orders
        $expectedTotal = [math]::Round(($script:orders | Measure-Object -Property total_price -Sum).Sum, 2)
        $script:verification.TotalRevenue | Should -Be $expectedTotal
    }

    It 'Should have average order value equal to total revenue / order count' {
        $expectedAvg = [math]::Round($script:verification.TotalRevenue / $script:verification.OrderCount, 2)
        $script:verification.AverageOrderValue | Should -Be $expectedAvg
    }
}

Describe 'Invoke-DatabaseSeed Integration' {
    # TDD RED: End-to-end test was written to verify the full orchestration.
    # TDD GREEN: Invoke-DatabaseSeed was implemented to tie everything together.

    BeforeAll {
        $script:testDb = Join-Path $TestDrive 'integration_test.db'
        $script:result = Invoke-DatabaseSeed -DatabasePath $script:testDb -Seed 42 -UserCount 10 -ProductCount 15 -OrderCount 25
    }

    It 'Should create the database file' {
        $script:testDb | Should -Exist
    }

    It 'Should return verification results' {
        $script:result | Should -Not -BeNullOrEmpty
    }

    It 'Should have all data counts correct' {
        $script:result.UserCount | Should -Be 10
        $script:result.ProductCount | Should -Be 15
        $script:result.OrderCount | Should -Be 25
    }

    It 'Should have zero integrity violations' {
        $script:result.OrphanUserOrders | Should -Be 0
        $script:result.OrphanProductOrders | Should -Be 0
        $script:result.InvalidPriceOrders | Should -Be 0
        $script:result.InvalidStatusOrders | Should -Be 0
        $script:result.DuplicateUsernames | Should -Be 0
        $script:result.DuplicateEmails | Should -Be 0
    }

    It 'Should produce the same results when run again with the same seed' {
        $testDb2 = Join-Path $TestDrive 'integration_test2.db'
        $result2 = Invoke-DatabaseSeed -DatabasePath $testDb2 -Seed 42 -UserCount 10 -ProductCount 15 -OrderCount 25

        $result2.UserCount | Should -Be $script:result.UserCount
        $result2.ProductCount | Should -Be $script:result.ProductCount
        $result2.OrderCount | Should -Be $script:result.OrderCount
        $result2.TotalRevenue | Should -Be $script:result.TotalRevenue
        $result2.AverageOrderValue | Should -Be $script:result.AverageOrderValue
    }

    It 'Should produce different results with a different seed' {
        $testDb3 = Join-Path $TestDrive 'integration_test3.db'
        $result3 = Invoke-DatabaseSeed -DatabasePath $testDb3 -Seed 99 -UserCount 10 -ProductCount 15 -OrderCount 25

        # The total revenue should differ with a different seed (different products/orders)
        $result3.TotalRevenue | Should -Not -Be $script:result.TotalRevenue
    }
}

Describe 'Error Handling' {
    # TDD RED: Tests were written to verify graceful error handling.
    # TDD GREEN: Error handling was added to each function.

    It 'Should throw meaningful error for invalid database path in schema creation' {
        { New-DatabaseSchema -DatabasePath '/nonexistent/path/db.sqlite' } | Should -Throw -ExpectedMessage '*Failed to create*'
    }

    It 'Should throw meaningful error for invalid database path in data import' {
        $users = New-MockUsers -Seed 1 -Count 1
        $products = New-MockProducts -Seed 2 -Count 1
        $orders = New-MockOrders -Seed 3 -UserCount 1 -ProductCount 1 -Products $products -Count 1
        { Import-MockData -DatabasePath '/nonexistent/path/db.sqlite' -Users $users -Products $products -Orders $orders } | Should -Throw -ExpectedMessage '*Failed to insert*'
    }

    It 'Should throw meaningful error for verification on non-existent database' {
        { Test-DataConsistency -DatabasePath '/nonexistent/path/db.sqlite' } | Should -Throw -ExpectedMessage '*Failed to run verification*'
    }

    It 'Should handle zero count for users without error' {
        # Empty array may unwrap to $null in PowerShell pipeline
        { $null = New-MockUsers -Seed 42 -Count 0 } | Should -Not -Throw
    }

    It 'Should handle zero count for products without error' {
        { $null = New-MockProducts -Seed 42 -Count 0 } | Should -Not -Throw
    }
}
