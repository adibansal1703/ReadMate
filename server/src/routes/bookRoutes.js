const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/authMiddleware');
const { bookValidation } = require('../middleware/validators');

const router = express.Router();

const uploadsDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `${req.user.id}_${Date.now()}${ext}`);
  },
});
const upload = multer({ storage });

router.post('/upload-cover', authenticateToken, upload.single('cover'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image file uploaded.' });
  }

  const protocol = req.protocol;
  const host = req.get('host');
  const imageUrl = `${protocol}://${host}/uploads/${req.file.filename}`;

  return res.json({ url: imageUrl });
});

router.get('/', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM books WHERE user_id = $1 ORDER BY updated_at DESC',
      [req.user.id]
    );

    return res.json({ books: result.rows });
  } catch (err) {
    console.error('[GET BOOKS ERROR]', err);
    return res.status(500).json({ error: 'Server error fetching books.' });
  }
});

function getStatusString(status) {
  if (status !== undefined && status !== null) {
    return String(status);
  }
  return '2';
}

router.post('/upsert', authenticateToken, bookValidation, async (req, res) => {
  const {
    id,
    title,
    subtitle,
    author,
    description,
    status,
    favourite,
    deleted,
    rating,
    pages,
    publication_year,
    isbn,
    olid,
    tags,
    notes,
    current_page,
    cover_url,
    blur_hash,
    book_type,
    readings,
    date_added,
    date_modified,
  } = req.body;

  const cleanStatus = getStatusString(status);

  try {
    let result;
    let oldBook = null;

    if (id && typeof id === 'number' && id > 0) {
      const oldRes = await pool.query('SELECT current_page, status, notes FROM books WHERE id = $1 AND user_id = $2', [id, req.user.id]);
      if (oldRes.rows.length > 0) {
        oldBook = oldRes.rows[0];
      }

      result = await pool.query(
        `UPDATE books SET
          title = $1, subtitle = $2, author = $3, description = $4, status = $5,
          favourite = $6, deleted = $7, rating = $8, pages = $9, publication_year = $10,
          isbn = $11, olid = $12, tags = $13, notes = $14, current_page = $15,
          cover_url = $16, blur_hash = $17, book_type = $18, readings = $19,
          date_added = $20, date_modified = $21, updated_at = CURRENT_TIMESTAMP
        WHERE id = $22 AND user_id = $23 RETURNING *`,
        [
          title, subtitle, author, description, cleanStatus,
          favourite || false, deleted || false, rating || 0, pages || 0, publication_year,
          isbn, olid, tags, notes, current_page || 0,
          cover_url, blur_hash, book_type || 'paperback', readings,
          date_added, date_modified, id, req.user.id
        ]
      );
    }

    let isNewBook = false;
    if (!result || result.rows.length === 0) {
      isNewBook = true;
      result = await pool.query(
        `INSERT INTO books (
          user_id, title, subtitle, author, description, status,
          favourite, deleted, rating, pages, publication_year,
          isbn, olid, tags, notes, current_page, cover_url,
          blur_hash, book_type, readings, date_added, date_modified
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22) RETURNING *`,
        [
          req.user.id, title, subtitle, author, description, cleanStatus,
          favourite || false, deleted || false, rating || 0, pages || 0, publication_year,
          isbn, olid, tags, notes, current_page || 0, cover_url,
          blur_hash, book_type || 'paperback', readings, date_added, date_modified
        ]
      );
    }

    const savedBook = result.rows[0];

    // Log history events
    if (isNewBook) {
      const initialPage = (savedBook.current_page && savedBook.current_page > 0) ? savedBook.current_page : null;
      await pool.query(
        `INSERT INTO book_history (book_id, user_id, event_type, description, page_number)
         VALUES ($1, $2, 'added', 'Book added to library', $3)`,
        [savedBook.id, req.user.id, initialPage]
      );
      if (savedBook.notes && savedBook.notes.trim().length > 0) {
        await pool.query(
          `INSERT INTO book_history (book_id, user_id, event_type, description, note_content)
           VALUES ($1, $2, 'notes_updated', 'Added note', $3)`,
          [savedBook.id, req.user.id, savedBook.notes]
        );
      }
    } else if (oldBook) {
      if (oldBook.current_page !== savedBook.current_page && savedBook.current_page > 0) {
        await pool.query(
          `INSERT INTO book_history (book_id, user_id, event_type, description, page_number)
           VALUES ($1, $2, 'page_updated', $3, $4)`,
          [savedBook.id, req.user.id, `Updated progress to page ${savedBook.current_page}`, savedBook.current_page]
        );
      }
      if (oldBook.status !== savedBook.status) {
        const isFinished = savedBook.status === '1' || savedBook.status === 'read';
        const isUnfinished = savedBook.status === '3' || savedBook.status === 'unfinished';
        let desc = 'Updated book status';
        if (isFinished) {
          desc = 'Marked book as Finished';
        } else if (isUnfinished) {
          desc = savedBook.current_page > 0 ? `Left unfinished at page ${savedBook.current_page}` : 'Marked as Unfinished';
        }

        await pool.query(
          `INSERT INTO book_history (book_id, user_id, event_type, description, page_number)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            savedBook.id,
            req.user.id,
            isFinished ? 'finished' : 'status_changed',
            desc,
            (savedBook.current_page && savedBook.current_page > 0) ? savedBook.current_page : null
          ]
        );
      }
      if (savedBook.notes && savedBook.notes !== oldBook.notes && savedBook.notes.trim().length > 0) {
        await pool.query(
          `INSERT INTO book_history (book_id, user_id, event_type, description, note_content)
           VALUES ($1, $2, 'notes_updated', 'Updated note', $3)`,
          [savedBook.id, req.user.id, savedBook.notes]
        );
      }
    }

    return res.status(200).json({ book: savedBook });
  } catch (err) {
    console.error('[UPSERT BOOK ERROR]', err);
    return res.status(500).json({ error: 'Server error saving book.' });
  }
});

router.post('/sync', authenticateToken, async (req, res) => {
  const { books } = req.body;
  if (!Array.isArray(books)) {
    return res.status(400).json({ error: 'Books array is required.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const book of books) {
      const {
        id, title, subtitle, author, description, status,
        favourite, deleted, rating, pages, publication_year,
        isbn, olid, tags, notes, current_page, cover_url,
        blur_hash, book_type, readings, date_added, date_modified
      } = book;

      if (!title) continue;
      const cleanStatus = getStatusString(status);

      if (id && typeof id === 'number' && id > 0) {
        await client.query(
          `UPDATE books SET
            title = $1, subtitle = $2, author = $3, description = $4, status = $5,
            favourite = $6, deleted = $7, rating = $8, pages = $9, publication_year = $10,
            isbn = $11, olid = $12, tags = $13, notes = $14, current_page = $15,
            cover_url = $16, blur_hash = $17, book_type = $18, readings = $19,
            date_added = $20, date_modified = $21, updated_at = CURRENT_TIMESTAMP
          WHERE id = $22 AND user_id = $23`,
          [
            title, subtitle, author, description, cleanStatus,
            favourite || false, deleted || false, rating || 0, pages || 0, publication_year,
            isbn, olid, tags, notes, current_page || 0,
            cover_url, blur_hash, book_type || 'paperback', readings,
            date_added, date_modified, id, req.user.id
          ]
        );
      } else {
        await client.query(
          `INSERT INTO books (
            user_id, title, subtitle, author, description, status,
            favourite, deleted, rating, pages, publication_year,
            isbn, olid, tags, notes, current_page, cover_url,
            blur_hash, book_type, readings, date_added, date_modified
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22)`,
          [
            req.user.id, title, subtitle, author, description, cleanStatus,
            favourite || false, deleted || false, rating || 0, pages || 0, publication_year,
            isbn, olid, tags, notes, current_page || 0, cover_url,
            blur_hash, book_type || 'paperback', readings, date_added, date_modified
          ]
        );
      }
    }

    await client.query('COMMIT');
    return res.json({ message: 'Batch sync successful.' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[SYNC BOOKS ERROR]', err);
    return res.status(500).json({ error: 'Server error during batch sync.' });
  } finally {
    client.release();
  }
});

function deleteCoverFile(coverUrl) {
  if (!coverUrl || typeof coverUrl !== 'string') return;
  try {
    const filename = coverUrl.split('/uploads/')[1];
    if (filename) {
      const filePath = path.join(uploadsDir, filename);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }
  } catch (e) {
    console.error('[DELETE COVER FILE ERROR]', e);
  }
}

router.post('/bulk-delete', authenticateToken, async (req, res) => {
  const ids = req.body.ids || req.body.bookIds;
  if (!Array.isArray(ids) || ids.length === 0) {
    return res.status(400).json({ error: 'Array of book IDs is required.' });
  }

  const validIds = ids.map(id => parseInt(id, 10)).filter(id => !isNaN(id) && id > 0);
  if (validIds.length === 0) {
    return res.status(400).json({ error: 'No valid numeric book IDs provided.' });
  }

  try {
    const coversRes = await pool.query(
      'SELECT cover_url FROM books WHERE id = ANY($1::int[]) AND user_id = $2',
      [validIds, req.user.id]
    );

    const result = await pool.query(
      'DELETE FROM books WHERE id = ANY($1::int[]) AND user_id = $2 RETURNING id',
      [validIds, req.user.id]
    );

    for (const row of coversRes.rows) {
      deleteCoverFile(row.cover_url);
    }

    return res.json({
      message: `${result.rowCount} book(s) permanently deleted successfully.`,
      deletedCount: result.rowCount,
    });
  } catch (err) {
    console.error('[BULK DELETE BOOKS ERROR]', err);
    return res.status(500).json({ error: 'Server error bulk deleting books.' });
  }
});

router.delete('/:id', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.params.id, 10);
  if (isNaN(bookId)) return res.status(400).json({ error: 'Invalid book ID.' });

  try {
    const bookRes = await pool.query('SELECT cover_url FROM books WHERE id = $1 AND user_id = $2', [bookId, req.user.id]);
    const coverUrl = bookRes.rows[0]?.cover_url;

    await pool.query('DELETE FROM books WHERE id = $1 AND user_id = $2', [bookId, req.user.id]);

    deleteCoverFile(coverUrl);

    return res.json({ message: 'Book deleted successfully.' });
  } catch (err) {
    console.error('[DELETE BOOK ERROR]', err);
    return res.status(500).json({ error: 'Server error deleting book.' });
  }
});

router.get('/profiles/search', authenticateToken, async (req, res) => {
  const { q } = req.query;
  if (!q) return res.json({ profiles: [] });

  try {
    const result = await pool.query(
      'SELECT id, username, display_name FROM profiles WHERE username ILIKE $1 AND id != $2 LIMIT 20',
      [`%${q}%`, req.user.id]
    );
    return res.json({ profiles: result.rows });
  } catch (err) {
    return res.status(500).json({ error: 'Profile search error.' });
  }
});

router.get('/profiles/:userId', async (req, res) => {
  try {
    const profileRes = await pool.query('SELECT id, username, display_name, yearly_goal FROM profiles WHERE id = $1', [req.params.userId]);
    if (profileRes.rows.length === 0) return res.status(404).json({ error: 'Profile not found.' });

    const booksRes = await pool.query('SELECT * FROM books WHERE user_id = $1', [req.params.userId]);

    return res.json({
      profile: profileRes.rows[0],
      books: booksRes.rows,
    });
  } catch (err) {
    return res.status(500).json({ error: 'Server error.' });
  }
});

router.get('/:id/history', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.params.id, 10);
  if (isNaN(bookId)) return res.status(400).json({ error: 'Invalid book ID.' });

  try {
    const result = await pool.query(
      'SELECT * FROM book_history WHERE book_id = $1 AND user_id = $2 ORDER BY created_at ASC',
      [bookId, req.user.id]
    );

    return res.json({ history: result.rows });
  } catch (err) {
    console.error('[GET BOOK HISTORY ERROR]', err);
    return res.status(500).json({ error: 'Server error fetching book history.' });
  }
});

router.post('/:id/notes', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.params.id, 10);
  const { note } = req.body;

  if (isNaN(bookId)) return res.status(400).json({ error: 'Invalid book ID.' });
  if (!note || typeof note !== 'string' || note.trim().length === 0) {
    return res.status(400).json({ error: 'Note content is required.' });
  }

  const cleanNote = note.trim();
  if (cleanNote.length > 5000) {
    return res.status(400).json({ error: 'Note exceeds maximum limit of 5000 characters.' });
  }

  try {
    const bookRes = await pool.query('SELECT id FROM books WHERE id = $1 AND user_id = $2', [bookId, req.user.id]);
    if (bookRes.rows.length === 0) {
      return res.status(404).json({ error: 'Book not found.' });
    }

    const historyRes = await pool.query(
      `INSERT INTO book_history (book_id, user_id, event_type, description, note_content)
       VALUES ($1, $2, 'note_added', 'Added note', $3) RETURNING *`,
      [bookId, req.user.id, cleanNote]
    );

    await pool.query('UPDATE books SET notes = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [cleanNote, bookId]);

    return res.status(201).json({ note: historyRes.rows[0] });
  } catch (err) {
    console.error('[ADD BOOK NOTE ERROR]', err);
    return res.status(500).json({ error: 'Server error adding note.' });
  }
});

module.exports = router;
