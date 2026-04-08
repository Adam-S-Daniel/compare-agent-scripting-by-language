# DatabaseSeed.ps1 - SQLite database seed script with deterministic data generation
# Strict mode enforced throughout

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module PSSQLite -ErrorAction Stop

<#
.SYNOPSIS
    Creates the database schema with users, products, and orders tables.
.DESCRIPTION
    Initializes a SQLite database with three tables linked by foreign keys.
    Foreign key enforcement is enabled via PRAGMA.
#>
function Initialize-Database {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    # Enable foreign key enforcement
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "PRAGMA foreign_keys = ON;"

    # Create users table with unique constraints on username and email
    [string]$usersSql = @"
        CREATE TABLE IF NOT EXISTS users (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            username    TEXT    NOT NULL UNIQUE,
            email       TEXT    NOT NULL UNIQUE,
            first_name  TEXT    NOT NULL,
            last_name   TEXT    NOT NULL,
            created_at  TEXT    NOT NULL
        );
"@
    Invoke-SqliteQuery -DataSource $DatabasePath -Query $usersSql

    # Create products table
    [string]$productsSql = @"
        CREATE TABLE IF NOT EXISTS products (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            name            TEXT    NOT NULL,
            description     TEXT    NOT NULL,
            price           REAL    NOT NULL CHECK(price > 0),
            stock_quantity  INTEGER NOT NULL CHECK(stock_quantity >= 0),
            category        TEXT    NOT NULL
        );
"@
    Invoke-SqliteQuery -DataSource $DatabasePath -Query $productsSql

    # Create orders table with foreign keys to users and products
    [string]$ordersSql = @"
        CREATE TABLE IF NOT EXISTS orders (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL,
            product_id  INTEGER NOT NULL,
            quantity    INTEGER NOT NULL CHECK(quantity > 0),
            total_price REAL    NOT NULL CHECK(total_price > 0),
            order_date  TEXT    NOT NULL,
            status      TEXT    NOT NULL CHECK(status IN ('pending', 'shipped', 'delivered', 'cancelled')),
            FOREIGN KEY (user_id)    REFERENCES users(id),
            FOREIGN KEY (product_id) REFERENCES products(id)
        );
"@
    Invoke-SqliteQuery -DataSource $DatabasePath -Query $ordersSql
}

# --- Deterministic mock data generation using seeded System.Random ---

# Realistic name/data pools for generating mock records
[string[]]$script:FirstNames = @(
    'Alice', 'Bob', 'Charlie', 'Diana', 'Edward', 'Fiona', 'George', 'Hannah',
    'Ivan', 'Julia', 'Kevin', 'Laura', 'Michael', 'Nina', 'Oscar', 'Patricia',
    'Quentin', 'Rachel', 'Samuel', 'Teresa', 'Ulysses', 'Victoria', 'William',
    'Xena', 'Yuri', 'Zara'
)

[string[]]$script:LastNames = @(
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
    'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson',
    'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson',
    'White', 'Harris', 'Sanchez'
)

[string[]]$script:EmailDomains = @(
    'example.com', 'testmail.org', 'mockdata.net', 'sample.io', 'demo.dev'
)

[string[]]$script:ProductNames = @(
    'Widget', 'Gadget', 'Sprocket', 'Gizmo', 'Doohickey', 'Thingamajig',
    'Contraption', 'Apparatus', 'Device', 'Mechanism', 'Instrument', 'Component'
)

[string[]]$script:ProductAdjectives = @(
    'Premium', 'Basic', 'Deluxe', 'Standard', 'Professional', 'Ultra',
    'Mini', 'Mega', 'Advanced', 'Classic', 'Pro', 'Elite'
)

[string[]]$script:Categories = @(
    'Electronics', 'Home & Garden', 'Sports', 'Books', 'Clothing',
    'Toys', 'Health', 'Automotive'
)

[string[]]$script:OrderStatuses = @('pending', 'shipped', 'delivered', 'cancelled')

<#
.SYNOPSIS
    Generates deterministic mock user data using a seeded RNG.
#>
function New-MockUsers {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [Parameter(Mandatory)]
        [int]$Count
    )

    [System.Random]$rng = [System.Random]::new($Seed)
    [hashtable[]]$users = @()

    # Track used usernames/emails to guarantee uniqueness
    [System.Collections.Generic.HashSet[string]]$usedUsernames = [System.Collections.Generic.HashSet[string]]::new()
    [System.Collections.Generic.HashSet[string]]$usedEmails = [System.Collections.Generic.HashSet[string]]::new()

    for ([int]$i = 0; $i -lt $Count; $i++) {
        # Generate a unique username by appending an index suffix
        [string]$firstName = $script:FirstNames[$rng.Next($script:FirstNames.Count)]
        [string]$lastName = $script:LastNames[$rng.Next($script:LastNames.Count)]
        [string]$domain = $script:EmailDomains[$rng.Next($script:EmailDomains.Count)]

        [string]$baseUsername = "$($firstName.ToLower()).$($lastName.ToLower())"
        [string]$username = $baseUsername
        [int]$suffix = $rng.Next(100, 999)

        # Ensure uniqueness by appending suffix
        $username = "${baseUsername}${suffix}"
        while (-not $usedUsernames.Add($username)) {
            $suffix = $rng.Next(100, 9999)
            $username = "${baseUsername}${suffix}"
        }

        [string]$email = "${username}@${domain}"
        while (-not $usedEmails.Add($email)) {
            $domain = $script:EmailDomains[$rng.Next($script:EmailDomains.Count)]
            $email = "${username}@${domain}"
        }

        # Generate a random creation date within the past two years
        [int]$daysBack = $rng.Next(1, 730)
        [string]$createdAt = ([datetime]::new(2025, 1, 1)).AddDays(-$daysBack).ToString('yyyy-MM-dd')

        $users += @{
            username   = $username
            email      = $email
            first_name = $firstName
            last_name  = $lastName
            created_at = $createdAt
        }
    }

    return $users
}

<#
.SYNOPSIS
    Generates deterministic mock product data using a seeded RNG.
#>
function New-MockProducts {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [Parameter(Mandatory)]
        [int]$Count
    )

    [System.Random]$rng = [System.Random]::new($Seed)
    [hashtable[]]$products = @()

    for ([int]$i = 0; $i -lt $Count; $i++) {
        [string]$adjective = $script:ProductAdjectives[$rng.Next($script:ProductAdjectives.Count)]
        [string]$baseName = $script:ProductNames[$rng.Next($script:ProductNames.Count)]
        [string]$category = $script:Categories[$rng.Next($script:Categories.Count)]

        # Price between $1.99 and $999.99, rounded to 2 decimal places
        [double]$price = [math]::Round($rng.NextDouble() * 998.0 + 1.99, 2)
        [int]$stockQuantity = $rng.Next(0, 500)

        $products += @{
            name           = "$adjective $baseName"
            description    = "A high-quality $($adjective.ToLower()) $($baseName.ToLower()) for $($category.ToLower()) use."
            price          = $price
            stock_quantity = $stockQuantity
            category       = $category
        }
    }

    return $products
}

<#
.SYNOPSIS
    Generates deterministic mock order data using a seeded RNG.
.DESCRIPTION
    Order user_id and product_id reference valid IDs (1..UserCount, 1..ProductCount).
#>
function New-MockOrders {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [Parameter(Mandatory)]
        [int]$UserCount,

        [Parameter(Mandatory)]
        [int]$ProductCount,

        [Parameter(Mandatory)]
        [int]$Count
    )

    [System.Random]$rng = [System.Random]::new($Seed)
    [hashtable[]]$orders = @()

    for ([int]$i = 0; $i -lt $Count; $i++) {
        [int]$userId = $rng.Next(1, $UserCount + 1)
        [int]$productId = $rng.Next(1, $ProductCount + 1)
        [int]$quantity = $rng.Next(1, 10)

        # Generate a price per unit between $5 and $500
        [double]$unitPrice = [math]::Round($rng.NextDouble() * 495.0 + 5.0, 2)
        [double]$totalPrice = [math]::Round($unitPrice * [double]$quantity, 2)

        [int]$daysBack = $rng.Next(1, 365)
        [string]$orderDate = ([datetime]::new(2025, 6, 1)).AddDays(-$daysBack).ToString('yyyy-MM-dd')

        [string]$status = $script:OrderStatuses[$rng.Next($script:OrderStatuses.Count)]

        $orders += @{
            user_id     = $userId
            product_id  = $productId
            quantity    = $quantity
            total_price = $totalPrice
            order_date  = $orderDate
            status      = $status
        }
    }

    return $orders
}

# --- Data insertion functions ---

<#
.SYNOPSIS
    Inserts generated user records into the database.
#>
function Import-MockUsers {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [hashtable[]]$Users
    )

    foreach ($user in $Users) {
        [string]$query = @"
            INSERT INTO users (username, email, first_name, last_name, created_at)
            VALUES (@username, @email, @first_name, @last_name, @created_at);
"@
        Invoke-SqliteQuery -DataSource $DatabasePath -Query $query -SqlParameters @{
            username   = [string]$user.username
            email      = [string]$user.email
            first_name = [string]$user.first_name
            last_name  = [string]$user.last_name
            created_at = [string]$user.created_at
        }
    }
}

<#
.SYNOPSIS
    Inserts generated product records into the database.
#>
function Import-MockProducts {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [hashtable[]]$Products
    )

    foreach ($product in $Products) {
        [string]$query = @"
            INSERT INTO products (name, description, price, stock_quantity, category)
            VALUES (@name, @description, @price, @stock_quantity, @category);
"@
        Invoke-SqliteQuery -DataSource $DatabasePath -Query $query -SqlParameters @{
            name           = [string]$product.name
            description    = [string]$product.description
            price          = [double]$product.price
            stock_quantity = [int]$product.stock_quantity
            category       = [string]$product.category
        }
    }
}

<#
.SYNOPSIS
    Inserts generated order records into the database.
#>
function Import-MockOrders {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [hashtable[]]$Orders
    )

    foreach ($order in $Orders) {
        [string]$query = @"
            INSERT INTO orders (user_id, product_id, quantity, total_price, order_date, status)
            VALUES (@user_id, @product_id, @quantity, @total_price, @order_date, @status);
"@
        Invoke-SqliteQuery -DataSource $DatabasePath -Query $query -SqlParameters @{
            user_id     = [int]$order.user_id
            product_id  = [int]$order.product_id
            quantity    = [int]$order.quantity
            total_price = [double]$order.total_price
            order_date  = [string]$order.order_date
            status      = [string]$order.status
        }
    }
}

<#
.SYNOPSIS
    Orchestrates the full database seed pipeline: schema + data generation + insertion.
.DESCRIPTION
    Creates the schema, generates deterministic mock data, inserts it, and returns counts.
#>
function Invoke-DatabaseSeed {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [int]$Seed,

        [int]$UserCount = 20,

        [int]$ProductCount = 15,

        [int]$OrderCount = 50
    )

    # Step 1: Create schema
    Initialize-Database -DatabasePath $DatabasePath

    # Step 2: Generate deterministic data
    [hashtable[]]$users = New-MockUsers -Seed $Seed -Count $UserCount
    [hashtable[]]$products = New-MockProducts -Seed ($Seed + 1) -Count $ProductCount
    [hashtable[]]$orders = New-MockOrders -Seed ($Seed + 2) -UserCount $UserCount -ProductCount $ProductCount -Count $OrderCount

    # Step 3: Insert data respecting referential integrity (users & products before orders)
    Import-MockUsers -DatabasePath $DatabasePath -Users $users
    Import-MockProducts -DatabasePath $DatabasePath -Products $products
    Import-MockOrders -DatabasePath $DatabasePath -Orders $orders

    return @{
        Users    = $UserCount
        Products = $ProductCount
        Orders   = $OrderCount
    }
}

# --- Verification query functions ---

<#
.SYNOPSIS
    Returns row counts for all three tables.
#>
function Get-TableCounts {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    $uCount = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) AS cnt FROM users;"
    $pCount = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) AS cnt FROM products;"
    $oCount = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) AS cnt FROM orders;"

    return @{
        users    = [int]$uCount.cnt
        products = [int]$pCount.cnt
        orders   = [int]$oCount.cnt
    }
}

<#
.SYNOPSIS
    Checks for orphaned foreign key references in the orders table.
#>
function Test-ReferentialIntegrity {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    $orphanedUsers = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
        SELECT COUNT(*) AS cnt FROM orders
        WHERE user_id NOT IN (SELECT id FROM users);
"@

    $orphanedProducts = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
        SELECT COUNT(*) AS cnt FROM orders
        WHERE product_id NOT IN (SELECT id FROM products);
"@

    return @{
        OrphanedUserOrders    = [int]$orphanedUsers.cnt
        OrphanedProductOrders = [int]$orphanedProducts.cnt
    }
}

<#
.SYNOPSIS
    Computes aggregate order statistics: total revenue, average, and breakdown by status.
#>
function Get-OrderStatistics {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    $totals = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
        SELECT SUM(total_price) AS total_revenue, AVG(total_price) AS avg_order FROM orders;
"@

    $statusRows = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
        SELECT status, COUNT(*) AS cnt FROM orders GROUP BY status;
"@

    [hashtable]$ordersByStatus = @{}
    foreach ($row in $statusRows) {
        $ordersByStatus[[string]$row.status] = [int]$row.cnt
    }

    return @{
        TotalRevenue      = [double]$totals.total_revenue
        AverageOrderValue = [double]$totals.avg_order
        OrdersByStatus    = $ordersByStatus
    }
}

<#
.SYNOPSIS
    Returns top customers ranked by number of orders placed.
#>
function Get-TopCustomers {
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [int]$Limit = 5
    )

    [string]$query = @"
        SELECT u.id, u.username, u.email, COUNT(o.id) AS order_count
        FROM users u
        INNER JOIN orders o ON o.user_id = u.id
        GROUP BY u.id
        ORDER BY order_count DESC
        LIMIT @limit;
"@

    $results = Invoke-SqliteQuery -DataSource $DatabasePath -Query $query -SqlParameters @{ limit = $Limit }
    return @($results)
}

<#
.SYNOPSIS
    Returns per-product sales totals: quantity sold and revenue generated.
#>
function Get-ProductSalesSummary {
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    [string]$query = @"
        SELECT p.name AS product_name, SUM(o.quantity) AS total_quantity, SUM(o.total_price) AS total_revenue
        FROM products p
        INNER JOIN orders o ON o.product_id = p.id
        GROUP BY p.id
        ORDER BY total_revenue DESC;
"@

    $results = Invoke-SqliteQuery -DataSource $DatabasePath -Query $query
    return @($results)
}

<#
.SYNOPSIS
    Runs all verification queries and returns a consolidated report.
#>
function Invoke-VerificationQueries {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    [hashtable]$tableCounts = Get-TableCounts -DatabasePath $DatabasePath
    [hashtable]$integrity = Test-ReferentialIntegrity -DatabasePath $DatabasePath
    [hashtable]$statistics = Get-OrderStatistics -DatabasePath $DatabasePath
    [array]$topCustomers = Get-TopCustomers -DatabasePath $DatabasePath -Limit 5
    [array]$productSales = Get-ProductSalesSummary -DatabasePath $DatabasePath

    return @{
        TableCounts  = $tableCounts
        Integrity    = $integrity
        Statistics   = $statistics
        TopCustomers = $topCustomers
        ProductSales = $productSales
    }
}
