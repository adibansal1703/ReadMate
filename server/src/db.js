const { Pool, Client } = require('pg');
require('dotenv').config();

const connectionString = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/readmate';

const pool = new Pool({
  connectionString: connectionString,
  ssl: connectionString.includes('sslmode=require') || connectionString.includes('neon.tech') || connectionString.includes('render.com')
    ? { rejectUnauthorized: false }
    : false,
});

async function ensureDatabaseExists() {
  try {
    const url = new URL(connectionString);
    const dbName = url.pathname.replace('/', '') || 'readmate';

    url.pathname = '/postgres';
    const systemClient = new Client({
      connectionString: url.toString(),
      ssl: connectionString.includes('sslmode=require') ? { rejectUnauthorized: false } : false,
    });

    await systemClient.connect();
    const res = await systemClient.query('SELECT 1 FROM pg_database WHERE datname = $1', [dbName]);
    if (res.rows.length === 0) {
      console.log(`[DB] Database "${dbName}" does not exist. Creating it now...`);
      await systemClient.query(`CREATE DATABASE "${dbName}";`);
      console.log(`[DB] Database "${dbName}" created successfully.`);
    }
    await systemClient.end();
  } catch (err) {
  }
}

async function initDb() {
  await ensureDatabaseExists();

  let client;
  try {
    client = await pool.connect();
  } catch (err) {
    if (err.code === '28P01') {
      console.error('\n================================================================');
      console.error('❌ POSTGRESQL AUTHENTICATION ERROR (28P01)');
      console.error('The password for user "postgres" in DATABASE_URL is incorrect.');
      console.error('Please create a file named ".env" inside "server/" folder with:');
      console.error('DATABASE_URL=postgresql://postgres:YOUR_REAL_PASSWORD@localhost:5432/readmate');
      console.error('================================================================\n');
    } else if (err.code === '3D000') {
      console.error('\n================================================================');
      console.error('❌ DATABASE DOES NOT EXIST ERROR (3D000)');
      console.error('The database "readmate" does not exist yet.');
      console.error('Please run in pgAdmin or psql command line: CREATE DATABASE readmate;');
      console.error('================================================================\n');
    }
    throw err;
  }

  try {
    await client.query('BEGIN');

    await client.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";');

    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        is_verified BOOLEAN DEFAULT false,
        verification_code VARCHAR(255),
        verification_expires TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_code VARCHAR(255);
      ALTER TABLE users ALTER COLUMN verification_code TYPE VARCHAR(255);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_expires TIMESTAMP WITH TIME ZONE;
      CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_idx ON users (LOWER(email));
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS profiles (
        id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        username VARCHAR(100) UNIQUE NOT NULL,
        email VARCHAR(255) NOT NULL,
        display_name VARCHAR(150),
        yearly_goal INTEGER DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_idx ON profiles (LOWER(username));
      CREATE UNIQUE INDEX IF NOT EXISTS profiles_email_lower_idx ON profiles (LOWER(email));
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS books (
        id SERIAL PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        subtitle VARCHAR(255),
        author VARCHAR(255),
        description TEXT,
        status VARCHAR(50) DEFAULT '2',
        favourite BOOLEAN DEFAULT false,
        deleted BOOLEAN DEFAULT false,
        rating DOUBLE PRECISION DEFAULT 0,
        pages INTEGER DEFAULT 0,
        publication_year INTEGER,
        isbn VARCHAR(100),
        olid VARCHAR(100),
        tags TEXT,
        notes TEXT,
        current_page INTEGER DEFAULT 0,
        cover_url TEXT,
        blur_hash TEXT,
        book_type VARCHAR(50) DEFAULT 'paperback',
        readings TEXT,
        date_added TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        date_modified TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await client.query(`
      ALTER TABLE books ADD COLUMN IF NOT EXISTS subtitle VARCHAR(255);
      ALTER TABLE books ADD COLUMN IF NOT EXISTS description TEXT;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS favourite BOOLEAN DEFAULT false;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT false;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS pages INTEGER DEFAULT 0;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS publication_year INTEGER;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS isbn VARCHAR(100);
      ALTER TABLE books ADD COLUMN IF NOT EXISTS olid VARCHAR(100);
      ALTER TABLE books ADD COLUMN IF NOT EXISTS tags TEXT;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS current_page INTEGER DEFAULT 0;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS blur_hash TEXT;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS book_type VARCHAR(50) DEFAULT 'paperback';
      ALTER TABLE books ADD COLUMN IF NOT EXISTS readings TEXT;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS date_added TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
      ALTER TABLE books ADD COLUMN IF NOT EXISTS date_modified TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS book_history (
        id SERIAL PRIMARY KEY,
        book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        event_type VARCHAR(50) NOT NULL,
        description TEXT,
        page_number INTEGER,
        note_content TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await client.query('COMMIT');
    console.log('[DB] PostgreSQL schema initialized & upgraded successfully.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[DB] Database initialization error:', err);
  } finally {
    if (client) client.release();
  }
}

async function purgeUnconfirmedUsers() {
  try {
    const res = await pool.query(`
      DELETE FROM users
      WHERE is_verified = false
        AND created_at < NOW() - INTERVAL '24 hours'
      RETURNING id, email;
    `);
    if (res.rowCount > 0) {
      console.log(`[DB PURGE] Auto-purged ${res.rowCount} stale unconfirmed account(s) older than 24 hours.`);
    }
  } catch (err) {
    console.error('[DB PURGE ERROR] Failed to purge unconfirmed accounts:', err);
  }
}

module.exports = {
  pool,
  initDb,
  purgeUnconfirmedUsers,
};
