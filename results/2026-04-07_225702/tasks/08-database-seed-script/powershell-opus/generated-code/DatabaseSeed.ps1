# DatabaseSeed.ps1 - SQLite database seed script with deterministic mock data
# Loads Microsoft.Data.Sqlite assemblies, creates schema, generates and inserts data,
# and provides verification queries.

# --- Assembly Loading ---
# Load the Microsoft.Data.Sqlite NuGet package assemblies from the lib directory.
$script:LibPath = Join-Path $PSScriptRoot "lib"

function Initialize-SqliteAssemblies {
    <# Load .NET assemblies for SQLite access in dependency order. #>
    [System.Reflection.Assembly]::LoadFrom((Join-Path $script:LibPath "SQLitePCLRaw.core.dll")) | Out-Null
    [System.Reflection.Assembly]::LoadFrom((Join-Path $script:LibPath "SQLitePCLRaw.provider.e_sqlite3.dll")) | Out-Null
    [System.Reflection.Assembly]::LoadFrom((Join-Path $script:LibPath "SQLitePCLRaw.batteries_v2.dll")) | Out-Null
    [System.Reflection.Assembly]::LoadFrom((Join-Path $script:LibPath "Microsoft.Data.Sqlite.dll")) | Out-Null
    [SQLitePCL.Batteries_V2]::Init()
}

# Initialize on load
Initialize-SqliteAssemblies

# --- Connection Helper ---
function New-SqliteConnection {
    <# Creates and opens a new SQLite connection. #>
    param(
        [Parameter(Mandatory)][string]$DataSource
    )
    try {
        $conn = New-Object Microsoft.Data.Sqlite.SqliteConnection "Data Source=$DataSource"
        $conn.Open()

        # Enable foreign key enforcement (off by default in SQLite)
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "PRAGMA foreign_keys = ON;"
        $cmd.ExecuteNonQuery() | Out-Null
        $cmd.Dispose()

        return $conn
    }
    catch {
        throw "Failed to open SQLite connection to '$DataSource': $_"
    }
}

# --- Schema Creation ---
function Initialize-Schema {
    <# Creates the users, products, and orders tables with proper foreign keys. #>
    param(
        [Parameter(Mandatory)]$Connection
    )

    $sql = @"
        CREATE TABLE IF NOT EXISTS users (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT    NOT NULL,
            email      TEXT    NOT NULL UNIQUE,
            created_at TEXT    NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS products (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            name     TEXT    NOT NULL,
            price    REAL    NOT NULL CHECK (price > 0),
            category TEXT    NOT NULL
        );

        CREATE TABLE IF NOT EXISTS orders (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id    INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity   INTEGER NOT NULL CHECK (quantity > 0),
            order_date TEXT    NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (user_id)    REFERENCES users(id),
            FOREIGN KEY (product_id) REFERENCES products(id)
        );
"@

    try {
        $cmd = $Connection.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.ExecuteNonQuery() | Out-Null
        $cmd.Dispose()
    }
    catch {
        throw "Failed to create schema: $_"
    }
}

# --- Query Helpers ---
function Invoke-SqliteQuery {
    <# Executes a SQL query and returns results as an array of hashtables. #>
    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][string]$Query,
        [hashtable]$Parameters = @{}
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query

    foreach ($key in $Parameters.Keys) {
        $param = $cmd.CreateParameter()
        $param.ParameterName = $key
        $param.Value = $Parameters[$key]
        $cmd.Parameters.Add($param) | Out-Null
    }

    $reader = $cmd.ExecuteReader()
    $results = @()

    while ($reader.Read()) {
        $row = @{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $row[$reader.GetName($i)] = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
        }
        $results += [PSCustomObject]$row
    }

    $reader.Close()
    $reader.Dispose()
    $cmd.Dispose()

    return $results
}

function Invoke-SqliteScalar {
    <# Executes a SQL query and returns a single scalar value. #>
    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][string]$Query
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query
    $result = $cmd.ExecuteScalar()
    $cmd.Dispose()
    return $result
}

function Get-TableNames {
    <# Returns a list of table names in the database. #>
    param(
        [Parameter(Mandatory)]$Connection
    )

    $results = Invoke-SqliteQuery -Connection $Connection `
        -Query "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"
    return $results | ForEach-Object { $_.name }
}

function Get-ColumnNames {
    <# Returns column names for a given table. #>
    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][string]$TableName
    )

    $results = Invoke-SqliteQuery -Connection $Connection -Query "PRAGMA table_info('$TableName');"
    return $results | ForEach-Object { $_.name }
}

function Get-ForeignKeys {
    <# Returns foreign key info for a given table. #>
    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][string]$TableName
    )

    return Invoke-SqliteQuery -Connection $Connection -Query "PRAGMA foreign_key_list('$TableName');"
}

# --- Deterministic Data Generation ---
# Uses System.Random with a fixed seed for reproducible data.

function New-MockUsers {
    <# Generates an array of realistic mock user data using seeded RNG. #>
    param(
        [Parameter(Mandatory)][System.Random]$Rng,
        [int]$Count = 20
    )

    $firstNames = @("Alice", "Bob", "Carol", "David", "Eve", "Frank", "Grace",
                     "Hank", "Iris", "Jack", "Karen", "Leo", "Mona", "Nick",
                     "Olivia", "Paul", "Quinn", "Rita", "Sam", "Tina")
    $lastNames  = @("Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia",
                     "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez",
                     "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
                     "Taylor", "Moore", "Jackson", "Martin")
    $domains    = @("example.com", "testmail.org", "mockdata.net", "sample.io")

    $users = @()
    $usedEmails = @{}

    for ($i = 0; $i -lt $Count; $i++) {
        $first = $firstNames[$Rng.Next($firstNames.Length)]
        $last  = $lastNames[$Rng.Next($lastNames.Length)]
        $name  = "$first $last"
        $domain = $domains[$Rng.Next($domains.Length)]
        $email = "$($first.ToLower()).$($last.ToLower())@$domain"

        # Ensure email uniqueness by appending a number if needed
        if ($usedEmails.ContainsKey($email)) {
            $usedEmails[$email]++
            $email = "$($first.ToLower()).$($last.ToLower())$($usedEmails[$email])@$domain"
        }
        else {
            $usedEmails[$email] = 0
        }

        # Deterministic date within the past year (2025)
        $dayOffset = $Rng.Next(0, 365)
        $createdAt = (Get-Date "2025-01-01").AddDays($dayOffset).ToString("yyyy-MM-dd HH:mm:ss")

        $users += @{ Name = $name; Email = $email; CreatedAt = $createdAt }
    }

    return $users
}

function New-MockProducts {
    <# Generates an array of realistic mock product data using seeded RNG. #>
    param(
        [Parameter(Mandatory)][System.Random]$Rng,
        [int]$Count = 15
    )

    $productNames = @(
        "Wireless Mouse", "Mechanical Keyboard", "USB-C Hub", "Monitor Stand",
        "Webcam HD", "Noise-Canceling Headphones", "Laptop Sleeve", "Desk Lamp",
        "Ergonomic Chair", "Standing Desk", "Cable Organizer", "Mousepad XL",
        "Screen Protector", "Power Strip", "External SSD", "Bluetooth Speaker",
        "Phone Charger", "Tablet Stand", "HDMI Cable", "Surge Protector"
    )
    $categories = @("Electronics", "Accessories", "Furniture", "Storage", "Audio")

    $products = @()
    # Use a shuffled subset to avoid duplicate product names
    $indices = 0..($productNames.Length - 1) | Sort-Object { $Rng.Next() }

    for ($i = 0; $i -lt $Count; $i++) {
        $nameIdx  = $indices[$i]
        # Price between $5.00 and $500.00, rounded to 2 decimals
        $price    = [math]::Round($Rng.NextDouble() * 495 + 5, 2)
        $category = $categories[$Rng.Next($categories.Length)]

        $products += @{
            Name     = $productNames[$nameIdx]
            Price    = $price
            Category = $category
        }
    }

    return $products
}

function New-MockOrders {
    <# Generates an array of mock orders referencing valid user and product IDs. #>
    param(
        [Parameter(Mandatory)][System.Random]$Rng,
        [int]$Count = 50,
        [Parameter(Mandatory)][int]$MaxUserId,
        [Parameter(Mandatory)][int]$MaxProductId
    )

    $orders = @()

    for ($i = 0; $i -lt $Count; $i++) {
        $userId    = $Rng.Next(1, $MaxUserId + 1)
        $productId = $Rng.Next(1, $MaxProductId + 1)
        $quantity  = $Rng.Next(1, 11)  # 1-10 items
        $dayOffset = $Rng.Next(0, 365)
        $orderDate = (Get-Date "2025-01-01").AddDays($dayOffset).ToString("yyyy-MM-dd HH:mm:ss")

        $orders += @{
            UserId    = $userId
            ProductId = $productId
            Quantity  = $quantity
            OrderDate = $orderDate
        }
    }

    return $orders
}

# --- Data Insertion ---
function Insert-Users {
    <# Inserts user records into the database within a transaction. #>
    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][array]$Users
    )

    $tx = $Connection.BeginTransaction()
    try {
        foreach ($user in $Users) {
            $cmd = $Connection.CreateCommand()
            $cmd.CommandText = "INSERT INTO users (name, email, created_at) VALUES (@name, @email, @created_at);"
            $p1 = $cmd.CreateParameter(); $p1.ParameterName = "@name"; $p1.Value = $user.Name; $cmd.Parameters.Add($p1) | Out-Null
            $p2 = $cmd.CreateParameter(); $p2.ParameterName = "@email"; $p2.Value = $user.Email; $cmd.Parameters.Add($p2) | Out-Null
            $p3 = $cmd.CreateParameter(); $p3.ParameterName = "@created_at"; $p3.Value = $user.CreatedAt; $cmd.Parameters.Add($p3) | Out-Null
            $cmd.ExecuteNonQuery() | Out-Null
            $cmd.Dispose()
        }
        $tx.Commit()
    }
    catch {
        $tx.Rollback()
        throw "Failed to insert users: $_"
    }
}

function Insert-Products {
    <# Inserts product records into the database within a transaction. #>
    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][array]$Products
    )

    $tx = $Connection.BeginTransaction()
    try {
        foreach ($product in $Products) {
            $cmd = $Connection.CreateCommand()
            $cmd.CommandText = "INSERT INTO products (name, price, category) VALUES (@name, @price, @category);"
            $p1 = $cmd.CreateParameter(); $p1.ParameterName = "@name"; $p1.Value = $product.Name; $cmd.Parameters.Add($p1) | Out-Null
            $p2 = $cmd.CreateParameter(); $p2.ParameterName = "@price"; $p2.Value = $product.Price; $cmd.Parameters.Add($p2) | Out-Null
            $p3 = $cmd.CreateParameter(); $p3.ParameterName = "@category"; $p3.Value = $product.Category; $cmd.Parameters.Add($p3) | Out-Null
            $cmd.ExecuteNonQuery() | Out-Null
            $cmd.Dispose()
        }
        $tx.Commit()
    }
    catch {
        $tx.Rollback()
        throw "Failed to insert products: $_"
    }
}

function Insert-Orders {
    <# Inserts order records into the database within a transaction. #>
    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][array]$Orders
    )

    $tx = $Connection.BeginTransaction()
    try {
        foreach ($order in $Orders) {
            $cmd = $Connection.CreateCommand()
            $cmd.CommandText = "INSERT INTO orders (user_id, product_id, quantity, order_date) VALUES (@uid, @pid, @qty, @date);"
            $p1 = $cmd.CreateParameter(); $p1.ParameterName = "@uid"; $p1.Value = $order.UserId; $cmd.Parameters.Add($p1) | Out-Null
            $p2 = $cmd.CreateParameter(); $p2.ParameterName = "@pid"; $p2.Value = $order.ProductId; $cmd.Parameters.Add($p2) | Out-Null
            $p3 = $cmd.CreateParameter(); $p3.ParameterName = "@qty"; $p3.Value = $order.Quantity; $cmd.Parameters.Add($p3) | Out-Null
            $p4 = $cmd.CreateParameter(); $p4.ParameterName = "@date"; $p4.Value = $order.OrderDate; $cmd.Parameters.Add($p4) | Out-Null
            $cmd.ExecuteNonQuery() | Out-Null
            $cmd.Dispose()
        }
        $tx.Commit()
    }
    catch {
        $tx.Rollback()
        throw "Failed to insert orders: $_"
    }
}

# --- Verification Queries ---
function Get-VerificationResults {
    <# Runs a suite of verification queries and returns the results. #>
    param(
        [Parameter(Mandatory)]$Connection
    )

    $results = @{}

    # Count of records in each table
    $results.UserCount    = [int](Invoke-SqliteScalar -Connection $Connection -Query "SELECT COUNT(*) FROM users;")
    $results.ProductCount = [int](Invoke-SqliteScalar -Connection $Connection -Query "SELECT COUNT(*) FROM products;")
    $results.OrderCount   = [int](Invoke-SqliteScalar -Connection $Connection -Query "SELECT COUNT(*) FROM orders;")

    # All order user_ids reference valid users
    $results.OrphanUserOrders = [int](Invoke-SqliteScalar -Connection $Connection -Query "
        SELECT COUNT(*) FROM orders o
        LEFT JOIN users u ON o.user_id = u.id
        WHERE u.id IS NULL;")

    # All order product_ids reference valid products
    $results.OrphanProductOrders = [int](Invoke-SqliteScalar -Connection $Connection -Query "
        SELECT COUNT(*) FROM orders o
        LEFT JOIN products p ON o.product_id = p.id
        WHERE p.id IS NULL;")

    # Orders per user (should be >= 0 for all users)
    $results.OrdersPerUser = Invoke-SqliteQuery -Connection $Connection -Query "
        SELECT u.id, u.name, COUNT(o.id) as order_count
        FROM users u
        LEFT JOIN orders o ON u.id = o.user_id
        GROUP BY u.id
        ORDER BY order_count DESC;"

    # Revenue per product
    $results.RevenuePerProduct = Invoke-SqliteQuery -Connection $Connection -Query "
        SELECT p.name, p.price, SUM(o.quantity) as total_qty,
               ROUND(p.price * SUM(o.quantity), 2) as total_revenue
        FROM products p
        INNER JOIN orders o ON p.id = o.product_id
        GROUP BY p.id
        ORDER BY total_revenue DESC;"

    # Total revenue
    $results.TotalRevenue = Invoke-SqliteScalar -Connection $Connection -Query "
        SELECT ROUND(SUM(p.price * o.quantity), 2)
        FROM orders o
        JOIN products p ON o.product_id = p.id;"

    # All emails are unique
    $results.DuplicateEmails = [int](Invoke-SqliteScalar -Connection $Connection -Query "
        SELECT COUNT(*) FROM (
            SELECT email FROM users GROUP BY email HAVING COUNT(*) > 1
        );")

    # All prices are positive
    $results.InvalidPrices = [int](Invoke-SqliteScalar -Connection $Connection -Query "
        SELECT COUNT(*) FROM products WHERE price <= 0;")

    # All quantities are positive
    $results.InvalidQuantities = [int](Invoke-SqliteScalar -Connection $Connection -Query "
        SELECT COUNT(*) FROM orders WHERE quantity <= 0;")

    return $results
}

# --- Main Seed Function ---
function Invoke-DatabaseSeed {
    <#
        Main entry point: creates schema, generates deterministic data, inserts it,
        and runs verification. Returns the connection and verification results.
    #>
    param(
        [string]$DataSource = ":memory:",
        [int]$Seed = 42,
        [int]$UserCount = 20,
        [int]$ProductCount = 15,
        [int]$OrderCount = 50
    )

    $conn = New-SqliteConnection -DataSource $DataSource
    Initialize-Schema -Connection $conn

    # Seeded RNG for deterministic data generation
    $rng = New-Object System.Random($Seed)

    $users    = New-MockUsers    -Rng $rng -Count $UserCount
    $products = New-MockProducts -Rng $rng -Count $ProductCount
    $orders   = New-MockOrders   -Rng $rng -Count $OrderCount -MaxUserId $UserCount -MaxProductId $ProductCount

    Insert-Users    -Connection $conn -Users $users
    Insert-Products -Connection $conn -Products $products
    Insert-Orders   -Connection $conn -Orders $orders

    $verification = Get-VerificationResults -Connection $conn

    return @{
        Connection   = $conn
        Verification = $verification
    }
}
