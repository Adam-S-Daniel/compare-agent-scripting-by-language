"""
TDD tests for SQLite database seed script.

Approach: Red/Green/Refactor methodology
-----------------------------------------
Tests were written FIRST in groups (red), then implementation code was
written to make each group pass (green), then refactored as needed.

Test groups follow the natural dependency order:
  1. Schema creation  - tables, columns, constraints, foreign keys
  2. Data generation  - deterministic mock data from seeded RNG
  3. Data insertion   - referential integrity, correct row counts
  4. Verification     - consistency queries across all tables
"""

import unittest
import sqlite3
import os
import tempfile

# Import the module under test
from db_seed import (
    create_schema,
    generate_users,
    generate_products,
    generate_orders,
    seed_database,
    run_verification_queries,
    SEED,
)


class TestSchemaCreation(unittest.TestCase):
    """
    TDD Cycle 1: Schema creation
    RED  - wrote these tests before create_schema existed
    GREEN - implemented create_schema with CREATE TABLE statements
    """

    def setUp(self):
        """Create a fresh in-memory database for each test."""
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys = ON")
        create_schema(self.conn)

    def tearDown(self):
        self.conn.close()

    def test_users_table_exists(self):
        """users table must be created."""
        cursor = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
        )
        self.assertIsNotNone(cursor.fetchone(), "users table should exist")

    def test_products_table_exists(self):
        """products table must be created."""
        cursor = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='products'"
        )
        self.assertIsNotNone(cursor.fetchone(), "products table should exist")

    def test_orders_table_exists(self):
        """orders table must be created."""
        cursor = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='orders'"
        )
        self.assertIsNotNone(cursor.fetchone(), "orders table should exist")

    def test_users_columns(self):
        """users table must have id, name, email, created_at."""
        cursor = self.conn.execute("PRAGMA table_info(users)")
        columns = {row[1] for row in cursor.fetchall()}
        expected = {"id", "name", "email", "created_at"}
        self.assertEqual(columns, expected)

    def test_products_columns(self):
        """products table must have id, name, price, category, stock."""
        cursor = self.conn.execute("PRAGMA table_info(products)")
        columns = {row[1] for row in cursor.fetchall()}
        expected = {"id", "name", "price", "category", "stock"}
        self.assertEqual(columns, expected)

    def test_orders_columns(self):
        """orders table must have id, user_id, product_id, quantity, total_price, order_date."""
        cursor = self.conn.execute("PRAGMA table_info(orders)")
        columns = {row[1] for row in cursor.fetchall()}
        expected = {"id", "user_id", "product_id", "quantity", "total_price", "order_date"}
        self.assertEqual(columns, expected)

    def test_orders_foreign_key_to_users(self):
        """orders.user_id must reference users.id."""
        cursor = self.conn.execute("PRAGMA foreign_key_list(orders)")
        fks = cursor.fetchall()
        referenced_tables = {row[2] for row in fks}
        self.assertIn("users", referenced_tables)

    def test_orders_foreign_key_to_products(self):
        """orders.product_id must reference products.id."""
        cursor = self.conn.execute("PRAGMA foreign_key_list(orders)")
        fks = cursor.fetchall()
        referenced_tables = {row[2] for row in fks}
        self.assertIn("products", referenced_tables)

    def test_users_email_unique(self):
        """users.email must have a UNIQUE constraint."""
        self.conn.execute(
            "INSERT INTO users (name, email, created_at) VALUES ('A', 'dup@x.com', '2024-01-01')"
        )
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute(
                "INSERT INTO users (name, email, created_at) VALUES ('B', 'dup@x.com', '2024-01-01')"
            )

    def test_foreign_key_enforcement(self):
        """Inserting an order with a non-existent user_id must fail."""
        # Insert a valid product first
        self.conn.execute(
            "INSERT INTO products (name, price, category, stock) VALUES ('X', 10.0, 'cat', 5)"
        )
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute(
                "INSERT INTO orders (user_id, product_id, quantity, total_price, order_date) "
                "VALUES (999, 1, 1, 10.0, '2024-01-01')"
            )


class TestDataGeneration(unittest.TestCase):
    """
    TDD Cycle 2: Deterministic data generation
    RED  - wrote these tests before generate_* functions existed
    GREEN - implemented generators with seeded random.Random
    """

    def test_generate_users_count(self):
        """generate_users returns the requested number of user records."""
        users = generate_users(20, seed=SEED)
        self.assertEqual(len(users), 20)

    def test_generate_users_fields(self):
        """Each user record must have name, email, and created_at fields."""
        users = generate_users(5, seed=SEED)
        for user in users:
            self.assertIn("name", user)
            self.assertIn("email", user)
            self.assertIn("created_at", user)

    def test_generate_users_unique_emails(self):
        """All generated emails must be unique."""
        users = generate_users(50, seed=SEED)
        emails = [u["email"] for u in users]
        self.assertEqual(len(emails), len(set(emails)), "emails must be unique")

    def test_generate_users_deterministic(self):
        """Same seed must produce identical output."""
        users_a = generate_users(10, seed=42)
        users_b = generate_users(10, seed=42)
        self.assertEqual(users_a, users_b)

    def test_generate_products_count(self):
        """generate_products returns the requested number of products."""
        products = generate_products(15, seed=SEED)
        self.assertEqual(len(products), 15)

    def test_generate_products_fields(self):
        """Each product must have name, price, category, and stock."""
        products = generate_products(5, seed=SEED)
        for p in products:
            self.assertIn("name", p)
            self.assertIn("price", p)
            self.assertIn("category", p)
            self.assertIn("stock", p)

    def test_generate_products_positive_price(self):
        """All product prices must be positive."""
        products = generate_products(30, seed=SEED)
        for p in products:
            self.assertGreater(p["price"], 0, "price must be positive")

    def test_generate_products_nonnegative_stock(self):
        """Stock must be non-negative."""
        products = generate_products(30, seed=SEED)
        for p in products:
            self.assertGreaterEqual(p["stock"], 0)

    def test_generate_products_deterministic(self):
        """Same seed must produce identical products."""
        a = generate_products(10, seed=42)
        b = generate_products(10, seed=42)
        self.assertEqual(a, b)

    def test_generate_orders_count(self):
        """generate_orders returns the requested number of orders."""
        users = generate_users(10, seed=SEED)
        products = generate_products(10, seed=SEED)
        orders = generate_orders(50, users, products, seed=SEED)
        self.assertEqual(len(orders), 50)

    def test_generate_orders_fields(self):
        """Each order must have user_id, product_id, quantity, total_price, order_date."""
        users = generate_users(5, seed=SEED)
        products = generate_products(5, seed=SEED)
        orders = generate_orders(10, users, products, seed=SEED)
        for o in orders:
            self.assertIn("user_id", o)
            self.assertIn("product_id", o)
            self.assertIn("quantity", o)
            self.assertIn("total_price", o)
            self.assertIn("order_date", o)

    def test_generate_orders_valid_references(self):
        """All order user_id and product_id must be within valid range."""
        users = generate_users(10, seed=SEED)
        products = generate_products(10, seed=SEED)
        orders = generate_orders(50, users, products, seed=SEED)
        for o in orders:
            self.assertGreaterEqual(o["user_id"], 1)
            self.assertLessEqual(o["user_id"], len(users))
            self.assertGreaterEqual(o["product_id"], 1)
            self.assertLessEqual(o["product_id"], len(products))

    def test_generate_orders_positive_quantity(self):
        """Order quantity must be positive."""
        users = generate_users(5, seed=SEED)
        products = generate_products(5, seed=SEED)
        orders = generate_orders(20, users, products, seed=SEED)
        for o in orders:
            self.assertGreater(o["quantity"], 0)

    def test_generate_orders_total_price_matches(self):
        """total_price should equal quantity * product price."""
        users = generate_users(5, seed=SEED)
        products = generate_products(5, seed=SEED)
        orders = generate_orders(20, users, products, seed=SEED)
        for o in orders:
            product = products[o["product_id"] - 1]  # 1-indexed to 0-indexed
            expected = round(o["quantity"] * product["price"], 2)
            self.assertAlmostEqual(o["total_price"], expected, places=2)

    def test_generate_orders_deterministic(self):
        """Same seed must produce identical orders."""
        users = generate_users(5, seed=SEED)
        products = generate_products(5, seed=SEED)
        a = generate_orders(10, users, products, seed=42)
        b = generate_orders(10, users, products, seed=42)
        self.assertEqual(a, b)


class TestDataInsertion(unittest.TestCase):
    """
    TDD Cycle 3: Inserting data while respecting referential integrity
    RED  - wrote these tests before seed_database existed
    GREEN - implemented seed_database that inserts users, products, then orders
    """

    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys = ON")
        # Use known counts for predictable testing
        self.num_users = 20
        self.num_products = 15
        self.num_orders = 50
        seed_database(
            self.conn,
            num_users=self.num_users,
            num_products=self.num_products,
            num_orders=self.num_orders,
            seed=SEED,
        )

    def tearDown(self):
        self.conn.close()

    def test_users_row_count(self):
        """Correct number of users must be inserted."""
        count = self.conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        self.assertEqual(count, self.num_users)

    def test_products_row_count(self):
        """Correct number of products must be inserted."""
        count = self.conn.execute("SELECT COUNT(*) FROM products").fetchone()[0]
        self.assertEqual(count, self.num_products)

    def test_orders_row_count(self):
        """Correct number of orders must be inserted."""
        count = self.conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]
        self.assertEqual(count, self.num_orders)

    def test_no_null_user_names(self):
        """No user name should be NULL."""
        count = self.conn.execute("SELECT COUNT(*) FROM users WHERE name IS NULL").fetchone()[0]
        self.assertEqual(count, 0)

    def test_no_null_product_names(self):
        """No product name should be NULL."""
        count = self.conn.execute("SELECT COUNT(*) FROM products WHERE name IS NULL").fetchone()[0]
        self.assertEqual(count, 0)

    def test_all_order_users_exist(self):
        """Every order.user_id must reference an existing user."""
        orphans = self.conn.execute(
            "SELECT COUNT(*) FROM orders WHERE user_id NOT IN (SELECT id FROM users)"
        ).fetchone()[0]
        self.assertEqual(orphans, 0, "no orphan orders for users")

    def test_all_order_products_exist(self):
        """Every order.product_id must reference an existing product."""
        orphans = self.conn.execute(
            "SELECT COUNT(*) FROM orders WHERE product_id NOT IN (SELECT id FROM products)"
        ).fetchone()[0]
        self.assertEqual(orphans, 0, "no orphan orders for products")

    def test_unique_emails_in_database(self):
        """All emails in the database must be unique."""
        total = self.conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        distinct = self.conn.execute("SELECT COUNT(DISTINCT email) FROM users").fetchone()[0]
        self.assertEqual(total, distinct)

    def test_seeded_insertion_is_deterministic(self):
        """Re-seeding with the same seed produces identical data."""
        conn2 = sqlite3.connect(":memory:")
        conn2.execute("PRAGMA foreign_keys = ON")
        seed_database(
            conn2,
            num_users=self.num_users,
            num_products=self.num_products,
            num_orders=self.num_orders,
            seed=SEED,
        )
        # Compare all users
        users1 = self.conn.execute("SELECT * FROM users ORDER BY id").fetchall()
        users2 = conn2.execute("SELECT * FROM users ORDER BY id").fetchall()
        self.assertEqual(users1, users2)

        # Compare all products
        products1 = self.conn.execute("SELECT * FROM products ORDER BY id").fetchall()
        products2 = conn2.execute("SELECT * FROM products ORDER BY id").fetchall()
        self.assertEqual(products1, products2)

        # Compare all orders
        orders1 = self.conn.execute("SELECT * FROM orders ORDER BY id").fetchall()
        orders2 = conn2.execute("SELECT * FROM orders ORDER BY id").fetchall()
        self.assertEqual(orders1, orders2)
        conn2.close()


class TestVerificationQueries(unittest.TestCase):
    """
    TDD Cycle 4: Verification queries that confirm data consistency
    RED  - wrote these tests before run_verification_queries existed
    GREEN - implemented run_verification_queries returning a dict of results
    """

    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys = ON")
        self.num_users = 20
        self.num_products = 15
        self.num_orders = 50
        seed_database(
            self.conn,
            num_users=self.num_users,
            num_products=self.num_products,
            num_orders=self.num_orders,
            seed=SEED,
        )
        self.results = run_verification_queries(self.conn)

    def tearDown(self):
        self.conn.close()

    def test_returns_dict(self):
        """Verification must return a dictionary of results."""
        self.assertIsInstance(self.results, dict)

    def test_total_users_count(self):
        """Verification must report correct user count."""
        self.assertEqual(self.results["total_users"], self.num_users)

    def test_total_products_count(self):
        """Verification must report correct product count."""
        self.assertEqual(self.results["total_products"], self.num_products)

    def test_total_orders_count(self):
        """Verification must report correct order count."""
        self.assertEqual(self.results["total_orders"], self.num_orders)

    def test_orphan_orders_users(self):
        """There must be zero orders referencing non-existent users."""
        self.assertEqual(self.results["orphan_orders_users"], 0)

    def test_orphan_orders_products(self):
        """There must be zero orders referencing non-existent products."""
        self.assertEqual(self.results["orphan_orders_products"], 0)

    def test_revenue_per_user(self):
        """Revenue per user must be a non-empty list of (user_name, total_spent) tuples."""
        rpu = self.results["revenue_per_user"]
        self.assertGreater(len(rpu), 0)
        # Each entry is (name, total_spent)
        for name, total in rpu:
            self.assertIsInstance(name, str)
            self.assertGreater(total, 0)

    def test_top_products_by_orders(self):
        """Top products must list products ordered at least once."""
        top = self.results["top_products_by_orders"]
        self.assertGreater(len(top), 0)
        for name, count in top:
            self.assertIsInstance(name, str)
            self.assertGreater(count, 0)

    def test_average_order_value(self):
        """Average order value must be a positive number."""
        avg = self.results["avg_order_value"]
        self.assertGreater(avg, 0)

    def test_orders_per_category(self):
        """Orders per category must have at least one category."""
        opc = self.results["orders_per_category"]
        self.assertGreater(len(opc), 0)
        for category, count in opc:
            self.assertIsInstance(category, str)
            self.assertGreater(count, 0)

    def test_total_revenue(self):
        """Total revenue must match sum of all order total_prices."""
        expected = self.conn.execute("SELECT SUM(total_price) FROM orders").fetchone()[0]
        self.assertAlmostEqual(self.results["total_revenue"], expected, places=2)

    def test_users_with_no_orders_count(self):
        """Must report count of users who placed zero orders."""
        # This is a valid metric - some users may have no orders
        self.assertIn("users_with_no_orders", self.results)
        self.assertGreaterEqual(self.results["users_with_no_orders"], 0)


class TestErrorHandling(unittest.TestCase):
    """
    TDD Cycle 5: Graceful error handling
    RED  - wrote these tests before error paths were handled
    GREEN - added try/except blocks with meaningful messages
    """

    def test_create_schema_on_closed_connection(self):
        """create_schema must raise a clear error on a closed connection."""
        conn = sqlite3.connect(":memory:")
        conn.close()
        with self.assertRaises(RuntimeError) as ctx:
            create_schema(conn)
        self.assertIn("schema", str(ctx.exception).lower())

    def test_seed_database_on_closed_connection(self):
        """seed_database must raise a clear error on a closed connection."""
        conn = sqlite3.connect(":memory:")
        conn.close()
        with self.assertRaises(RuntimeError) as ctx:
            seed_database(conn, num_users=5, num_products=5, num_orders=10, seed=SEED)
        self.assertIn("database", str(ctx.exception).lower())

    def test_generate_orders_empty_users(self):
        """generate_orders must raise ValueError if users list is empty."""
        products = generate_products(5, seed=SEED)
        with self.assertRaises(ValueError) as ctx:
            generate_orders(10, [], products, seed=SEED)
        self.assertIn("users", str(ctx.exception).lower())

    def test_generate_orders_empty_products(self):
        """generate_orders must raise ValueError if products list is empty."""
        users = generate_users(5, seed=SEED)
        with self.assertRaises(ValueError) as ctx:
            generate_orders(10, users, [], seed=SEED)
        self.assertIn("products", str(ctx.exception).lower())


if __name__ == "__main__":
    unittest.main()
