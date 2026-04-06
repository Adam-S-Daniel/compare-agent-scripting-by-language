# DatabaseSeed.ps1 - SQLite database seed script with deterministic mock data
# Uses System.Data.SQLite via the PSSQLite module for database operations
# Implements seeded RNG for reproducible test data generation

# Ensure PSSQLite module is available
if (-not (Get-Module -ListAvailable PSSQLite)) {
    Install-Module -Name PSSQLite -Force -Scope CurrentUser -AllowClobber
}
Import-Module PSSQLite -ErrorAction Stop

<#
.SYNOPSIS
    Creates the SQLite database schema with users, products, and orders tables.
.DESCRIPTION
    Sets up three tables with proper foreign key relationships:
    - users: stores customer information
    - products: stores product catalog
    - orders: references both users and products via foreign keys
.PARAMETER DatabasePath
    Path to the SQLite database file.
#>
function New-DatabaseSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    try {
        # Enable foreign key enforcement
        Invoke-SqliteQuery -DataSource $DatabasePath -Query "PRAGMA foreign_keys = ON;"

        # Create users table
        $usersSQL = @"
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"@
        Invoke-SqliteQuery -DataSource $DatabasePath -Query $usersSQL

        # Create products table
        $productsSQL = @"
CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    price REAL NOT NULL CHECK(price > 0),
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK(stock_quantity >= 0),
    category TEXT NOT NULL
);
"@
        Invoke-SqliteQuery -DataSource $DatabasePath -Query $productsSQL

        # Create orders table with foreign keys to users and products
        $ordersSQL = @"
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    total_price REAL NOT NULL CHECK(total_price > 0),
    order_date TEXT NOT NULL DEFAULT (datetime('now')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);
"@
        Invoke-SqliteQuery -DataSource $DatabasePath -Query $ordersSQL

        Write-Verbose "Database schema created successfully at $DatabasePath"
    }
    catch {
        throw "Failed to create database schema: $_"
    }
}

<#
.SYNOPSIS
    Generates deterministic mock user data using a seeded random number generator.
.PARAMETER Seed
    The seed value for reproducible random generation.
.PARAMETER Count
    Number of users to generate.
#>
function New-MockUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [int]$Count = 10
    )

    $rng = [System.Random]::new($Seed)

    $firstNames = @('Alice', 'Bob', 'Charlie', 'Diana', 'Edward',
                     'Fiona', 'George', 'Hannah', 'Ivan', 'Julia',
                     'Kevin', 'Laura', 'Michael', 'Nancy', 'Oscar',
                     'Patricia', 'Quentin', 'Rachel', 'Samuel', 'Tina')

    $lastNames = @('Smith', 'Johnson', 'Williams', 'Brown', 'Jones',
                    'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
                    'Anderson', 'Taylor', 'Thomas', 'Jackson', 'White',
                    'Harris', 'Martin', 'Thompson', 'Moore', 'Clark')

    $domains = @('example.com', 'testmail.org', 'mockmail.net', 'sample.io', 'demo.dev')

    $users = [System.Collections.ArrayList]::new()

    # Track used usernames and emails to ensure uniqueness
    $usedUsernames = @{}
    $usedEmails = @{}

    for ($i = 0; $i -lt $Count; $i++) {
        $firstName = $firstNames[$rng.Next($firstNames.Length)]
        $lastName = $lastNames[$rng.Next($lastNames.Length)]
        $domain = $domains[$rng.Next($domains.Length)]

        # Generate unique username by appending index if needed
        $baseUsername = "$($firstName.ToLower()).$($lastName.ToLower())"
        $username = $baseUsername
        $suffix = 1
        while ($usedUsernames.ContainsKey($username)) {
            $username = "${baseUsername}${suffix}"
            $suffix++
        }
        $usedUsernames[$username] = $true

        # Generate unique email
        $baseEmail = "${username}@${domain}"
        $email = $baseEmail
        $emailSuffix = 1
        while ($usedEmails.ContainsKey($email)) {
            $email = "${username}${emailSuffix}@${domain}"
            $emailSuffix++
        }
        $usedEmails[$email] = $true

        # Generate a deterministic created_at date (within 2024)
        $dayOffset = $rng.Next(0, 365)
        $createdAt = [datetime]::new(2024, 1, 1).AddDays($dayOffset).ToString('yyyy-MM-dd HH:mm:ss')

        $null = $users.Add([PSCustomObject]@{
            username   = $username
            email      = $email
            first_name = $firstName
            last_name  = $lastName
            created_at = $createdAt
        })
    }

    return $users.ToArray()
}

<#
.SYNOPSIS
    Generates deterministic mock product data using a seeded random number generator.
.PARAMETER Seed
    The seed value for reproducible random generation.
.PARAMETER Count
    Number of products to generate.
#>
function New-MockProducts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [int]$Count = 15
    )

    $rng = [System.Random]::new($Seed)

    $categories = @('Electronics', 'Books', 'Clothing', 'Home & Garden', 'Sports')

    $productTemplates = @{
        'Electronics' = @('Wireless Mouse', 'USB-C Hub', 'Bluetooth Speaker', 'LED Monitor',
                          'Mechanical Keyboard', 'Webcam HD', 'Power Bank', 'Smart Watch')
        'Books'       = @('Python Cookbook', 'Design Patterns', 'Clean Code', 'The Pragmatic Programmer',
                          'Data Science Handbook', 'SQL Deep Dive', 'Algorithms Guide', 'DevOps Manual')
        'Clothing'    = @('Cotton T-Shirt', 'Denim Jacket', 'Running Shoes', 'Wool Sweater',
                          'Cargo Pants', 'Baseball Cap', 'Leather Belt', 'Silk Scarf')
        'Home & Garden' = @('Plant Pot Set', 'LED Desk Lamp', 'Throw Pillow', 'Wall Clock',
                            'Garden Hose', 'Candle Set', 'Door Mat', 'Picture Frame')
        'Sports'      = @('Yoga Mat', 'Resistance Bands', 'Water Bottle', 'Jump Rope',
                          'Tennis Racket', 'Basketball', 'Cycling Gloves', 'Foam Roller')
    }

    $descriptions = @(
        'High quality product with excellent reviews.',
        'Best seller in its category.',
        'Premium grade materials used.',
        'Customer favorite with 4+ star rating.',
        'New arrival with competitive pricing.',
        'Eco-friendly and sustainably sourced.',
        'Professional grade equipment.',
        'Great value for everyday use.'
    )

    $products = [System.Collections.ArrayList]::new()
    $usedNames = @{}

    for ($i = 0; $i -lt $Count; $i++) {
        $category = $categories[$rng.Next($categories.Length)]
        $templateList = $productTemplates[$category]
        $baseName = $templateList[$rng.Next($templateList.Length)]

        # Ensure unique product names
        $name = $baseName
        $suffix = 2
        while ($usedNames.ContainsKey($name)) {
            $name = "$baseName v$suffix"
            $suffix++
        }
        $usedNames[$name] = $true

        $description = $descriptions[$rng.Next($descriptions.Length)]
        # Price between 5.00 and 500.00, rounded to 2 decimal places
        $price = [math]::Round($rng.NextDouble() * 495 + 5, 2)
        $stockQuantity = $rng.Next(0, 200)

        $null = $products.Add([PSCustomObject]@{
            name           = $name
            description    = $description
            price          = $price
            stock_quantity = $stockQuantity
            category       = $category
        })
    }

    return $products.ToArray()
}

<#
.SYNOPSIS
    Generates deterministic mock order data using a seeded random number generator.
.PARAMETER Seed
    The seed value for reproducible random generation.
.PARAMETER UserCount
    Number of users available to reference.
.PARAMETER ProductCount
    Number of products available to reference.
.PARAMETER Products
    The product data array (for price lookup).
.PARAMETER Count
    Number of orders to generate.
#>
function New-MockOrders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [Parameter(Mandatory)]
        [int]$UserCount,

        [Parameter(Mandatory)]
        [int]$ProductCount,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Products,

        [int]$Count = 25
    )

    $rng = [System.Random]::new($Seed)
    $statuses = @('pending', 'processing', 'shipped', 'delivered', 'cancelled')

    $orders = [System.Collections.ArrayList]::new()

    for ($i = 0; $i -lt $Count; $i++) {
        # user_id and product_id are 1-based (AUTOINCREMENT starts at 1)
        $userId = $rng.Next(1, $UserCount + 1)
        $productId = $rng.Next(1, $ProductCount + 1)
        $quantity = $rng.Next(1, 6)  # 1 to 5 items
        $productPrice = $Products[$productId - 1].price
        $totalPrice = [math]::Round($productPrice * $quantity, 2)
        $status = $statuses[$rng.Next($statuses.Length)]

        # Generate a deterministic order date (within 2024)
        $dayOffset = $rng.Next(0, 365)
        $orderDate = [datetime]::new(2024, 1, 1).AddDays($dayOffset).ToString('yyyy-MM-dd HH:mm:ss')

        $null = $orders.Add([PSCustomObject]@{
            user_id     = $userId
            product_id  = $productId
            quantity    = $quantity
            total_price = $totalPrice
            order_date  = $orderDate
            status      = $status
        })
    }

    return $orders.ToArray()
}

<#
.SYNOPSIS
    Inserts mock data into the database respecting referential integrity.
.DESCRIPTION
    Inserts users first, then products, then orders (which reference both).
.PARAMETER DatabasePath
    Path to the SQLite database file.
.PARAMETER Users
    Array of user objects to insert.
.PARAMETER Products
    Array of product objects to insert.
.PARAMETER Orders
    Array of order objects to insert.
#>
function Import-MockData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Users,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Products,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Orders
    )

    try {
        # Enable foreign keys
        Invoke-SqliteQuery -DataSource $DatabasePath -Query "PRAGMA foreign_keys = ON;"

        # Insert users first (no dependencies)
        foreach ($user in $Users) {
            $query = @"
INSERT INTO users (username, email, first_name, last_name, created_at)
VALUES (@username, @email, @first_name, @last_name, @created_at);
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $query -SqlParameters @{
                username   = $user.username
                email      = $user.email
                first_name = $user.first_name
                last_name  = $user.last_name
                created_at = $user.created_at
            }
        }

        # Insert products second (no dependencies)
        foreach ($product in $Products) {
            $query = @"
INSERT INTO products (name, description, price, stock_quantity, category)
VALUES (@name, @description, @price, @stock_quantity, @category);
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $query -SqlParameters @{
                name           = $product.name
                description    = $product.description
                price          = $product.price
                stock_quantity = [int]$product.stock_quantity
                category       = $product.category
            }
        }

        # Insert orders last (depends on users and products)
        foreach ($order in $Orders) {
            $query = @"
INSERT INTO orders (user_id, product_id, quantity, total_price, order_date, status)
VALUES (@user_id, @product_id, @quantity, @total_price, @order_date, @status);
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $query -SqlParameters @{
                user_id     = [int]$order.user_id
                product_id  = [int]$order.product_id
                quantity    = [int]$order.quantity
                total_price = $order.total_price
                order_date  = $order.order_date
                status      = $order.status
            }
        }

        Write-Verbose "Mock data inserted successfully."
    }
    catch {
        throw "Failed to insert mock data: $_"
    }
}

<#
.SYNOPSIS
    Runs verification queries to confirm data consistency.
.PARAMETER DatabasePath
    Path to the SQLite database file.
.RETURNS
    A hashtable containing verification results.
#>
function Test-DataConsistency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    try {
        Invoke-SqliteQuery -DataSource $DatabasePath -Query "PRAGMA foreign_keys = ON;"

        $results = @{}

        # Count records in each table
        $results.UserCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as cnt FROM users;").cnt
        $results.ProductCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as cnt FROM products;").cnt
        $results.OrderCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as cnt FROM orders;").cnt

        # Verify all order user_ids reference valid users
        $orphanUserOrders = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT COUNT(*) as cnt FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE u.id IS NULL;
"@
        $results.OrphanUserOrders = $orphanUserOrders.cnt

        # Verify all order product_ids reference valid products
        $orphanProductOrders = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT COUNT(*) as cnt FROM orders o
LEFT JOIN products p ON o.product_id = p.id
WHERE p.id IS NULL;
"@
        $results.OrphanProductOrders = $orphanProductOrders.cnt

        # Total revenue across all orders
        $results.TotalRevenue = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT ROUND(SUM(total_price), 2) as total FROM orders;").total

        # Average order value
        $results.AverageOrderValue = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT ROUND(AVG(total_price), 2) as avg_val FROM orders;").avg_val

        # Orders per status
        $statusRows = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT status, COUNT(*) as cnt FROM orders GROUP BY status ORDER BY status;"
        $results.OrdersByStatus = @{}
        foreach ($row in $statusRows) {
            $results.OrdersByStatus[$row.status] = $row.cnt
        }

        # Top spending users
        $results.TopSpenders = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT u.username, ROUND(SUM(o.total_price), 2) as total_spent, COUNT(o.id) as order_count
FROM users u
JOIN orders o ON u.id = o.user_id
GROUP BY u.id
ORDER BY total_spent DESC
LIMIT 5;
"@

        # Products by category with average price
        $results.CategoryStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT category, COUNT(*) as product_count, ROUND(AVG(price), 2) as avg_price
FROM products
GROUP BY category
ORDER BY category;
"@

        # Verify all orders have positive total_price
        $invalidPriceOrders = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as cnt FROM orders WHERE total_price <= 0;"
        $results.InvalidPriceOrders = $invalidPriceOrders.cnt

        # Verify all orders have valid statuses
        $invalidStatusOrders = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT COUNT(*) as cnt FROM orders
WHERE status NOT IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled');
"@
        $results.InvalidStatusOrders = $invalidStatusOrders.cnt

        # Verify unique usernames
        $duplicateUsernames = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT COUNT(*) as cnt FROM (
    SELECT username FROM users GROUP BY username HAVING COUNT(*) > 1
);
"@
        $results.DuplicateUsernames = $duplicateUsernames.cnt

        # Verify unique emails
        $duplicateEmails = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT COUNT(*) as cnt FROM (
    SELECT email FROM users GROUP BY email HAVING COUNT(*) > 1
);
"@
        $results.DuplicateEmails = $duplicateEmails.cnt

        return $results
    }
    catch {
        throw "Failed to run verification queries: $_"
    }
}

<#
.SYNOPSIS
    Orchestrates the full database seed process.
.PARAMETER DatabasePath
    Path to the SQLite database file.
.PARAMETER Seed
    Seed for deterministic RNG (default: 42).
.PARAMETER UserCount
    Number of users to generate.
.PARAMETER ProductCount
    Number of products to generate.
.PARAMETER OrderCount
    Number of orders to generate.
#>
function Invoke-DatabaseSeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [int]$Seed = 42,
        [int]$UserCount = 10,
        [int]$ProductCount = 15,
        [int]$OrderCount = 25
    )

    # Remove existing database to start fresh
    if (Test-Path $DatabasePath) {
        Remove-Item $DatabasePath -Force
    }

    Write-Host "Creating database schema..." -ForegroundColor Cyan
    New-DatabaseSchema -DatabasePath $DatabasePath

    Write-Host "Generating mock data (seed=$Seed)..." -ForegroundColor Cyan
    $users = New-MockUsers -Seed $Seed -Count $UserCount
    $products = New-MockProducts -Seed ($Seed + 1) -Count $ProductCount
    $orders = New-MockOrders -Seed ($Seed + 2) -UserCount $UserCount -ProductCount $ProductCount -Products $products -Count $OrderCount

    Write-Host "Inserting data..." -ForegroundColor Cyan
    Import-MockData -DatabasePath $DatabasePath -Users $users -Products $products -Orders $orders

    Write-Host "Running verification queries..." -ForegroundColor Cyan
    $verification = Test-DataConsistency -DatabasePath $DatabasePath

    Write-Host "`n=== Verification Results ===" -ForegroundColor Green
    Write-Host "Users: $($verification.UserCount)"
    Write-Host "Products: $($verification.ProductCount)"
    Write-Host "Orders: $($verification.OrderCount)"
    Write-Host "Orphan user orders: $($verification.OrphanUserOrders)"
    Write-Host "Orphan product orders: $($verification.OrphanProductOrders)"
    Write-Host "Total revenue: `$$($verification.TotalRevenue)"
    Write-Host "Average order value: `$$($verification.AverageOrderValue)"
    Write-Host "Invalid price orders: $($verification.InvalidPriceOrders)"
    Write-Host "Invalid status orders: $($verification.InvalidStatusOrders)"
    Write-Host "Duplicate usernames: $($verification.DuplicateUsernames)"
    Write-Host "Duplicate emails: $($verification.DuplicateEmails)"

    Write-Host "`nOrders by status:" -ForegroundColor Cyan
    foreach ($status in ($verification.OrdersByStatus.Keys | Sort-Object)) {
        Write-Host "  ${status}: $($verification.OrdersByStatus[$status])"
    }

    Write-Host "`nTop 5 spenders:" -ForegroundColor Cyan
    foreach ($spender in $verification.TopSpenders) {
        Write-Host "  $($spender.username): `$$($spender.total_spent) ($($spender.order_count) orders)"
    }

    return $verification
}
