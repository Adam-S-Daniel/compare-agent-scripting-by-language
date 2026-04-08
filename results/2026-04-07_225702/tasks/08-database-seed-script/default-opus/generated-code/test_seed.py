"""Tests for the database seed script using red/green TDD methodology."""

import sqlite3
import os
import random
import pytest

# We'll import from seed.py once it exists
# RED: This import will fail — seed.py doesn't exist yet.
from seed import (
    create_schema, generate_users, generate_products, generate_orders,
    insert_users, insert_products, insert_orders, seed_database,
    run_verification_queries, DB_PATH, RNG_SEED,
)


class TestSchema:
    """RED phase: tests for schema creation — these fail because seed.py doesn't exist."""

    def setup_method(self):
        """Use an in-memory database for isolation."""
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys = ON")

    def teardown_method(self):
        self.conn.close()

    def test_create_schema_creates_users_table(self):
        create_schema(self.conn)
        cur = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
        )
        assert cur.fetchone() is not None, "users table should exist"

    def test_create_schema_creates_products_table(self):
        create_schema(self.conn)
        cur = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='products'"
        )
        assert cur.fetchone() is not None, "products table should exist"

    def test_create_schema_creates_orders_table(self):
        create_schema(self.conn)
        cur = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='orders'"
        )
        assert cur.fetchone() is not None, "orders table should exist"

    def test_users_table_columns(self):
        create_schema(self.conn)
        cur = self.conn.execute("PRAGMA table_info(users)")
        columns = {row[1]: row[2] for row in cur.fetchall()}
        assert "id" in columns
        assert "name" in columns
        assert "email" in columns
        assert "created_at" in columns

    def test_products_table_columns(self):
        create_schema(self.conn)
        cur = self.conn.execute("PRAGMA table_info(products)")
        columns = {row[1]: row[2] for row in cur.fetchall()}
        assert "id" in columns
        assert "name" in columns
        assert "price" in columns
        assert "category" in columns

    def test_orders_table_columns(self):
        create_schema(self.conn)
        cur = self.conn.execute("PRAGMA table_info(orders)")
        columns = {row[1]: row[2] for row in cur.fetchall()}
        assert "id" in columns
        assert "user_id" in columns
        assert "product_id" in columns
        assert "quantity" in columns
        assert "order_date" in columns

    def test_orders_foreign_key_to_users(self):
        create_schema(self.conn)
        cur = self.conn.execute("PRAGMA foreign_key_list(orders)")
        fks = {row[2]: row[3] for row in cur.fetchall()}  # table -> from-column
        assert "users" in fks, "orders should have FK to users"

    def test_orders_foreign_key_to_products(self):
        create_schema(self.conn)
        cur = self.conn.execute("PRAGMA foreign_key_list(orders)")
        fks = {row[2]: row[3] for row in cur.fetchall()}
        assert "products" in fks, "orders should have FK to products"


class TestDataGeneration:
    """RED phase: tests for deterministic mock data generation."""

    def test_generate_users_returns_expected_count(self):
        rng = random.Random(RNG_SEED)
        users = generate_users(rng, count=20)
        assert len(users) == 20

    def test_generate_users_have_required_fields(self):
        rng = random.Random(RNG_SEED)
        users = generate_users(rng, count=5)
        for user in users:
            assert "name" in user
            assert "email" in user
            assert "created_at" in user

    def test_generate_users_unique_emails(self):
        rng = random.Random(RNG_SEED)
        users = generate_users(rng, count=50)
        emails = [u["email"] for u in users]
        assert len(emails) == len(set(emails)), "emails must be unique"

    def test_generate_users_deterministic(self):
        """Same seed produces identical data."""
        users_a = generate_users(random.Random(RNG_SEED), count=10)
        users_b = generate_users(random.Random(RNG_SEED), count=10)
        assert users_a == users_b

    def test_generate_products_returns_expected_count(self):
        rng = random.Random(RNG_SEED)
        products = generate_products(rng, count=15)
        assert len(products) == 15

    def test_generate_products_have_required_fields(self):
        rng = random.Random(RNG_SEED)
        products = generate_products(rng, count=5)
        for p in products:
            assert "name" in p
            assert "price" in p and p["price"] > 0
            assert "category" in p

    def test_generate_products_deterministic(self):
        products_a = generate_products(random.Random(RNG_SEED), count=10)
        products_b = generate_products(random.Random(RNG_SEED), count=10)
        assert products_a == products_b

    def test_generate_orders_returns_expected_count(self):
        rng = random.Random(RNG_SEED)
        orders = generate_orders(rng, user_ids=[1, 2, 3], product_ids=[1, 2], count=25)
        assert len(orders) == 25

    def test_generate_orders_respect_referential_integrity(self):
        """Order user_id and product_id must come from the provided ID lists."""
        rng = random.Random(RNG_SEED)
        user_ids = [10, 20, 30]
        product_ids = [100, 200]
        orders = generate_orders(rng, user_ids=user_ids, product_ids=product_ids, count=50)
        for o in orders:
            assert o["user_id"] in user_ids, f"user_id {o['user_id']} not in allowed set"
            assert o["product_id"] in product_ids, f"product_id {o['product_id']} not in allowed set"

    def test_generate_orders_have_required_fields(self):
        rng = random.Random(RNG_SEED)
        orders = generate_orders(rng, user_ids=[1], product_ids=[1], count=5)
        for o in orders:
            assert "user_id" in o
            assert "product_id" in o
            assert "quantity" in o and o["quantity"] > 0
            assert "order_date" in o

    def test_generate_orders_deterministic(self):
        orders_a = generate_orders(random.Random(RNG_SEED), [1, 2], [1, 2], count=10)
        orders_b = generate_orders(random.Random(RNG_SEED), [1, 2], [1, 2], count=10)
        assert orders_a == orders_b


class TestInsertion:
    """RED phase: tests for inserting data into the database."""

    def setup_method(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys = ON")
        create_schema(self.conn)
        self.rng = random.Random(RNG_SEED)

    def teardown_method(self):
        self.conn.close()

    def test_insert_users_populates_table(self):
        users = generate_users(self.rng, count=10)
        insert_users(self.conn, users)
        count = self.conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        assert count == 10

    def test_insert_products_populates_table(self):
        products = generate_products(self.rng, count=8)
        insert_products(self.conn, products)
        count = self.conn.execute("SELECT COUNT(*) FROM products").fetchone()[0]
        assert count == 8

    def test_insert_users_returns_ids(self):
        users = generate_users(self.rng, count=5)
        ids = insert_users(self.conn, users)
        assert len(ids) == 5
        assert all(isinstance(i, int) for i in ids)

    def test_insert_products_returns_ids(self):
        products = generate_products(self.rng, count=5)
        ids = insert_products(self.conn, products)
        assert len(ids) == 5

    def test_insert_orders_populates_table(self):
        user_ids = insert_users(self.conn, generate_users(self.rng, count=3))
        prod_ids = insert_products(self.conn, generate_products(self.rng, count=3))
        orders = generate_orders(self.rng, user_ids, prod_ids, count=15)
        insert_orders(self.conn, orders)
        count = self.conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]
        assert count == 15

    def test_foreign_key_violation_rejected(self):
        """Inserting an order with a non-existent user_id must fail."""
        insert_products(self.conn, generate_products(self.rng, count=1))
        bad_order = [{"user_id": 9999, "product_id": 1, "quantity": 1,
                      "order_date": "2024-01-01"}]
        with pytest.raises(sqlite3.IntegrityError):
            insert_orders(self.conn, bad_order)

    def test_seed_database_end_to_end(self):
        """Full seeding populates all three tables with consistent data."""
        seed_database(self.conn)
        users = self.conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        products = self.conn.execute("SELECT COUNT(*) FROM products").fetchone()[0]
        orders = self.conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]
        assert users > 0
        assert products > 0
        assert orders > 0

    def test_seed_database_all_order_fks_valid(self):
        """Every order references an existing user and product."""
        seed_database(self.conn)
        # Orders with invalid user_id
        orphan_users = self.conn.execute("""
            SELECT COUNT(*) FROM orders o
            LEFT JOIN users u ON o.user_id = u.id
            WHERE u.id IS NULL
        """).fetchone()[0]
        assert orphan_users == 0, "found orders referencing non-existent users"

        # Orders with invalid product_id
        orphan_products = self.conn.execute("""
            SELECT COUNT(*) FROM orders o
            LEFT JOIN products p ON o.product_id = p.id
            WHERE p.id IS NULL
        """).fetchone()[0]
        assert orphan_products == 0, "found orders referencing non-existent products"


class TestVerificationQueries:
    """RED phase: tests for the verification query suite that confirms data consistency."""

    def setup_method(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys = ON")
        seed_database(self.conn)

    def teardown_method(self):
        self.conn.close()

    def test_verification_returns_dict(self):
        results = run_verification_queries(self.conn)
        assert isinstance(results, dict)

    def test_verification_has_row_counts(self):
        results = run_verification_queries(self.conn)
        assert "user_count" in results
        assert "product_count" in results
        assert "order_count" in results
        assert results["user_count"] == 30
        assert results["product_count"] == 25
        assert results["order_count"] == 100

    def test_verification_has_revenue_by_category(self):
        """Revenue per category: SUM(price * quantity) grouped by product category."""
        results = run_verification_queries(self.conn)
        assert "revenue_by_category" in results
        assert len(results["revenue_by_category"]) > 0
        # Each entry should be (category, revenue)
        for category, revenue in results["revenue_by_category"]:
            assert isinstance(category, str)
            assert revenue > 0

    def test_verification_has_top_customers(self):
        """Top customers by total order count."""
        results = run_verification_queries(self.conn)
        assert "top_customers" in results
        assert len(results["top_customers"]) > 0

    def test_verification_has_orders_per_user_stats(self):
        """Average orders per user."""
        results = run_verification_queries(self.conn)
        assert "avg_orders_per_user" in results
        assert results["avg_orders_per_user"] > 0

    def test_verification_has_orphan_check(self):
        """Zero orphaned orders (FK integrity)."""
        results = run_verification_queries(self.conn)
        assert "orphaned_orders" in results
        assert results["orphaned_orders"] == 0

    def test_verification_deterministic(self):
        """Same seed ⇒ same verification results."""
        conn2 = sqlite3.connect(":memory:")
        conn2.execute("PRAGMA foreign_keys = ON")
        seed_database(conn2)
        r1 = run_verification_queries(self.conn)
        r2 = run_verification_queries(conn2)
        conn2.close()
        assert r1 == r2


class TestErrorHandling:
    """Tests for graceful error handling."""

    def test_duplicate_email_raises_integrity_error(self):
        conn = sqlite3.connect(":memory:")
        conn.execute("PRAGMA foreign_keys = ON")
        create_schema(conn)
        user = [{"name": "Test", "email": "dup@test.com", "created_at": "2024-01-01"}]
        insert_users(conn, user)
        with pytest.raises(sqlite3.IntegrityError):
            insert_users(conn, user)
        conn.close()

    def test_negative_price_rejected(self):
        conn = sqlite3.connect(":memory:")
        conn.execute("PRAGMA foreign_keys = ON")
        create_schema(conn)
        with pytest.raises(sqlite3.IntegrityError):
            insert_products(conn, [{"name": "Bad", "price": -5, "category": "X"}])
        conn.close()

    def test_zero_quantity_rejected(self):
        conn = sqlite3.connect(":memory:")
        conn.execute("PRAGMA foreign_keys = ON")
        create_schema(conn)
        insert_users(conn, [{"name": "A", "email": "a@b.com", "created_at": "2024-01-01"}])
        insert_products(conn, [{"name": "P", "price": 1.0, "category": "C"}])
        with pytest.raises(sqlite3.IntegrityError):
            insert_orders(conn, [{"user_id": 1, "product_id": 1, "quantity": 0, "order_date": "2024-01-01"}])
        conn.close()
