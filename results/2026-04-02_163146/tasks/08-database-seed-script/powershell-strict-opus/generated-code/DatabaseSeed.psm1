# DatabaseSeed.psm1
# SQLite database seeding module with deterministic mock data generation.
# Supports both Microsoft.Data.Sqlite and PSSQLite/System.Data.SQLite backends.
# Uses System.Data.Common base types for cross-library compatibility.
# All functions use strict mode, explicit typing, CmdletBinding, and OutputType.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# SQLite Backend Detection and Loading
# ---------------------------------------------------------------------------
# Strategy:
#   1. Check if Microsoft.Data.Sqlite is already loaded
#   2. Try PSSQLite module (provides System.Data.SQLite)
#   3. Try loading Microsoft.Data.Sqlite from NuGet cache
#   4. Install PSSQLite module from PSGallery
#   5. Download and load Microsoft.Data.Sqlite NuGet packages via HTTP
#   6. Use dotnet CLI to restore packages as last resort
# ---------------------------------------------------------------------------

# Module-level variable to track which backend is active
[string]$script:SqliteBackend = 'None'

function Initialize-SqliteAssembly {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    # Strategy 1: Microsoft.Data.Sqlite already loaded
    try {
        [void][Microsoft.Data.Sqlite.SqliteConnection]
        $script:SqliteBackend = 'Microsoft.Data.Sqlite'
        Write-Verbose 'Microsoft.Data.Sqlite already loaded'
        return
    }
    catch { }

    # Strategy 2: System.Data.SQLite already loaded (e.g., from PSSQLite)
    try {
        [void][System.Data.SQLite.SQLiteConnection]
        $script:SqliteBackend = 'System.Data.SQLite'
        Write-Verbose 'System.Data.SQLite already loaded'
        return
    }
    catch { }

    # Strategy 3: Try importing PSSQLite module
    try {
        Import-Module PSSQLite -ErrorAction Stop
        [void][System.Data.SQLite.SQLiteConnection]
        $script:SqliteBackend = 'System.Data.SQLite'
        Write-Verbose 'Loaded System.Data.SQLite via PSSQLite module'
        return
    }
    catch { }

    # Strategy 4: Search NuGet cache for Microsoft.Data.Sqlite
    [string]$nugetBase = Join-Path $HOME '.nuget' 'packages'
    if (Test-Path $nugetBase) {
        [string[]]$candidates = @(
            Get-ChildItem -Path $nugetBase -Filter 'Microsoft.Data.Sqlite.dll' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match 'net[678]\.' } |
            Sort-Object -Property FullName -Descending |
            Select-Object -ExpandProperty FullName
        )
        foreach ($dll in $candidates) {
            try {
                Add-Type -Path $dll -ErrorAction Stop
                [void][Microsoft.Data.Sqlite.SqliteConnection]
                # Also try to load SQLitePCLRaw
                [string]$dllDir = Split-Path $dll -Parent
                [string[]]$rawDlls = @(Get-ChildItem -Path (Split-Path (Split-Path $dllDir -Parent) -Parent) -Filter 'SQLitePCLRaw*.dll' -Recurse -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty FullName)
                foreach ($rawDll in $rawDlls) {
                    try { Add-Type -Path $rawDll -ErrorAction SilentlyContinue } catch { }
                }
                try { [SQLitePCL.Batteries_V2]::Init() } catch { }
                $script:SqliteBackend = 'Microsoft.Data.Sqlite'
                Write-Verbose "Loaded Microsoft.Data.Sqlite from NuGet cache: $dll"
                return
            }
            catch { }
        }
    }

    # Strategy 5: Install PSSQLite from PSGallery
    try {
        Write-Host 'Installing PSSQLite module...' -ForegroundColor Yellow
        Install-Module -Name PSSQLite -Force -Scope CurrentUser -SkipPublisherCheck -ErrorAction Stop
        Import-Module PSSQLite -ErrorAction Stop
        [void][System.Data.SQLite.SQLiteConnection]
        $script:SqliteBackend = 'System.Data.SQLite'
        Write-Verbose 'Installed and loaded PSSQLite module'
        return
    }
    catch {
        Write-Verbose "PSSQLite install failed: $_"
    }

    # Strategy 6: Download Microsoft.Data.Sqlite NuGet packages via HTTP
    [string]$libDir = Join-Path $PSScriptRoot 'sqlite-lib'
    if (-not (Test-Path $libDir)) {
        [void](New-Item -ItemType Directory -Path $libDir -Force)
    }

    try {
        Write-Host 'Downloading Microsoft.Data.Sqlite NuGet packages...' -ForegroundColor Yellow
        [string[]]$packages = @(
            'https://www.nuget.org/api/v2/package/Microsoft.Data.Sqlite/8.0.11',
            'https://www.nuget.org/api/v2/package/SQLitePCLRaw.core/2.1.10',
            'https://www.nuget.org/api/v2/package/SQLitePCLRaw.bundle_e_sqlite3/2.1.10',
            'https://www.nuget.org/api/v2/package/SQLitePCLRaw.lib.e_sqlite3/2.1.10',
            'https://www.nuget.org/api/v2/package/SQLitePCLRaw.provider.e_sqlite3/2.1.10'
        )

        foreach ($pkgUrl in $packages) {
            [string]$pkgName = ($pkgUrl -split '/')[-2]
            [string]$zipPath = Join-Path $libDir "$pkgName.zip"
            [string]$extractPath = Join-Path $libDir $pkgName

            if (-not (Test-Path $extractPath)) {
                Invoke-WebRequest -Uri $pkgUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
                Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop
                Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            }
        }

        # Find and load the DLLs - try net8.0 first, then net6.0
        [string[]]$tfms = @('net8.0', 'net7.0', 'net6.0', 'netstandard2.0')
        [string[]]$dllNames = @('SQLitePCLRaw.core', 'SQLitePCLRaw.batteries_v2', 'SQLitePCLRaw.provider.e_sqlite3', 'Microsoft.Data.Sqlite')

        foreach ($dllName in $dllNames) {
            [bool]$loaded = $false
            foreach ($tfm in $tfms) {
                [string[]]$found = @(Get-ChildItem -Path $libDir -Filter "$dllName.dll" -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match $tfm } |
                    Select-Object -ExpandProperty FullName)
                if ($found.Count -gt 0) {
                    try {
                        Add-Type -Path $found[0] -ErrorAction Stop
                        $loaded = $true
                        break
                    }
                    catch { }
                }
            }
            if (-not $loaded) {
                # Try any matching DLL
                [string[]]$anyFound = @(Get-ChildItem -Path $libDir -Filter "$dllName.dll" -Recurse -ErrorAction SilentlyContinue |
                    Select-Object -First 1 -ExpandProperty FullName)
                if ($anyFound.Count -gt 0) {
                    try { Add-Type -Path $anyFound[0] -ErrorAction SilentlyContinue } catch { }
                }
            }
        }

        try { [SQLitePCL.Batteries_V2]::Init() } catch { }
        [void][Microsoft.Data.Sqlite.SqliteConnection]
        $script:SqliteBackend = 'Microsoft.Data.Sqlite'
        Write-Verbose 'Loaded Microsoft.Data.Sqlite from downloaded NuGet packages'
        return
    }
    catch {
        Write-Verbose "NuGet download failed: $_"
    }

    # Strategy 7: Use dotnet CLI to restore packages
    try {
        Write-Host 'Using dotnet CLI to restore SQLite packages...' -ForegroundColor Yellow
        [string]$tempProj = Join-Path $libDir 'temp.csproj'
        # Detect .NET version
        [string]$dotnetVersion = (& dotnet --version 2>&1).ToString().Trim()
        [string]$tfm = if ($dotnetVersion -match '^9\.') { 'net9.0' }
                        elseif ($dotnetVersion -match '^8\.') { 'net8.0' }
                        elseif ($dotnetVersion -match '^10\.') { 'net10.0' }
                        else { 'net8.0' }

        [string]$projContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>$tfm</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Data.Sqlite" Version="8.*" />
  </ItemGroup>
</Project>
"@
        Set-Content -Path $tempProj -Value $projContent -Force

        [string]$publishDir = Join-Path $libDir 'publish'
        $null = & dotnet publish $tempProj -o $publishDir --nologo -v quiet 2>&1

        if (Test-Path $publishDir) {
            [string[]]$dllsToLoad = @(
                'SQLitePCLRaw.core.dll',
                'SQLitePCLRaw.batteries_v2.dll',
                'SQLitePCLRaw.provider.e_sqlite3.dll',
                'Microsoft.Data.Sqlite.dll'
            )

            foreach ($dllFile in $dllsToLoad) {
                [string[]]$found = @(Get-ChildItem -Path $publishDir -Filter $dllFile -Recurse -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty FullName)
                if ($found.Count -gt 0) {
                    try { Add-Type -Path $found[0] -ErrorAction SilentlyContinue } catch { }
                }
            }

            try { [SQLitePCL.Batteries_V2]::Init() } catch { }
            [void][Microsoft.Data.Sqlite.SqliteConnection]
            $script:SqliteBackend = 'Microsoft.Data.Sqlite'
            Write-Verbose 'Loaded Microsoft.Data.Sqlite via dotnet publish'
            return
        }
    }
    catch {
        Write-Verbose "dotnet restore failed: $_"
    }

    throw 'Could not load any SQLite library. Tried: Microsoft.Data.Sqlite, PSSQLite module, NuGet download, dotnet CLI. Ensure at least one is available.'
}

# Load SQLite assembly when module is imported
Initialize-SqliteAssembly

# ---------------------------------------------------------------------------
# Database Connection
# ---------------------------------------------------------------------------

function New-DatabaseConnection {
    <#
    .SYNOPSIS
        Creates a new SQLite database connection.
    .DESCRIPTION
        Opens a connection to the specified SQLite database. Use ':memory:'
        for an in-memory database. Works with both Microsoft.Data.Sqlite and
        System.Data.SQLite backends.
    #>
    [CmdletBinding()]
    [OutputType([System.Data.Common.DbConnection])]
    param(
        [Parameter(Mandatory)]
        [string]$DataSource
    )

    [System.Data.Common.DbConnection]$conn = $null

    if ($script:SqliteBackend -eq 'Microsoft.Data.Sqlite') {
        [string]$connStr = "Data Source=$DataSource"
        $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
    }
    elseif ($script:SqliteBackend -eq 'System.Data.SQLite') {
        [string]$connStr = "Data Source=$DataSource;Version=3;"
        $conn = [System.Data.SQLite.SQLiteConnection]::new($connStr)
    }
    else {
        throw "No SQLite backend available. Backend: $($script:SqliteBackend)"
    }

    $conn.Open()

    # Enable foreign key enforcement - critical for referential integrity
    [System.Data.Common.DbCommand]$cmd = $conn.CreateCommand()
    $cmd.CommandText = 'PRAGMA foreign_keys = ON'
    [void]$cmd.ExecuteNonQuery()
    $cmd.Dispose()

    return $conn
}

# ---------------------------------------------------------------------------
# Schema Creation
# ---------------------------------------------------------------------------

function Initialize-Schema {
    <#
    .SYNOPSIS
        Creates the users, products, and orders tables with foreign keys.
    .DESCRIPTION
        Sets up the database schema with three related tables. Orders reference
        both users and products via foreign keys. Executes each CREATE TABLE
        as a separate command for maximum compatibility.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection
    )

    # Execute each CREATE TABLE separately for cross-library compatibility
    [string[]]$statements = @(
        'CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL,
            full_name TEXT NOT NULL,
            created_at TEXT NOT NULL
        )',
        'CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            price REAL NOT NULL CHECK(price > 0),
            category TEXT NOT NULL,
            stock_quantity INTEGER NOT NULL CHECK(stock_quantity >= 0)
        )',
        'CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            total_price REAL NOT NULL CHECK(total_price > 0),
            order_date TEXT NOT NULL,
            status TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (product_id) REFERENCES products(id)
        )'
    )

    foreach ($sql in $statements) {
        [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
        $cmd.CommandText = $sql
        [void]$cmd.ExecuteNonQuery()
        $cmd.Dispose()
    }
}

# ---------------------------------------------------------------------------
# Schema Inspection Helpers
# ---------------------------------------------------------------------------

function Get-TableColumns {
    <#
    .SYNOPSIS
        Returns column metadata for a given table using PRAGMA table_info.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$TableName
    )

    [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
    $cmd.CommandText = "PRAGMA table_info('$TableName')"
    [System.Data.Common.DbDataReader]$reader = $cmd.ExecuteReader()

    [System.Collections.Generic.List[PSCustomObject]]$columns = [System.Collections.Generic.List[PSCustomObject]]::new()
    while ($reader.Read()) {
        [PSCustomObject]$col = [PSCustomObject]@{
            Cid        = [int]$reader['cid']
            Name       = [string]$reader['name']
            Type       = [string]$reader['type']
            NotNull    = [bool]([int]$reader['notnull'] -ne 0)
            Default    = $reader['dflt_value']
            PrimaryKey = [bool]([int]$reader['pk'] -ne 0)
        }
        $columns.Add($col)
    }
    $reader.Close()
    $reader.Dispose()
    $cmd.Dispose()

    return [PSCustomObject[]]$columns.ToArray()
}

function Get-ForeignKeys {
    <#
    .SYNOPSIS
        Returns foreign key metadata for a given table using PRAGMA foreign_key_list.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$TableName
    )

    [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
    $cmd.CommandText = "PRAGMA foreign_key_list('$TableName')"
    [System.Data.Common.DbDataReader]$reader = $cmd.ExecuteReader()

    [System.Collections.Generic.List[PSCustomObject]]$fkeys = [System.Collections.Generic.List[PSCustomObject]]::new()
    while ($reader.Read()) {
        [PSCustomObject]$fk = [PSCustomObject]@{
            Id    = [int]$reader['id']
            Seq   = [int]$reader['seq']
            Table = [string]$reader['table']
            From  = [string]$reader['from']
            To    = [string]$reader['to']
        }
        $fkeys.Add($fk)
    }
    $reader.Close()
    $reader.Dispose()
    $cmd.Dispose()

    return [PSCustomObject[]]$fkeys.ToArray()
}

function Get-AllTables {
    <#
    .SYNOPSIS
        Returns a list of all user-created table names in the database.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection
    )

    [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
    $cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    [System.Data.Common.DbDataReader]$reader = $cmd.ExecuteReader()

    [System.Collections.Generic.List[string]]$tables = [System.Collections.Generic.List[string]]::new()
    while ($reader.Read()) {
        $tables.Add([string]$reader['name'])
    }
    $reader.Close()
    $reader.Dispose()
    $cmd.Dispose()

    return [string[]]$tables.ToArray()
}

# ---------------------------------------------------------------------------
# Query Helpers
# ---------------------------------------------------------------------------

function Invoke-ScalarQuery {
    <#
    .SYNOPSIS
        Executes a query and returns the first column of the first row.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Query
    )

    [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query
    [object]$result = $cmd.ExecuteScalar()
    $cmd.Dispose()

    return $result
}

function Invoke-QueryRows {
    <#
    .SYNOPSIS
        Executes a query and returns all rows as PSCustomObjects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Query
    )

    [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query
    [System.Data.Common.DbDataReader]$reader = $cmd.ExecuteReader()

    [System.Collections.Generic.List[PSCustomObject]]$rows = [System.Collections.Generic.List[PSCustomObject]]::new()
    while ($reader.Read()) {
        [hashtable]$rowData = @{}
        for ([int]$i = 0; $i -lt $reader.FieldCount; $i++) {
            $rowData[[string]$reader.GetName($i)] = $reader.GetValue($i)
        }
        $rows.Add([PSCustomObject]$rowData)
    }
    $reader.Close()
    $reader.Dispose()
    $cmd.Dispose()

    return [PSCustomObject[]]$rows.ToArray()
}

function Invoke-NonQuery {
    <#
    .SYNOPSIS
        Executes a non-query SQL statement (INSERT, UPDATE, DELETE).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Query
    )

    [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query
    [int]$affected = $cmd.ExecuteNonQuery()
    $cmd.Dispose()

    return $affected
}

# ---------------------------------------------------------------------------
# Deterministic Mock Data Generation
# ---------------------------------------------------------------------------
# Uses System.Random with a fixed seed for reproducible data generation.
# Each generator function creates its own Random instance from the seed
# to ensure independent, repeatable sequences.
# ---------------------------------------------------------------------------

function New-MockUsers {
    <#
    .SYNOPSIS
        Generates deterministic mock user data using a seeded RNG.
    .DESCRIPTION
        Creates user records with unique usernames, valid email addresses,
        and realistic full names. The same seed always produces identical output.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [Parameter(Mandatory)]
        [int]$Count
    )

    [System.Random]$rng = [System.Random]::new($Seed)

    # Realistic name components for generating diverse data
    [string[]]$firstNames = @(
        'Emma', 'Liam', 'Olivia', 'Noah', 'Ava', 'Ethan', 'Sophia', 'Mason',
        'Isabella', 'William', 'Mia', 'James', 'Charlotte', 'Benjamin', 'Amelia',
        'Lucas', 'Harper', 'Henry', 'Evelyn', 'Alexander', 'Abigail', 'Daniel',
        'Emily', 'Matthew', 'Elizabeth', 'Joseph', 'Sofia', 'David', 'Victoria',
        'Samuel', 'Aria', 'Sebastian', 'Grace', 'Jack', 'Chloe', 'Owen',
        'Penelope', 'Ryan', 'Layla', 'Nathan', 'Riley', 'Leo', 'Zoey', 'Adam',
        'Nora', 'Aaron', 'Lily', 'Charles', 'Eleanor', 'Thomas'
    )

    [string[]]$lastNames = @(
        'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller',
        'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez',
        'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin',
        'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark',
        'Ramirez', 'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King',
        'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores', 'Green',
        'Adams', 'Nelson', 'Baker', 'Hall', 'Rivera', 'Campbell', 'Mitchell',
        'Carter', 'Roberts'
    )

    [string[]]$domains = @('gmail.com', 'yahoo.com', 'outlook.com', 'proton.me', 'fastmail.com', 'hey.com')

    [System.Collections.Generic.List[PSCustomObject]]$users = [System.Collections.Generic.List[PSCustomObject]]::new()
    [System.Collections.Generic.HashSet[string]]$usedUsernames = [System.Collections.Generic.HashSet[string]]::new()

    for ([int]$i = 0; $i -lt $Count; $i++) {
        [string]$first = $firstNames[$rng.Next($firstNames.Length)]
        [string]$last = $lastNames[$rng.Next($lastNames.Length)]

        # Generate a unique username by appending a numeric suffix
        [string]$baseUsername = "$($first.ToLower()).$($last.ToLower())"
        [int]$suffix = $rng.Next(100, 999)
        [string]$username = "${baseUsername}${suffix}"

        # If collision occurs, increment deterministically (no extra RNG calls)
        while (-not $usedUsernames.Add($username)) {
            $suffix = $suffix + 1
            $username = "${baseUsername}${suffix}"
        }

        [string]$domain = $domains[$rng.Next($domains.Length)]
        [string]$email = "${username}@${domain}"
        [string]$fullName = "$first $last"

        # Generate a creation date within the past 2 years
        [int]$daysAgo = $rng.Next(1, 730)
        [string]$createdAt = [datetime]::new(2024, 1, 1).AddDays(-$daysAgo).ToString('yyyy-MM-dd HH:mm:ss')

        [PSCustomObject]$user = [PSCustomObject]@{
            Username  = $username
            Email     = $email
            FullName  = $fullName
            CreatedAt = $createdAt
        }
        $users.Add($user)
    }

    return [PSCustomObject[]]$users.ToArray()
}

function New-MockProducts {
    <#
    .SYNOPSIS
        Generates deterministic mock product data using a seeded RNG.
    .DESCRIPTION
        Creates product records with names, descriptions, prices, categories,
        and stock quantities. Same seed always produces identical output.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [Parameter(Mandatory)]
        [int]$Count
    )

    [System.Random]$rng = [System.Random]::new($Seed)

    # Product templates organized by category for realistic data
    [hashtable]$productsByCategory = @{
        'Electronics' = @('Wireless Headphones', 'USB-C Hub', 'Mechanical Keyboard', 'Smart Watch', 'Portable Charger', 'Bluetooth Speaker', 'Webcam', 'Mouse Pad')
        'Clothing'    = @('Cotton T-Shirt', 'Denim Jacket', 'Running Shoes', 'Wool Sweater', 'Baseball Cap', 'Silk Scarf', 'Leather Belt', 'Linen Pants')
        'Books'       = @('Python Cookbook', 'Design Patterns', 'Clean Code', 'Data Structures', 'AI Handbook', 'Web Security', 'DevOps Guide', 'SQL Mastery')
        'Home'        = @('Desk Lamp', 'Throw Pillow', 'Wall Clock', 'Plant Pot', 'Candle Set', 'Picture Frame', 'Door Mat', 'Shelf Unit')
        'Sports'      = @('Yoga Mat', 'Resistance Bands', 'Jump Rope', 'Water Bottle', 'Foam Roller', 'Tennis Balls', 'Swim Goggles', 'Bike Light')
        'Food'        = @('Organic Coffee', 'Dark Chocolate', 'Trail Mix', 'Protein Bars', 'Green Tea', 'Olive Oil', 'Honey Jar', 'Granola')
        'Toys'        = @('Building Blocks', 'Board Game', 'Puzzle Set', 'Action Figure', 'Card Game', 'Stuffed Animal', 'Remote Car', 'Art Kit')
        'Health'      = @('Vitamin D', 'First Aid Kit', 'Hand Sanitizer', 'Face Mask Pack', 'Thermometer', 'Ice Pack', 'Eye Drops', 'Sunscreen')
    }

    [string[]]$categories = @('Electronics', 'Clothing', 'Books', 'Home', 'Sports', 'Food', 'Toys', 'Health')

    [System.Collections.Generic.List[PSCustomObject]]$products = [System.Collections.Generic.List[PSCustomObject]]::new()

    for ([int]$i = 0; $i -lt $Count; $i++) {
        [string]$category = $categories[$rng.Next($categories.Length)]
        [string[]]$categoryProducts = [string[]]$productsByCategory[$category]
        [string]$productName = $categoryProducts[$rng.Next($categoryProducts.Length)]

        # Append a variant number to ensure variety
        [int]$variant = $rng.Next(1, 100)
        [string]$name = "$productName v$variant"

        [string]$description = "High-quality $($productName.ToLower()) in the $($category.ToLower()) category. Model $variant."

        # Price range: $1.99 to $499.99, rounded to 2 decimals
        [double]$price = [math]::Round(1.99 + ($rng.NextDouble() * 498.0), 2)
        [int]$stock = $rng.Next(0, 500)

        [PSCustomObject]$product = [PSCustomObject]@{
            Name          = $name
            Description   = $description
            Price         = $price
            Category      = $category
            StockQuantity = $stock
        }
        $products.Add($product)
    }

    return [PSCustomObject[]]$products.ToArray()
}

function New-MockOrders {
    <#
    .SYNOPSIS
        Generates deterministic mock order data using a seeded RNG.
    .DESCRIPTION
        Generates orders referencing valid user and product IDs within
        the specified ranges, ensuring referential integrity is possible.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [int]$Seed,

        [Parameter(Mandatory)]
        [int]$Count,

        [Parameter(Mandatory)]
        [int]$MaxUserId,

        [Parameter(Mandatory)]
        [int]$MaxProductId
    )

    [System.Random]$rng = [System.Random]::new($Seed)
    [string[]]$statuses = @('pending', 'processing', 'shipped', 'delivered', 'cancelled')

    [System.Collections.Generic.List[PSCustomObject]]$orders = [System.Collections.Generic.List[PSCustomObject]]::new()

    for ([int]$i = 0; $i -lt $Count; $i++) {
        [int]$userId = $rng.Next(1, $MaxUserId + 1)
        [int]$productId = $rng.Next(1, $MaxProductId + 1)
        [int]$quantity = $rng.Next(1, 11)

        # Calculate a realistic total price (quantity * a random unit price)
        [double]$unitPrice = [math]::Round(5.0 + ($rng.NextDouble() * 200.0), 2)
        [double]$totalPrice = [math]::Round([double]$quantity * $unitPrice, 2)

        # Order date within the past year
        [int]$daysAgo = $rng.Next(0, 365)
        [string]$orderDate = [datetime]::new(2024, 6, 15).AddDays(-$daysAgo).ToString('yyyy-MM-dd')

        [string]$status = $statuses[$rng.Next($statuses.Length)]

        [PSCustomObject]$order = [PSCustomObject]@{
            UserId     = $userId
            ProductId  = $productId
            Quantity   = $quantity
            TotalPrice = $totalPrice
            OrderDate  = $orderDate
            Status     = $status
        }
        $orders.Add($order)
    }

    return [PSCustomObject[]]$orders.ToArray()
}

# ---------------------------------------------------------------------------
# Data Insertion
# ---------------------------------------------------------------------------

function Import-SeedData {
    <#
    .SYNOPSIS
        Seeds the database with deterministic mock data.
    .DESCRIPTION
        Generates and inserts users, products, and orders in the correct order
        to respect foreign key constraints. Uses transactions for atomicity.
        Uses different seed offsets for each data type to prevent correlation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection,

        [Parameter(Mandatory)]
        [int]$Seed,

        [Parameter(Mandatory)]
        [int]$UserCount,

        [Parameter(Mandatory)]
        [int]$ProductCount,

        [Parameter(Mandatory)]
        [int]$OrderCount
    )

    # Generate all data first, then insert in a transaction
    [PSCustomObject[]]$users = New-MockUsers -Seed $Seed -Count $UserCount
    [PSCustomObject[]]$products = New-MockProducts -Seed ([int]($Seed + 1000)) -Count $ProductCount
    [PSCustomObject[]]$orders = New-MockOrders -Seed ([int]($Seed + 2000)) -Count $OrderCount -MaxUserId $UserCount -MaxProductId $ProductCount

    [System.Data.Common.DbTransaction]$transaction = $Connection.BeginTransaction()

    try {
        # Insert users first (no foreign key dependencies)
        foreach ($user in $users) {
            [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
            $cmd.Transaction = $transaction
            $cmd.CommandText = 'INSERT INTO users (username, email, full_name, created_at) VALUES (@username, @email, @fullname, @createdat)'

            [System.Data.Common.DbParameter]$p1 = $cmd.CreateParameter()
            $p1.ParameterName = '@username'
            $p1.Value = [string]$user.Username
            [void]$cmd.Parameters.Add($p1)

            [System.Data.Common.DbParameter]$p2 = $cmd.CreateParameter()
            $p2.ParameterName = '@email'
            $p2.Value = [string]$user.Email
            [void]$cmd.Parameters.Add($p2)

            [System.Data.Common.DbParameter]$p3 = $cmd.CreateParameter()
            $p3.ParameterName = '@fullname'
            $p3.Value = [string]$user.FullName
            [void]$cmd.Parameters.Add($p3)

            [System.Data.Common.DbParameter]$p4 = $cmd.CreateParameter()
            $p4.ParameterName = '@createdat'
            $p4.Value = [string]$user.CreatedAt
            [void]$cmd.Parameters.Add($p4)

            [void]$cmd.ExecuteNonQuery()
            $cmd.Dispose()
        }

        # Insert products second (no foreign key dependencies)
        foreach ($product in $products) {
            [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
            $cmd.Transaction = $transaction
            $cmd.CommandText = 'INSERT INTO products (name, description, price, category, stock_quantity) VALUES (@name, @desc, @price, @category, @stock)'

            [System.Data.Common.DbParameter]$p1 = $cmd.CreateParameter()
            $p1.ParameterName = '@name'
            $p1.Value = [string]$product.Name
            [void]$cmd.Parameters.Add($p1)

            [System.Data.Common.DbParameter]$p2 = $cmd.CreateParameter()
            $p2.ParameterName = '@desc'
            $p2.Value = [string]$product.Description
            [void]$cmd.Parameters.Add($p2)

            [System.Data.Common.DbParameter]$p3 = $cmd.CreateParameter()
            $p3.ParameterName = '@price'
            $p3.Value = [double]$product.Price
            [void]$cmd.Parameters.Add($p3)

            [System.Data.Common.DbParameter]$p4 = $cmd.CreateParameter()
            $p4.ParameterName = '@category'
            $p4.Value = [string]$product.Category
            [void]$cmd.Parameters.Add($p4)

            [System.Data.Common.DbParameter]$p5 = $cmd.CreateParameter()
            $p5.ParameterName = '@stock'
            $p5.Value = [int]$product.StockQuantity
            [void]$cmd.Parameters.Add($p5)

            [void]$cmd.ExecuteNonQuery()
            $cmd.Dispose()
        }

        # Insert orders last (depends on users and products via foreign keys)
        foreach ($order in $orders) {
            [System.Data.Common.DbCommand]$cmd = $Connection.CreateCommand()
            $cmd.Transaction = $transaction
            $cmd.CommandText = 'INSERT INTO orders (user_id, product_id, quantity, total_price, order_date, status) VALUES (@userid, @productid, @quantity, @totalprice, @orderdate, @status)'

            [System.Data.Common.DbParameter]$p1 = $cmd.CreateParameter()
            $p1.ParameterName = '@userid'
            $p1.Value = [int]$order.UserId
            [void]$cmd.Parameters.Add($p1)

            [System.Data.Common.DbParameter]$p2 = $cmd.CreateParameter()
            $p2.ParameterName = '@productid'
            $p2.Value = [int]$order.ProductId
            [void]$cmd.Parameters.Add($p2)

            [System.Data.Common.DbParameter]$p3 = $cmd.CreateParameter()
            $p3.ParameterName = '@quantity'
            $p3.Value = [int]$order.Quantity
            [void]$cmd.Parameters.Add($p3)

            [System.Data.Common.DbParameter]$p4 = $cmd.CreateParameter()
            $p4.ParameterName = '@totalprice'
            $p4.Value = [double]$order.TotalPrice
            [void]$cmd.Parameters.Add($p4)

            [System.Data.Common.DbParameter]$p5 = $cmd.CreateParameter()
            $p5.ParameterName = '@orderdate'
            $p5.Value = [string]$order.OrderDate
            [void]$cmd.Parameters.Add($p5)

            [System.Data.Common.DbParameter]$p6 = $cmd.CreateParameter()
            $p6.ParameterName = '@status'
            $p6.Value = [string]$order.Status
            [void]$cmd.Parameters.Add($p6)

            [void]$cmd.ExecuteNonQuery()
            $cmd.Dispose()
        }

        $transaction.Commit()
    }
    catch {
        try { $transaction.Rollback() } catch { }
        throw "Failed to seed database: $_"
    }
    finally {
        $transaction.Dispose()
    }

    return [PSCustomObject]@{
        UsersInserted    = $UserCount
        ProductsInserted = $ProductCount
        OrdersInserted   = $OrderCount
    }
}

# ---------------------------------------------------------------------------
# Verification Queries
# ---------------------------------------------------------------------------

function Test-DataIntegrity {
    <#
    .SYNOPSIS
        Runs comprehensive verification queries against the seeded database.
    .DESCRIPTION
        Checks table existence, referential integrity, data validity,
        and computes aggregate statistics for verification.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection]$Connection
    )

    # Verify all three tables exist
    [string[]]$tables = Get-AllTables -Connection $Connection
    [bool]$tablesExist = ($tables -contains 'users') -and ($tables -contains 'products') -and ($tables -contains 'orders')

    # Check for orphaned orders (broken foreign keys)
    [int]$orphanedUserRefs = [int](Invoke-ScalarQuery -Connection $Connection -Query '
        SELECT COUNT(*) FROM orders o LEFT JOIN users u ON o.user_id = u.id WHERE u.id IS NULL')
    [int]$orphanedProductRefs = [int](Invoke-ScalarQuery -Connection $Connection -Query '
        SELECT COUNT(*) FROM orders o LEFT JOIN products p ON o.product_id = p.id WHERE p.id IS NULL')
    [bool]$noOrphanedOrders = ($orphanedUserRefs -eq 0) -and ($orphanedProductRefs -eq 0)

    # Verify all order totals are positive
    [int]$invalidTotals = [int](Invoke-ScalarQuery -Connection $Connection -Query '
        SELECT COUNT(*) FROM orders WHERE total_price <= 0')
    [bool]$allTotalsPositive = ($invalidTotals -eq 0)

    # Verify all product prices are valid
    [int]$invalidPrices = [int](Invoke-ScalarQuery -Connection $Connection -Query '
        SELECT COUNT(*) FROM products WHERE price <= 0')
    [bool]$allPricesValid = ($invalidPrices -eq 0)

    # Verify username uniqueness
    [int]$totalUsers = [int](Invoke-ScalarQuery -Connection $Connection -Query 'SELECT COUNT(*) FROM users')
    [int]$uniqueUsers = [int](Invoke-ScalarQuery -Connection $Connection -Query 'SELECT COUNT(DISTINCT username) FROM users')
    [bool]$uniqueUsernames = ($totalUsers -eq $uniqueUsers)

    # Record counts
    [int]$userCount = $totalUsers
    [int]$productCount = [int](Invoke-ScalarQuery -Connection $Connection -Query 'SELECT COUNT(*) FROM products')
    [int]$orderCount = [int](Invoke-ScalarQuery -Connection $Connection -Query 'SELECT COUNT(*) FROM orders')

    # Total revenue
    [object]$revenueResult = Invoke-ScalarQuery -Connection $Connection -Query 'SELECT SUM(total_price) FROM orders'
    [double]$totalRevenue = if ($null -eq $revenueResult -or $revenueResult -is [System.DBNull]) { 0.0 } else { [double]$revenueResult }

    # Top-spending user
    [PSCustomObject[]]$topSpenderRows = Invoke-QueryRows -Connection $Connection -Query '
        SELECT u.username, SUM(o.total_price) as total_spent
        FROM orders o JOIN users u ON o.user_id = u.id
        GROUP BY o.user_id ORDER BY total_spent DESC LIMIT 1'
    [string]$topSpender = if ($topSpenderRows.Count -gt 0) { [string]$topSpenderRows[0].username } else { '' }

    # Most ordered product
    [PSCustomObject[]]$topProductRows = Invoke-QueryRows -Connection $Connection -Query '
        SELECT p.name, COUNT(o.id) as order_count
        FROM orders o JOIN products p ON o.product_id = p.id
        GROUP BY o.product_id ORDER BY order_count DESC LIMIT 1'
    [string]$mostOrderedProduct = if ($topProductRows.Count -gt 0) { [string]$topProductRows[0].name } else { '' }

    # Average order value
    [object]$avgResult = Invoke-ScalarQuery -Connection $Connection -Query 'SELECT AVG(total_price) FROM orders'
    [double]$avgOrderValue = if ($null -eq $avgResult -or $avgResult -is [System.DBNull]) { 0.0 } else { [double]$avgResult }

    # Orders by status breakdown
    [PSCustomObject[]]$statusRows = Invoke-QueryRows -Connection $Connection -Query '
        SELECT status, COUNT(*) as cnt FROM orders GROUP BY status ORDER BY status'
    [hashtable]$ordersByStatus = @{}
    foreach ($row in $statusRows) {
        $ordersByStatus[[string]$row.status] = [int]$row.cnt
    }

    return [PSCustomObject]@{
        TablesExist        = $tablesExist
        NoOrphanedOrders   = $noOrphanedOrders
        AllTotalsPositive  = $allTotalsPositive
        AllPricesValid     = $allPricesValid
        UniqueUsernames    = $uniqueUsernames
        UserCount          = $userCount
        ProductCount       = $productCount
        OrderCount         = $orderCount
        TotalRevenue       = $totalRevenue
        TopSpender         = $topSpender
        MostOrderedProduct = $mostOrderedProduct
        AverageOrderValue  = $avgOrderValue
        OrdersByStatus     = $ordersByStatus
    }
}

# Export all public functions
Export-ModuleMember -Function @(
    'New-DatabaseConnection',
    'Initialize-Schema',
    'Get-TableColumns',
    'Get-ForeignKeys',
    'Get-AllTables',
    'Invoke-ScalarQuery',
    'Invoke-QueryRows',
    'Invoke-NonQuery',
    'New-MockUsers',
    'New-MockProducts',
    'New-MockOrders',
    'Import-SeedData',
    'Test-DataIntegrity'
)
