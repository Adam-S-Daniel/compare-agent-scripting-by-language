# DatabaseSeed.ps1
# SQLite database seed script with realistic mock data using deterministic (seeded) RNG.
#
# Approach:
#   1. Initialize schema (users, products, orders) with foreign key constraints.
#   2. Generate deterministic mock data by constructing a System.Random from a fixed seed.
#   3. Insert data in dependency order: users → products → orders.
#   4. Provide verification query helpers to confirm referential integrity and data quality.
#
# SQLite FK note: PRAGMA foreign_keys is per-connection. We use New-SQLiteConnection
# for operations that need FK enforcement so the PRAGMA and DML share one connection.

# ---------------------------------------------------------------------------
# Ensure PSSQLite is available
# ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
    Write-Host "Installing PSSQLite module..." -ForegroundColor Yellow
    Install-Module -Name PSSQLite -Force -Scope CurrentUser -SkipPublisherCheck
}
Import-Module PSSQLite -ErrorAction Stop

# ---------------------------------------------------------------------------
# Low-level SQL helpers
# ---------------------------------------------------------------------------

function Invoke-SqlQuery {
    <#
    .SYNOPSIS  Execute a query and return all result rows as PSObjects.
    #>
    param(
        [string]$DbPath,
        [string]$Query,
        [hashtable]$Parameters = @{}
    )
    Invoke-SqliteQuery -DataSource $DbPath -Query $Query -SqlParameters $Parameters
}

function Invoke-SqlScalar {
    <#
    .SYNOPSIS  Execute a query and return the value in column 0 of row 0.
    #>
    param(
        [string]$DbPath,
        [string]$Query,
        [hashtable]$Parameters = @{}
    )
    $rows = Invoke-SqliteQuery -DataSource $DbPath -Query $Query -SqlParameters $Parameters
    if ($null -eq $rows) { return 0 }

    $first = @($rows)[0]
    if ($first -is [System.Data.DataRow]) { return $first[0] }

    # PSCustomObject — grab first property value
    $prop = $first.PSObject.Properties | Select-Object -First 1
    if ($null -ne $prop) { return $prop.Value }
    return 0
}

function Open-FkConnection {
    <#
    .SYNOPSIS  Open a SQLiteConnection with foreign-key enforcement enabled.
               Caller must call .Close()/.Dispose() when done.
    #>
    param([string]$DbPath)
    $conn = New-SQLiteConnection -DataSource $DbPath
    Invoke-SqliteQuery -SQLiteConnection $conn -Query "PRAGMA foreign_keys = ON;" | Out-Null
    $conn
}

# ---------------------------------------------------------------------------
# Schema creation
# ---------------------------------------------------------------------------

function Initialize-Database {
    <#
    .SYNOPSIS  Create the SQLite database file and define the three tables.
    #>
    param([string]$DbPath)

    # Touch the file (creates it if absent)
    $conn = New-SQLiteConnection -DataSource $DbPath
    $conn.Close()

    # Users — root entity, no FK dependencies
    Invoke-SqliteQuery -DataSource $DbPath -Query @"
        CREATE TABLE IF NOT EXISTS users (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            username   TEXT NOT NULL UNIQUE,
            email      TEXT NOT NULL UNIQUE,
            full_name  TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        );
"@

    # Products — root entity, no FK dependencies
    Invoke-SqliteQuery -DataSource $DbPath -Query @"
        CREATE TABLE IF NOT EXISTS products (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            name           TEXT    NOT NULL,
            description    TEXT,
            price          REAL    NOT NULL CHECK(price > 0),
            stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK(stock_quantity >= 0),
            created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
        );
"@

    # Orders — depends on users and products via FK
    Invoke-SqliteQuery -DataSource $DbPath -Query @"
        CREATE TABLE IF NOT EXISTS orders (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL REFERENCES users(id)    ON DELETE RESTRICT,
            product_id  INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
            quantity    INTEGER NOT NULL CHECK(quantity > 0),
            total_price REAL    NOT NULL CHECK(total_price > 0),
            order_date  TEXT    NOT NULL DEFAULT (datetime('now'))
        );
"@
}

function Get-TableSchema {
    <#
    .SYNOPSIS  Return PRAGMA table_info rows for the named table.
    #>
    param(
        [string]$DbPath,
        [string]$TableName
    )
    Invoke-SqliteQuery -DataSource $DbPath -Query "PRAGMA table_info($TableName)"
}

# ---------------------------------------------------------------------------
# Deterministic mock-data generators (seeded RNG via System.Random)
# ---------------------------------------------------------------------------

# Static name pools
$script:FirstNames = @(
    'Alice','Bob','Carol','David','Eve','Frank','Grace','Henry',
    'Isabel','James','Karen','Liam','Maya','Nathan','Olivia','Paul',
    'Quinn','Rachel','Sam','Tina','Uma','Victor','Wendy','Xander','Yara','Zoe'
)
$script:LastNames = @(
    'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
    'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson',
    'Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson','White'
)
$script:Domains = @(
    'gmail.com','yahoo.com','outlook.com','hotmail.com','example.com',
    'mail.com','proton.me','icloud.com'
)
$script:ProductAdjectives = @(
    'Premium','Classic','Deluxe','Essential','Advanced','Pro','Ultra','Smart',
    'Eco','Compact','Portable','Heavy-Duty','Lightweight','Budget','Flagship'
)
$script:ProductNouns = @(
    'Laptop','Keyboard','Mouse','Monitor','Headphones','Webcam','Desk','Chair',
    'Notebook','Pen','Tablet','Phone','Charger','Cable','Bag','Case',
    'Speaker','Microphone','Camera','Light','Stand','Hub','Dock','Pad'
)

function Get-RandInt   { param($Rng,$Min,$Max) $Rng.Next($Min, $Max + 1) }
function Get-RandDbl   { param($Rng,$Min,$Max) $Min + ($Rng.NextDouble() * ($Max - $Min)) }
function Get-RandElem  { param($Rng,$Arr)      $Arr[$Rng.Next(0, $Arr.Length)] }

function New-MockUsers {
    <#
    .SYNOPSIS  Produce $Count user records deterministically from $Seed.
    #>
    param([int]$Count, [int]$Seed)

    $rng   = [System.Random]::new($Seed)
    $users = [System.Collections.Generic.List[object]]::new()
    $usedU = [System.Collections.Generic.HashSet[string]]::new()
    $usedE = [System.Collections.Generic.HashSet[string]]::new()

    while ($users.Count -lt $Count) {
        $first    = Get-RandElem $rng $script:FirstNames
        $last     = Get-RandElem $rng $script:LastNames
        $domain   = Get-RandElem $rng $script:Domains
        $suffix   = Get-RandInt  $rng 1 9999
        $username = "$($first.ToLower())_$($last.ToLower())$suffix"
        $email    = "$($first.ToLower()).$($last.ToLower())$suffix@$domain"

        if ($usedU.Contains($username) -or $usedE.Contains($email)) { continue }
        $null = $usedU.Add($username)
        $null = $usedE.Add($email)

        $daysAgo   = Get-RandInt $rng 0 1095
        $createdAt = (Get-Date).AddDays(-$daysAgo).ToString('yyyy-MM-dd HH:mm:ss')

        $users.Add([PSCustomObject]@{
            username   = $username
            email      = $email
            full_name  = "$first $last"
            created_at = $createdAt
        })
    }
    $users.ToArray()
}

function New-MockProducts {
    <#
    .SYNOPSIS  Produce $Count product records deterministically from $Seed.
    #>
    param([int]$Count, [int]$Seed)

    $rng      = [System.Random]::new($Seed)
    $products = [System.Collections.Generic.List[object]]::new()

    for ($i = 0; $i -lt $Count; $i++) {
        $adj   = Get-RandElem $rng $script:ProductAdjectives
        $noun  = Get-RandElem $rng $script:ProductNouns
        $price = [Math]::Round((Get-RandDbl $rng 4.99 499.99), 2)
        $stock = Get-RandInt  $rng 0 500

        $products.Add([PSCustomObject]@{
            name           = "$adj $noun"
            description    = "A $($adj.ToLower()) $($noun.ToLower()) for everyday use."
            price          = $price
            stock_quantity = $stock
        })
    }
    $products.ToArray()
}

function New-MockOrders {
    <#
    .SYNOPSIS  Produce $Count order records referencing user IDs 1..$UserCount
               and product IDs 1..$ProductCount, deterministically from $Seed.
    #>
    param([int]$Count, [int]$UserCount, [int]$ProductCount, [int]$Seed)

    $rng    = [System.Random]::new($Seed)
    $orders = [System.Collections.Generic.List[object]]::new()

    for ($i = 0; $i -lt $Count; $i++) {
        $userId    = Get-RandInt $rng 1 $UserCount
        $productId = Get-RandInt $rng 1 $ProductCount
        $qty       = Get-RandInt $rng 1 10
        $unitPrice = [Math]::Round((Get-RandDbl $rng 4.99 499.99), 2)
        $total     = [Math]::Round($qty * $unitPrice, 2)
        $daysAgo   = Get-RandInt $rng 0 365
        $orderDate = (Get-Date).AddDays(-$daysAgo).ToString('yyyy-MM-dd HH:mm:ss')

        $orders.Add([PSCustomObject]@{
            user_id     = $userId
            product_id  = $productId
            quantity    = $qty
            total_price = $total
            order_date  = $orderDate
        })
    }
    $orders.ToArray()
}

# ---------------------------------------------------------------------------
# Insertion functions
# ---------------------------------------------------------------------------

function Add-Users {
    <#
    .SYNOPSIS  Bulk-insert users; returns the count inserted.
    #>
    param([string]$DbPath, [object[]]$Users)

    $count = 0
    foreach ($u in $Users) {
        Invoke-SqliteQuery -DataSource $DbPath -Query @"
            INSERT INTO users (username, email, full_name, created_at)
            VALUES (@username, @email, @full_name, @created_at);
"@ -SqlParameters @{
            username   = $u.username
            email      = $u.email
            full_name  = $u.full_name
            created_at = $u.created_at
        }
        $count++
    }
    $count
}

function Add-Products {
    <#
    .SYNOPSIS  Bulk-insert products; returns the count inserted.
    #>
    param([string]$DbPath, [object[]]$Products)

    $count = 0
    foreach ($p in $Products) {
        Invoke-SqliteQuery -DataSource $DbPath -Query @"
            INSERT INTO products (name, description, price, stock_quantity)
            VALUES (@name, @description, @price, @stock_quantity);
"@ -SqlParameters @{
            name           = $p.name
            description    = $p.description
            price          = $p.price
            stock_quantity = $p.stock_quantity
        }
        $count++
    }
    $count
}

function Add-Orders {
    <#
    .SYNOPSIS  Bulk-insert orders with FK constraints enforced; returns count inserted.
               Uses a single SQLite connection so the PRAGMA persists across all INSERTs.
    #>
    param([string]$DbPath, [object[]]$Orders)

    # Open one connection with FK enforcement — PRAGMA foreign_keys is per-connection
    $conn = Open-FkConnection -DbPath $DbPath

    try {
        $count = 0
        foreach ($o in $Orders) {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query @"
                INSERT INTO orders (user_id, product_id, quantity, total_price, order_date)
                VALUES (@user_id, @product_id, @quantity, @total_price, @order_date);
"@ -SqlParameters @{
                user_id     = $o.user_id
                product_id  = $o.product_id
                quantity    = $o.quantity
                total_price = $o.total_price
                order_date  = $o.order_date
            }
            $count++
        }
        $count
    }
    finally {
        $conn.Close()
    }
}

# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

function Invoke-DatabaseSeed {
    <#
    .SYNOPSIS  Initialize the schema and populate with deterministic mock data.
    .OUTPUTS   PSCustomObject { UsersInserted, ProductsInserted, OrdersInserted }
    #>
    param(
        [string]$DbPath,
        [int]$UserCount    = 20,
        [int]$ProductCount = 15,
        [int]$OrderCount   = 50,
        [int]$Seed         = 42
    )

    Initialize-Database -DbPath $DbPath

    # Use different sub-seeds per table so sequences don't correlate
    $users    = New-MockUsers    -Count $UserCount    -Seed ($Seed * 31 + 1)
    $products = New-MockProducts -Count $ProductCount -Seed ($Seed * 31 + 2)
    $orders   = New-MockOrders   -Count $OrderCount   -UserCount $UserCount -ProductCount $ProductCount -Seed ($Seed * 31 + 3)

    $usersIns    = Add-Users    -DbPath $DbPath -Users    $users
    $productsIns = Add-Products -DbPath $DbPath -Products $products
    $ordersIns   = Add-Orders   -DbPath $DbPath -Orders   $orders

    [PSCustomObject]@{
        UsersInserted    = $usersIns
        ProductsInserted = $productsIns
        OrdersInserted   = $ordersIns
    }
}

# ---------------------------------------------------------------------------
# Verification queries
# ---------------------------------------------------------------------------

function Test-OrderTotalsConsistency {
    <#
    .SYNOPSIS  Verify that all orders have positive totals and valid FK references.
    .OUTPUTS   PSCustomObject { IsConsistent, Issues }
    #>
    param([string]$DbPath)

    $issues = [System.Collections.Generic.List[string]]::new()

    $badTotal = Invoke-SqlScalar -DbPath $DbPath -Query "SELECT COUNT(*) FROM orders WHERE total_price <= 0"
    if ([int]$badTotal -gt 0) { $issues.Add("$badTotal order(s) with non-positive total_price") }

    $orphanUser = Invoke-SqlScalar -DbPath $DbPath -Query @"
        SELECT COUNT(*) FROM orders o LEFT JOIN users u ON o.user_id = u.id WHERE u.id IS NULL
"@
    if ([int]$orphanUser -gt 0) { $issues.Add("$orphanUser order(s) missing user_id reference") }

    $orphanProd = Invoke-SqlScalar -DbPath $DbPath -Query @"
        SELECT COUNT(*) FROM orders o LEFT JOIN products p ON o.product_id = p.id WHERE p.id IS NULL
"@
    if ([int]$orphanProd -gt 0) { $issues.Add("$orphanProd order(s) missing product_id reference") }

    [PSCustomObject]@{
        IsConsistent = ($issues.Count -eq 0)
        Issues       = $issues.ToArray()
    }
}

function Get-UserOrderSummary {
    <#
    .SYNOPSIS  Aggregate order stats per user.
               Returns PSCustomObjects (via Select-Object) so property names are
               introspectable — PSSQLite returns DataRows by default, and DataRow
               column names are NOT always visible via .PSObject.Properties.Name.
    #>
    param([string]$DbPath)
    Invoke-SqliteQuery -DataSource $DbPath -Query @"
        SELECT
            u.username,
            u.email,
            COUNT(o.id)                       AS order_count,
            COALESCE(SUM(o.total_price), 0.0) AS total_spent
        FROM users u
        LEFT JOIN orders o ON o.user_id = u.id
        GROUP BY u.id, u.username, u.email
        ORDER BY total_spent DESC;
"@ | Select-Object *
}

function Get-ProductSalesSummary {
    <#
    .SYNOPSIS  Aggregate sales stats per product.
               Returns PSCustomObjects — see Get-UserOrderSummary for rationale.
    #>
    param([string]$DbPath)
    Invoke-SqliteQuery -DataSource $DbPath -Query @"
        SELECT
            p.name                            AS product_name,
            p.price                           AS unit_price,
            COUNT(o.id)                       AS times_ordered,
            COALESCE(SUM(o.quantity), 0)      AS total_units_sold,
            COALESCE(SUM(o.total_price), 0.0) AS total_revenue
        FROM products p
        LEFT JOIN orders o ON o.product_id = p.id
        GROUP BY p.id, p.name, p.price
        ORDER BY total_revenue DESC;
"@ | Select-Object *
}

function Invoke-VerificationSuite {
    <#
    .SYNOPSIS  Run all data-consistency checks; return a consolidated report.
    .OUTPUTS   PSCustomObject { AllPassed, Checks }
    #>
    param([string]$DbPath)

    # Build check list inline — avoid inner-function scope issues (PowerShell inner
    # functions get their own scope and cannot write to the outer function's locals).
    $checks = [System.Collections.Generic.List[object]]::new()

    $orphanUser = [int](Invoke-SqlScalar -DbPath $DbPath -Query @"
        SELECT COUNT(*) FROM orders o LEFT JOIN users u ON o.user_id = u.id WHERE u.id IS NULL
"@)
    $checks.Add([PSCustomObject]@{ Name = "No orphaned orders (user_id)"; Passed = ($orphanUser -eq 0); Detail = "Orphan count: $orphanUser" })

    $orphanProd = [int](Invoke-SqlScalar -DbPath $DbPath -Query @"
        SELECT COUNT(*) FROM orders o LEFT JOIN products p ON o.product_id = p.id WHERE p.id IS NULL
"@)
    $checks.Add([PSCustomObject]@{ Name = "No orphaned orders (product_id)"; Passed = ($orphanProd -eq 0); Detail = "Orphan count: $orphanProd" })

    $dupEmails = [int](Invoke-SqlScalar -DbPath $DbPath -Query @"
        SELECT COUNT(*) FROM (SELECT email FROM users GROUP BY email HAVING COUNT(*) > 1)
"@)
    $checks.Add([PSCustomObject]@{ Name = "Unique user emails"; Passed = ($dupEmails -eq 0); Detail = "Duplicate count: $dupEmails" })

    $dupUsers = [int](Invoke-SqlScalar -DbPath $DbPath -Query @"
        SELECT COUNT(*) FROM (SELECT username FROM users GROUP BY username HAVING COUNT(*) > 1)
"@)
    $checks.Add([PSCustomObject]@{ Name = "Unique usernames"; Passed = ($dupUsers -eq 0); Detail = "Duplicate count: $dupUsers" })

    $badPrices = [int](Invoke-SqlScalar -DbPath $DbPath -Query "SELECT COUNT(*) FROM orders WHERE total_price <= 0")
    $checks.Add([PSCustomObject]@{ Name = "All order total_prices > 0"; Passed = ($badPrices -eq 0); Detail = "Bad price count: $badPrices" })

    $badQty = [int](Invoke-SqlScalar -DbPath $DbPath -Query "SELECT COUNT(*) FROM orders WHERE quantity <= 0")
    $checks.Add([PSCustomObject]@{ Name = "All order quantities > 0"; Passed = ($badQty -eq 0); Detail = "Bad qty count: $badQty" })

    $uCnt = [int](Invoke-SqlScalar -DbPath $DbPath -Query "SELECT COUNT(*) FROM users")
    $pCnt = [int](Invoke-SqlScalar -DbPath $DbPath -Query "SELECT COUNT(*) FROM products")
    $oCnt = [int](Invoke-SqlScalar -DbPath $DbPath -Query "SELECT COUNT(*) FROM orders")
    $checks.Add([PSCustomObject]@{ Name = "Users table non-empty";    Passed = ($uCnt -gt 0); Detail = "Count: $uCnt" })
    $checks.Add([PSCustomObject]@{ Name = "Products table non-empty"; Passed = ($pCnt -gt 0); Detail = "Count: $pCnt" })
    $checks.Add([PSCustomObject]@{ Name = "Orders table non-empty";   Passed = ($oCnt -gt 0); Detail = "Count: $oCnt" })

    $allPassed = ($checks | Where-Object { -not $_.Passed }).Count -eq 0

    [PSCustomObject]@{
        AllPassed = $allPassed
        Checks    = $checks.ToArray()
    }
}
