#!/usr/bin/env python3
import os
import re
import sys
import sqlite3
import bcrypt


# SQLite Database Connector
class Database:
    def __init__(self, db_name):
        """Starts the database connector"""
        self.conn = sqlite3.connect(db_name)
        self.cursor = self.conn.cursor()

    def create_table(self, table_name, columns):
        """Create table if not exists on database"""
        query = f"CREATE TABLE IF NOT EXISTS {table_name} ({columns})"
        self.cursor.execute(query)

    def insert_data(self, table_name, values):
        """Insert data on database"""
        placeholders = ', '.join(['?' for _ in values.split(",")])
        query = f"INSERT INTO {table_name} VALUES ({placeholders})"
        self.cursor.execute(query, values.split(","))
        self.conn.commit()

    def select_data(self, table_name, columns='*', condition=''):
        """Make query on database"""
        query = f"SELECT {columns} FROM {table_name} {condition}"
        self.cursor.execute(query)
        return self.cursor.fetchone()

    def update_data(self, table_name, set_values, condition):
        """Update data on database"""
        query = f"UPDATE {table_name} SET {set_values} {condition}"
        self.cursor.execute(query)
        self.conn.commit()

    def delete_data(self, table_name, condition):
        """Delete an existent data on database"""
        query = f"DELETE FROM {table_name} {condition}"
        self.cursor.execute(query)
        self.conn.commit()

    def close_connection(self):
        """Close database connection"""
        self.conn.close()


# MultiVPN Auth Class
class MultivpnAuth:
    def __init__(self):
        """Manage the auth for MultiVPN"""
        self.db = Database("users.db")
        self.user_regex = r"^[a-zA-Z0-9_]{4,32}$"
        self.password_regex = r"^[a-zA-Z0-9_]{8,32}$"
        self.check_database()

    def close_connection(self):
        """Close sqlite connection"""
        self.db.close_connection()

    def check_database(self):
        """Create auth table if not exists"""
        self.db.create_table("users", "username TEXT, password TEXT")

    def create_user(self, user, password):
        """Create new user from vpn auth"""
        hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
        self.db.insert_data("users", f"{user},{hashed.decode()}")

    def delete_user(self, user):
        """Delete user from vpn auth"""
        self.db.delete_data("users", f"WHERE username='{user}'")

    def authenticate(self, user, password):
        """Check if the user exists and test login"""
        user_re = re.compile(self.user_regex)
        pass_re = re.compile(self.password_regex)
        if user_re.match(str(user)) and pass_re.match(str(password)):
            user = self.db.select_data(
                "users", "password", 
                f"WHERE username='{user}'"
            )
            if user and bcrypt.checkpw(
                password.encode(), user[0].encode()):
                return True
        return False


if __name__ == '__main__':
    """Starts the authenticator"""
    auth = MultivpnAuth()
    if len(sys.argv) > 1:
        if sys.argv[1] == 'manage':
            username = input("Username: ")
            if sys.argv[2] in ['-c', '--create']:
                password = input(f"Password for {username}: ")
                auth.create_user(username, password)
            elif sys.argv[2] in ['-r', '--remove']:
                auth.delete_user(username)
            elif sys.argv[2] in ['-a', '--auth']:
                password = input(f"Password for {username}: ")
                print(auth.authenticate(username, password))
        else:
            username = os.environ.get('username')
            password = os.environ.get('password')
            if auth.authenticate(username, password):
                sys.exit(0)
    sys.exit(1)
