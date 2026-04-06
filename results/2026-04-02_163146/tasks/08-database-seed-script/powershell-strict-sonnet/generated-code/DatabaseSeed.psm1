# DatabaseSeed.psm1
# SQLite database seed module — PowerShell strict mode
#
# Design:
#   - Every public function is CmdletBinding + typed params + OutputType
#   - Seeded RNG via [System.Random]::new([int]) for determinism
#   - PSSQLite module wraps SQLite; all SQL is parameterised to prevent injection
#   - Schema uses IF NOT EXISTS so Initialize-DatabaseSchema is idempotent
#   - Foreign keys are enforced at INSERT time (PRAGMA foreign_keys = ON)

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Private constants — realistic seed data pools
# ---------------------------------------------------------------------------
[string[]]$script:FirstNames = @(
    'Alice','Bob','Carol','David','Eve','Frank','Grace','Henry','Iris','Jack',
    'Karen','Liam','Maria','Noah','Olivia','Paul','Quinn','Rachel','Sam','Tina',
    'Uma','Victor','Wendy','Xander','Yara','Zoe','Aaron','Beth','Chris','Diana'
)

[string[]]$script:LastNames = @(
    'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Wilson',
    'Moore','Taylor','Anderson','Thomas','Jackson','White','Harris','Martin','Thompson',
    'Lee','Walker','Hall','Allen','Young','King','Wright','Scott','Green','Baker',
    'Adams','Nelson'
)

[string[]]$script:Domains = @(
    'gmail.com','yahoo.com','outlook.com','hotmail.com','proton.me',
    'icloud.com','example.com','mail.com','inbox.com','live.com'
)

[string[]]$script:ProductCategories = @(
    'Electronics','Clothing','Books','Home & Garden','Sports & Outdoors',
    'Toys & Games','Health & Beauty','Automotive','Office Supplies','Food & Beverage'
)

[string[]]$script:ProductAdjectives = @(
    'Premium','Deluxe','Standard','Compact','Professional','Essential',
    'Ultra','Advanced','Classic','Smart','Portable','Heavy-Duty'
)

[string[]]$script:ProductNouns = @(
    'Widget','Gadget','Tool','Kit','Set','Pack','Bundle','System',
    'Device','Module','Unit','Component','Accessory','Adapter','Connector'
)

[string[]]$script:OrderStatuses = @(
    'pending','processing','shipped','delivered','cancelled'
)

# Weighted status probabilities (index maps to $OrderStatuses)
# delivered=40%, shipped=25%, processing=15%, pending=10%, cancelled=10%
[int[]]$script:StatusWeights = @(10, 15, 25, 40, 10)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

function Get-WeightedRandom {
    <#
    .SYNOPSIS
        Selects an index from an array using weighted probability.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][System.Random]$Rng,
        [Parameter(Mandatory)][int[]]$Weights
    )

    [int]$total = 0
    foreach ($w in $Weights) { $total += $w }
    [int]$roll = $Rng.Next(0, $total)
    [int]$cumulative = 0
    for ([int]$i = 0; $i -lt $Weights.Length; $i++) {
        $cumulative += $Weights[$i]
        if ($roll -lt $cumulative) { return $i }
    }
    return $Weights.Length - 1
}

function Format-IsoDate {
    <#
    .SYNOPSIS
        Returns a random ISO-8601 date between two DateTime values.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][System.Random]$Rng,
        [Parameter(Mandatory)][datetime]$MinDate,
        [Parameter(Mandatory)][datetime]$MaxDate
    )

    [long]$rangeTicks = ($MaxDate - $MinDate).Ticks
    [long]$offsetTicks = [long]([double]$rangeTicks * $Rng.NextDouble())
    [datetime]$result = $MinDate.AddTicks($offsetTicks)
    return $result.ToString('yyyy-MM-dd HH:mm:ss')
}

# ---------------------------------------------------------------------------
# Public: Initialize-DatabaseSchema
# ---------------------------------------------------------------------------
function Initialize-DatabaseSchema {
    <#
    .SYNOPSIS
        Creates users, products, and orders tables in a SQLite database.
    .DESCRIPTION
        Idempotent — uses IF NOT EXISTS. Enforces foreign keys via PRAGMA.
    .PARAMETER DatabasePath
        Full path to the SQLite database file (created if absent).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][string]$DatabasePath
    )

    # Enable FK enforcement for this connection
    Invoke-SqliteQuery -DataSource $DatabasePath -Query 'PRAGMA foreign_keys = ON' | Out-Null

    # --- users ---
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
CREATE TABLE IF NOT EXISTS users (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    username   TEXT    NOT NULL UNIQUE,
    email      TEXT    NOT NULL UNIQUE,
    full_name  TEXT    NOT NULL,
    created_at TEXT    NOT NULL,
    is_active  INTEGER NOT NULL DEFAULT 1
)
'@ | Out-Null

    # --- products ---
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
CREATE TABLE IF NOT EXISTS products (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    name           TEXT    NOT NULL,
    description    TEXT,
    price          REAL    NOT NULL CHECK (price >= 0),
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    category       TEXT    NOT NULL,
    created_at     TEXT    NOT NULL
)
'@ | Out-Null

    # --- orders ---
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
CREATE TABLE IF NOT EXISTS orders (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id     INTEGER NOT NULL,
    product_id  INTEGER NOT NULL,
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    unit_price  REAL    NOT NULL,
    total_price REAL    NOT NULL,
    status      TEXT    NOT NULL DEFAULT 'pending',
    order_date  TEXT    NOT NULL,
    FOREIGN KEY (user_id)    REFERENCES users(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
)
'@ | Out-Null

    # Indexes for FK columns (performance)
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
CREATE INDEX IF NOT EXISTS idx_orders_user_id    ON orders(user_id)
'@ | Out-Null

    Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
CREATE INDEX IF NOT EXISTS idx_orders_product_id ON orders(product_id)
'@ | Out-Null
}

# ---------------------------------------------------------------------------
# Public: New-MockUsers
# ---------------------------------------------------------------------------
function New-MockUsers {
    <#
    .SYNOPSIS
        Generates deterministic mock user records.
    .PARAMETER Count
        Number of users to generate.
    .PARAMETER Seed
        RNG seed for reproducibility.
    .OUTPUTS
        Array of hashtables, each containing username, email, full_name,
        created_at, is_active.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][int]$Seed
    )

    [System.Random]$rng = [System.Random]::new($Seed)
    [datetime]$minDate  = [datetime]::new(2018, 1, 1)
    [datetime]$maxDate  = [datetime]::new(2024, 12, 31)

    [System.Collections.Generic.List[hashtable]]$users =
        [System.Collections.Generic.List[hashtable]]::new()
    [System.Collections.Generic.HashSet[string]]$usedUsernames =
        [System.Collections.Generic.HashSet[string]]::new()

    [int]$generated = 0
    [int]$attempts  = 0
    [int]$maxAttempts = $Count * 20  # prevent infinite loop

    while ($generated -lt $Count -and $attempts -lt $maxAttempts) {
        $attempts++

        [string]$first  = $script:FirstNames[$rng.Next(0, $script:FirstNames.Length)]
        [string]$last   = $script:LastNames[$rng.Next(0, $script:LastNames.Length)]
        [string]$suffix = [string]$rng.Next(1, 9999)
        [string]$username = ($first.ToLower() + '.' + $last.ToLower() + $suffix)

        if ($usedUsernames.Contains($username)) { continue }
        [void]$usedUsernames.Add($username)

        [string]$domain   = $script:Domains[$rng.Next(0, $script:Domains.Length)]
        [string]$email    = $username + '@' + $domain
        [string]$fullName = $first + ' ' + $last
        [string]$createdAt = Format-IsoDate -Rng $rng -MinDate $minDate -MaxDate $maxDate
        [int]$isActive    = if ($rng.NextDouble() -gt 0.15) { 1 } else { 0 }

        [void]$users.Add(@{
            username   = $username
            email      = $email
            full_name  = $fullName
            created_at = $createdAt
            is_active  = $isActive
        })
        $generated++
    }

    if ($generated -lt $Count) {
        throw "Could not generate $Count unique users (only generated $generated after $attempts attempts)"
    }

    return [hashtable[]]$users.ToArray()
}

# ---------------------------------------------------------------------------
# Public: New-MockProducts
# ---------------------------------------------------------------------------
function New-MockProducts {
    <#
    .SYNOPSIS
        Generates deterministic mock product records.
    .PARAMETER Count
        Number of products to generate.
    .PARAMETER Seed
        RNG seed for reproducibility.
    .OUTPUTS
        Array of hashtables with name, description, price, stock_quantity,
        category, created_at.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][int]$Seed
    )

    [System.Random]$rng = [System.Random]::new($Seed)
    [datetime]$minDate  = [datetime]::new(2020, 1, 1)
    [datetime]$maxDate  = [datetime]::new(2024, 12, 31)

    [System.Collections.Generic.List[hashtable]]$products =
        [System.Collections.Generic.List[hashtable]]::new()

    for ([int]$i = 0; $i -lt $Count; $i++) {
        [string]$adj      = $script:ProductAdjectives[$rng.Next(0, $script:ProductAdjectives.Length)]
        [string]$noun     = $script:ProductNouns[$rng.Next(0, $script:ProductNouns.Length)]
        [string]$name     = "$adj $noun $(($i + 1))"
        [string]$category = $script:ProductCategories[$rng.Next(0, $script:ProductCategories.Length)]

        # Price between 1.99 and 999.99, rounded to 2 dp
        [double]$price = [System.Math]::Round(1.99 + $rng.NextDouble() * 998.0, 2)

        [int]$stock     = $rng.Next(0, 501)
        [string]$desc   = "$adj $category $noun suitable for everyday use."
        [string]$created = Format-IsoDate -Rng $rng -MinDate $minDate -MaxDate $maxDate

        [void]$products.Add(@{
            name           = $name
            description    = $desc
            price          = $price
            stock_quantity = $stock
            category       = $category
            created_at     = $created
        })
    }

    return [hashtable[]]$products.ToArray()
}

# ---------------------------------------------------------------------------
# Public: New-MockOrders
# ---------------------------------------------------------------------------
function New-MockOrders {
    <#
    .SYNOPSIS
        Generates deterministic mock order records that reference valid
        user and product IDs.
    .PARAMETER Count
        Number of orders to generate.
    .PARAMETER Seed
        RNG seed for reproducibility.
    .PARAMETER UserIds
        Array of valid user IDs to reference (must be non-empty).
    .PARAMETER ProductIds
        Array of valid product IDs to reference (must be non-empty).
    .OUTPUTS
        Array of hashtables with user_id, product_id, quantity, unit_price,
        total_price, status, order_date.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][int]$Seed,
        [Parameter(Mandatory)][int[]]$UserIds,
        [Parameter(Mandatory)][int[]]$ProductIds
    )

    if ($UserIds.Length -eq 0)    { throw 'UserIds must not be empty' }
    if ($ProductIds.Length -eq 0) { throw 'ProductIds must not be empty' }

    [System.Random]$rng = [System.Random]::new($Seed)
    [datetime]$minDate  = [datetime]::new(2021, 1, 1)
    [datetime]$maxDate  = [datetime]::new(2025, 3, 31)

    [System.Collections.Generic.List[hashtable]]$orders =
        [System.Collections.Generic.List[hashtable]]::new()

    for ([int]$i = 0; $i -lt $Count; $i++) {
        [int]$userId    = $UserIds[$rng.Next(0, $UserIds.Length)]
        [int]$productId = $ProductIds[$rng.Next(0, $ProductIds.Length)]
        [int]$quantity  = $rng.Next(1, 11)          # 1–10 units

        # Unit price between 0.99 and 499.99
        [double]$unitPrice = [System.Math]::Round(0.99 + $rng.NextDouble() * 499.0, 2)
        [double]$totalPrice = [System.Math]::Round([double]$quantity * $unitPrice, 2)

        [int]$statusIdx = Get-WeightedRandom -Rng $rng -Weights $script:StatusWeights
        [string]$status = $script:OrderStatuses[$statusIdx]
        [string]$orderDate = Format-IsoDate -Rng $rng -MinDate $minDate -MaxDate $maxDate

        [void]$orders.Add(@{
            user_id     = $userId
            product_id  = $productId
            quantity    = $quantity
            unit_price  = $unitPrice
            total_price = $totalPrice
            status      = $status
            order_date  = $orderDate
        })
    }

    return [hashtable[]]$orders.ToArray()
}

# ---------------------------------------------------------------------------
# Public: Import-SeedData
# ---------------------------------------------------------------------------
function Import-SeedData {
    <#
    .SYNOPSIS
        Generates and inserts users, products, and orders into the database.
    .DESCRIPTION
        Inserts users and products first, then orders — preserving referential
        integrity. Uses SQLite transactions for performance and atomicity.
    .PARAMETER DatabasePath
        Path to the SQLite file (schema must already be initialised).
    .PARAMETER UserCount
        Number of user rows to insert.
    .PARAMETER ProductCount
        Number of product rows to insert.
    .PARAMETER OrderCount
        Number of order rows to insert.
    .PARAMETER Seed
        RNG seed for reproducible data generation.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][string]$DatabasePath,
        [Parameter(Mandatory)][int]$UserCount,
        [Parameter(Mandatory)][int]$ProductCount,
        [Parameter(Mandatory)][int]$OrderCount,
        [Parameter(Mandatory)][int]$Seed
    )

    # Generate data — use distinct seed offsets so user/product/order pools
    # don't produce identical sequences when seeded the same way.
    [hashtable[]]$users    = New-MockUsers    -Count $UserCount    -Seed ($Seed)
    [hashtable[]]$products = New-MockProducts -Count $ProductCount -Seed ($Seed + 1000)

    # Open a single connection so transactions span multiple INSERT calls.
    # Pre-initialise $conn to $null so the finally-block null-guard works
    # even if New-SQLiteConnection throws (strict mode would otherwise
    # complain about an undefined variable in the finally block).
    $conn = $null
    $conn = New-SQLiteConnection -DataSource $DatabasePath

    try {
        # Enable FK enforcement for this connection
        Invoke-SqliteQuery -SQLiteConnection $conn -Query 'PRAGMA foreign_keys = ON' | Out-Null

        # ---- Insert users (single transaction for performance) ----
        Invoke-SqliteQuery -SQLiteConnection $conn -Query 'BEGIN TRANSACTION' | Out-Null
        foreach ($u in $users) {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query @'
INSERT INTO users (username, email, full_name, created_at, is_active)
VALUES            (@username, @email, @full_name, @created_at, @is_active)
'@ -SqlParameters @{
                username   = [string]$u.username
                email      = [string]$u.email
                full_name  = [string]$u.full_name
                created_at = [string]$u.created_at
                is_active  = [int]$u.is_active
            } | Out-Null
        }
        Invoke-SqliteQuery -SQLiteConnection $conn -Query 'COMMIT' | Out-Null

        # ---- Insert products ----
        Invoke-SqliteQuery -SQLiteConnection $conn -Query 'BEGIN TRANSACTION' | Out-Null
        foreach ($p in $products) {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query @'
INSERT INTO products (name, description, price, stock_quantity, category, created_at)
VALUES               (@name, @description, @price, @stock_quantity, @category, @created_at)
'@ -SqlParameters @{
                name           = [string]$p.name
                description    = [string]$p.description
                price          = [double]$p.price
                stock_quantity = [int]$p.stock_quantity
                category       = [string]$p.category
                created_at     = [string]$p.created_at
            } | Out-Null
        }
        Invoke-SqliteQuery -SQLiteConnection $conn -Query 'COMMIT' | Out-Null

        # ---- Collect the auto-assigned IDs we just created ----
        [array]$userRows    = Invoke-SqliteQuery -SQLiteConnection $conn -Query 'SELECT id FROM users'
        [array]$productRows = Invoke-SqliteQuery -SQLiteConnection $conn -Query 'SELECT id FROM products'
        [int[]]$userIds    = @($userRows    | ForEach-Object { [int]$_.id })
        [int[]]$productIds = @($productRows | ForEach-Object { [int]$_.id })

        # ---- Generate and insert orders (references real IDs — FK safe) ----
        [hashtable[]]$orders = New-MockOrders -Count $OrderCount -Seed ($Seed + 2000) `
            -UserIds $userIds -ProductIds $productIds

        Invoke-SqliteQuery -SQLiteConnection $conn -Query 'BEGIN TRANSACTION' | Out-Null
        foreach ($o in $orders) {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query @'
INSERT INTO orders (user_id, product_id, quantity, unit_price, total_price, status, order_date)
VALUES             (@user_id, @product_id, @quantity, @unit_price, @total_price, @status, @order_date)
'@ -SqlParameters @{
                user_id     = [int]$o.user_id
                product_id  = [int]$o.product_id
                quantity    = [int]$o.quantity
                unit_price  = [double]$o.unit_price
                total_price = [double]$o.total_price
                status      = [string]$o.status
                order_date  = [string]$o.order_date
            } | Out-Null
        }
        Invoke-SqliteQuery -SQLiteConnection $conn -Query 'COMMIT' | Out-Null
    }
    catch {
        # Attempt rollback on error; swallow secondary rollback failures
        try { Invoke-SqliteQuery -SQLiteConnection $conn -Query 'ROLLBACK' | Out-Null } catch { }
        throw "Import-SeedData failed: $_"
    }
    finally {
        # Null guard: connection may not have been created if New-SQLiteConnection threw
        if ($null -ne $conn) {
            $conn.Close()
            $conn.Dispose()
        }
    }
}

# ---------------------------------------------------------------------------
# Public: Invoke-VerificationQueries
# ---------------------------------------------------------------------------
function Invoke-VerificationQueries {
    <#
    .SYNOPSIS
        Runs a suite of data-consistency verification queries and returns
        a structured result object.
    .PARAMETER DatabasePath
        Path to the seeded SQLite database.
    .OUTPUTS
        PSCustomObject with fields:
          UserCount, ProductCount, OrderCount,
          OrphanedOrders, PriceErrors,
          ActiveUserPct, TopSpenders, RevenueByCategory
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$DatabasePath
    )

    # ---- Counts ----
    [array]$uRows = Invoke-SqliteQuery -DataSource $DatabasePath -Query 'SELECT COUNT(*) AS cnt FROM users'
    [array]$pRows = Invoke-SqliteQuery -DataSource $DatabasePath -Query 'SELECT COUNT(*) AS cnt FROM products'
    [array]$oRows = Invoke-SqliteQuery -DataSource $DatabasePath -Query 'SELECT COUNT(*) AS cnt FROM orders'

    [int]$userCount    = [int]$uRows[0].cnt
    [int]$productCount = [int]$pRows[0].cnt
    [int]$orderCount   = [int]$oRows[0].cnt

    # ---- Referential integrity — orphaned orders ----
    [array]$orphanRows = Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
SELECT COUNT(*) AS cnt
FROM   orders o
WHERE  NOT EXISTS (SELECT 1 FROM users    u WHERE u.id = o.user_id)
   OR  NOT EXISTS (SELECT 1 FROM products p WHERE p.id = o.product_id)
'@
    [int]$orphanedOrders = [int]$orphanRows[0].cnt

    # ---- Price calculation errors ----
    [array]$priceRows = Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
SELECT COUNT(*) AS cnt
FROM   orders
WHERE  ABS(total_price - (quantity * unit_price)) > 0.01
'@
    [int]$priceErrors = [int]$priceRows[0].cnt

    # ---- Active user percentage ----
    [double]$activeUserPct = 0.0
    if ($userCount -gt 0) {
        [array]$activeRows = Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
SELECT ROUND(100.0 * SUM(is_active) / COUNT(*), 2) AS pct FROM users
'@
        $activeUserPct = [double]$activeRows[0].pct
    }

    # ---- Top spenders (top 5 users by total spend) ----
    [array]$topSpenders = Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
SELECT u.username,
       ROUND(SUM(o.total_price), 2) AS total_spent,
       COUNT(o.id)                  AS order_count
FROM   orders o
JOIN   users  u ON u.id = o.user_id
GROUP  BY o.user_id
ORDER  BY total_spent DESC
LIMIT  5
'@

    # ---- Revenue by product category ----
    [array]$revenueByCategory = Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
SELECT p.category,
       ROUND(SUM(o.total_price), 2) AS revenue,
       COUNT(o.id)                  AS order_count
FROM   orders   o
JOIN   products p ON p.id = o.product_id
GROUP  BY p.category
ORDER  BY revenue DESC
'@

    return [PSCustomObject]@{
        UserCount          = $userCount
        ProductCount       = $productCount
        OrderCount         = $orderCount
        OrphanedOrders     = $orphanedOrders
        PriceErrors        = $priceErrors
        ActiveUserPct      = $activeUserPct
        TopSpenders        = $topSpenders
        RevenueByCategory  = $revenueByCategory
    }
}

# Export only the public API
Export-ModuleMember -Function @(
    'Initialize-DatabaseSchema'
    'New-MockUsers'
    'New-MockProducts'
    'New-MockOrders'
    'Import-SeedData'
    'Invoke-VerificationQueries'
)
