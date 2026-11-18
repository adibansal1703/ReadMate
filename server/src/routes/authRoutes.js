const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { pool } = require('../db');
const { authenticateToken, JWT_SECRET } = require('../middleware/authMiddleware');
const { signupValidation, loginValidation, passwordUpdateValidation } = require('../middleware/validators');
const { sendConfirmationLinkEmail, sendAccountDeletionEmail, sendPasswordResetEmail } = require('../utils/mailer');

const router = express.Router();

function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

function getBaseHostUrl(req) {
  const host = req.get('host') || 'localhost:3000';
  const protocol = req.protocol || 'http';
  return process.env.APP_URL || `${protocol}://${host}`;
}

router.post('/signup', signupValidation, async (req, res) => {
  const { email, password, username } = req.body;
  const cleanEmail = email.toLowerCase().trim();
  const cleanUsername = username.toLowerCase().trim();

  try {
    // Auto-purge any stale unconfirmed account (>24h old) matching email or username
    await pool.query(
      `DELETE FROM users
       WHERE is_verified = false
         AND created_at < NOW() - INTERVAL '24 hours'
         AND (LOWER(email) = LOWER($1) OR id IN (SELECT id FROM profiles WHERE LOWER(username) = LOWER($2)))`,
      [cleanEmail, cleanUsername]
    );

    const existing = await pool.query(
      'SELECT email, username FROM profiles WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($2)',
      [cleanEmail, cleanUsername]
    );

    if (existing.rows.length > 0) {
      for (const match of existing.rows) {
        if (match.email.toLowerCase() === cleanEmail) {
          return res.status(400).json({ error: 'An account with this email address already exists. Try logging in instead.' });
        }
        if (match.username.toLowerCase() === cleanUsername) {
          return res.status(400).json({ error: 'This username is already taken. Please choose another one.' });
        }
      }
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const verificationToken = generateToken();

    const userResult = await pool.query(
      `INSERT INTO users (email, password_hash, is_verified, verification_code, verification_expires)
       VALUES ($1, $2, false, $3, NOW() + INTERVAL '24 hours')
       RETURNING id, email, is_verified`,
      [cleanEmail, passwordHash, verificationToken]
    );
    const newUser = userResult.rows[0];

    await pool.query(
      'INSERT INTO profiles (id, username, email, display_name) VALUES ($1, $2, $3, $4)',
      [newUser.id, cleanUsername, cleanEmail, cleanUsername]
    );

    const baseUrl = getBaseHostUrl(req);
    const confirmUrl = `${baseUrl}/api/auth/confirm-email?token=${verificationToken}`;

    await sendConfirmationLinkEmail(cleanEmail, confirmUrl);

    return res.status(201).json({
      is_verified: false,
      email: cleanEmail,
      username: cleanUsername,
      message: 'Registration successful! A confirmation link has been sent to your email address.',
    });
  } catch (err) {
    if (err.code === '23505') {
      const detail = err.detail || '';
      if (detail.includes('email') || detail.includes('users_email')) {
        return res.status(400).json({ error: 'An account with this email address already exists. Try logging in instead.' });
      }
      if (detail.includes('username') || detail.includes('profiles_username')) {
        return res.status(400).json({ error: 'This username is already taken. Please choose another one.' });
      }
      return res.status(400).json({ error: 'An account with this email or username already exists.' });
    }
    console.error('[AUTH SIGNUP ERROR]', err);
    return res.status(500).json({ error: 'Server error during signup.' });
  }
});

router.get('/confirm-email', async (req, res) => {
  const { token } = req.query;

  if (!token) {
    return res.status(400).send(`
      <!DOCTYPE html>
      <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Invalid Token - ReadMate</title></head>
        <body style="font-family: system-ui, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0;">
          <div style="background: #1e293b; padding: 40px; border-radius: 16px; text-align: center; max-width: 400px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5);">
            <div style="font-size: 64px; margin-bottom: 16px;">❌</div>
            <h1 style="color: #f87171; margin-bottom: 8px;">Invalid Confirmation Link</h1>
            <p style="color: #94a3b8; font-size: 16px;">The confirmation token is missing or invalid.</p>
          </div>
        </body>
      </html>
    `);
  }

  try {
    const userRes = await pool.query(
      'SELECT id, email, is_verified, verification_expires FROM users WHERE verification_code = $1',
      [token.trim()]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).send(`
        <!DOCTYPE html>
        <html>
          <head><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Token Not Found - ReadMate</title></head>
          <body style="font-family: system-ui, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0;">
            <div style="background: #1e293b; padding: 40px; border-radius: 16px; text-align: center; max-width: 400px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5);">
              <div style="font-size: 64px; margin-bottom: 16px;">❓</div>
              <h1 style="color: #f87171; margin-bottom: 8px;">Account Not Found</h1>
              <p style="color: #94a3b8; font-size: 16px;">This confirmation link is invalid or has already been used.</p>
            </div>
          </body>
        </html>
      `);
    }

    const user = userRes.rows[0];

    await pool.query(
      'UPDATE users SET is_verified = true, verification_code = NULL, verification_expires = NULL WHERE id = $1',
      [user.id]
    );

    console.log(`[AUTH CONFIRMED] User ${user.email} verified email via link click!`);

    return res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Email Confirmed - ReadMate</title>
          <style>
            body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .card { background: #1e293b; padding: 40px; border-radius: 16px; text-align: center; max-width: 400px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5); border: 1px solid #334155; }
            .icon { font-size: 64px; margin-bottom: 16px; }
            h1 { color: #00BFA6; margin-bottom: 8px; font-size: 26px; }
            p { color: #94a3b8; font-size: 16px; line-height: 1.5; margin-top: 12px; }
            .badge { display: inline-block; background: #059669; color: #fff; padding: 6px 16px; border-radius: 20px; font-size: 14px; font-weight: bold; margin-top: 16px; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">✅</div>
            <h1>Email Confirmed!</h1>
            <div class="badge">Account Activated</div>
            <p>Your email address has been verified successfully.</p>
            <p>You can now close this window and return to the ReadMate app on your phone. You will be automatically logged in!</p>
          </div>
        </body>
      </html>
    `);
  } catch (err) {
    console.error('[CONFIRM EMAIL ERROR]', err);
    return res.status(500).send('Server error confirming email.');
  }
});

router.post('/resend-code', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email is required.' });

  const cleanEmail = email.toLowerCase().trim();

  try {
    const userRes = await pool.query('SELECT id, is_verified FROM users WHERE email = $1', [cleanEmail]);
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'Account not found.' });
    }

    if (userRes.rows[0].is_verified) {
      return res.json({ is_verified: true, message: 'Account is already verified.' });
    }

    const newToken = generateToken();
    await pool.query(
      `UPDATE users SET verification_code = $1, verification_expires = NOW() + INTERVAL '24 hours' WHERE id = $2`,
      [newToken, userRes.rows[0].id]
    );

    const baseUrl = getBaseHostUrl(req);
    const confirmUrl = `${baseUrl}/api/auth/confirm-email?token=${newToken}`;

    await sendConfirmationLinkEmail(cleanEmail, confirmUrl);

    return res.json({ message: 'A new confirmation link has been sent to your email.' });
  } catch (err) {
    console.error('[RESEND CONFIRMATION ERROR]', err);
    return res.status(500).json({ error: 'Server error resending confirmation email.' });
  }
});

router.post('/login', loginValidation, async (req, res) => {
  const { identifier, password } = req.body;
  const cleanIdentifier = identifier.toLowerCase().trim();

  try {
    let email = cleanIdentifier;

    if (!cleanIdentifier.includes('@')) {
      const profileRes = await pool.query('SELECT email FROM profiles WHERE username = $1', [cleanIdentifier]);
      if (profileRes.rows.length === 0) {
        return res.status(404).json({ error: `Username "@${cleanIdentifier}" not found. Please check spelling.` });
      }
      email = profileRes.rows[0].email;
    }

    const userRes = await pool.query('SELECT id, email, password_hash, is_verified FROM users WHERE email = $1', [email]);
    if (userRes.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid login credentials.' });
    }

    const user = userRes.rows[0];
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);

    if (!isPasswordValid) {
      return res.status(400).json({ error: 'Wrong password for account.' });
    }

    if (!user.is_verified) {
      return res.status(403).json({
        is_verified: false,
        email: user.email,
        error: 'Email not confirmed',
      });
    }

    const profileRes = await pool.query('SELECT username, display_name, yearly_goal FROM profiles WHERE id = $1', [user.id]);
    const profile = profileRes.rows[0] || {};

    const token = jwt.sign(
      { id: user.id, email: user.email, username: profile.username },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      is_verified: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        username: profile.username,
        display_name: profile.display_name,
        yearly_goal: profile.yearly_goal || 0,
      },
    });
  } catch (err) {
    console.error('[AUTH LOGIN ERROR]', err);
    return res.status(500).json({ error: 'Server error during login.' });
  }
});

router.get('/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT p.id, p.username, p.email, p.display_name, p.yearly_goal FROM profiles p WHERE p.id = $1',
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User profile not found.' });
    }

    return res.json({ user: result.rows[0] });
  } catch (err) {
    console.error('[AUTH ME ERROR]', err);
    return res.status(500).json({ error: 'Server error fetching user profile.' });
  }
});

router.get('/check-username', async (req, res) => {
  const { username } = req.query;
  if (!username) return res.status(400).json({ error: 'Username query parameter is required.' });

  try {
    const result = await pool.query('SELECT id FROM profiles WHERE username = $1', [username.toLowerCase().trim()]);
    return res.json({ available: result.rows.length === 0 });
  } catch (err) {
    return res.status(500).json({ error: 'Database check error.' });
  }
});

router.get('/check-email', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ error: 'Email query parameter is required.' });

  try {
    const result = await pool.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    return res.json({ registered: result.rows.length > 0 });
  } catch (err) {
    return res.status(500).json({ error: 'Database check error.' });
  }
});

router.post('/reset-password', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email is required.' });

  const cleanEmail = email.toLowerCase().trim();

  try {
    const userRes = await pool.query('SELECT id FROM users WHERE email = $1', [cleanEmail]);
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'This email is not registered.' });
    }

    const userId = userRes.rows[0].id;
    const resetToken = jwt.sign({ userId, type: 'reset' }, JWT_SECRET, { expiresIn: '1h' });

    const baseUrl = getBaseHostUrl(req);
    const resetUrl = `${baseUrl}/api/auth/reset-password-page?token=${resetToken}`;

    const sent = await sendPasswordResetEmail(cleanEmail, resetUrl);

    if (!sent) {
      return res.status(500).json({
        error: 'Mail delivery failed.',
      });
    }

    return res.json({ message: 'A password reset link has been sent to your email address.' });
  } catch (err) {
    console.error('[RESET PASSWORD ERROR]', err);
    return res.status(500).json({ error: 'Server error processing password reset.' });
  }
});

router.get('/reset-password-page', async (req, res) => {
  const { token } = req.query;

  if (!token) {
    return res.status(400).send(`
      <!DOCTYPE html>
      <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Invalid Token - ReadMate</title></head>
        <body style="font-family: system-ui, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0;">
          <div style="background: #1e293b; padding: 40px; border-radius: 16px; text-align: center; max-width: 400px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5);">
            <div style="font-size: 64px; margin-bottom: 16px;">❌</div>
            <h1 style="color: #f87171; margin-bottom: 8px;">Invalid Link</h1>
            <p style="color: #94a3b8; font-size: 16px;">The password reset token is missing or invalid.</p>
          </div>
        </body>
      </html>
    `);
  }

  try {
    const decoded = jwt.verify(token.trim(), JWT_SECRET);
    if (!decoded || decoded.type !== 'reset') {
      throw new Error('Invalid token');
    }
  } catch (err) {
    return res.status(400).send(`
      <!DOCTYPE html>
      <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Expired Link - ReadMate</title></head>
        <body style="font-family: system-ui, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0;">
          <div style="background: #1e293b; padding: 40px; border-radius: 16px; text-align: center; max-width: 400px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5);">
            <div style="font-size: 64px; margin-bottom: 16px;">⏰</div>
            <h1 style="color: #f87171; margin-bottom: 8px;">Link Expired</h1>
            <p style="color: #94a3b8; font-size: 16px;">This password reset link has expired or already been used. Please request a new link from the app.</p>
          </div>
        </body>
      </html>
    `);
  }

  return res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Reset Password - ReadMate</title>
          <style>
            * { box-sizing: border-box; }
            body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; }
            .card { background: #1e293b; padding: 40px; border-radius: 16px; width: 100%; max-width: 420px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5); border: 1px solid #334155; }
            h1 { color: #00BFA6; margin-bottom: 8px; font-size: 26px; text-align: center; }
            p { color: #94a3b8; font-size: 15px; margin-bottom: 24px; text-align: center; }
            label { display: block; font-size: 14px; color: #cbd5e1; margin-bottom: 6px; font-weight: 500; }
            input { width: 100%; padding: 12px 16px; border-radius: 8px; border: 1px solid #475569; background: #0f172a; color: #fff; font-size: 16px; margin-bottom: 16px; outline: none; }
            input:focus { border-color: #00BFA6; }
            button { width: 100%; padding: 14px; background: #00BFA6; color: #fff; font-size: 16px; font-weight: bold; border: none; border-radius: 8px; cursor: pointer; transition: background 0.2s; }
            button:hover { background: #00a38d; }
            .error { color: #f87171; font-size: 14px; margin-bottom: 16px; display: none; text-align: center; }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Set New Password</h1>
            <p>Enter your new password below for your ReadMate account.</p>
            <div id="errorMsg" class="error"></div>
            <form id="resetForm">
              <input type="hidden" name="token" value="${token.trim()}" />
              <label for="password">New Password</label>
              <input type="password" id="password" name="password" required minlength="6" placeholder="At least 6 characters" />
              <label for="confirmPassword">Confirm New Password</label>
              <input type="password" id="confirmPassword" name="confirmPassword" required placeholder="Re-enter new password" />
              <button type="submit" id="submitBtn">Update Password</button>
            </form>
          </div>
          <script>
            document.getElementById('resetForm').addEventListener('submit', async (e) => {
              e.preventDefault();
              const p1 = document.getElementById('password').value;
              const p2 = document.getElementById('confirmPassword').value;
              const errorDiv = document.getElementById('errorMsg');
              errorDiv.style.display = 'none';

              if (p1 !== p2) {
                errorDiv.innerText = 'Passwords do not match.';
                errorDiv.style.display = 'block';
                return;
              }

              if (p1.length < 6) {
                errorDiv.innerText = 'Password must be at least 6 characters.';
                errorDiv.style.display = 'block';
                return;
              }

              const btn = document.getElementById('submitBtn');
              btn.disabled = true;
              btn.innerText = 'Updating...';

              try {
                const res = await fetch('/api/auth/do-reset-password', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ token: '${token.trim()}', password: p1 })
                });
                const data = await res.json();
                if (res.ok) {
                  document.querySelector('.card').innerHTML =
                    '<div style="font-size: 64px; text-align: center; margin-bottom: 16px;">✅</div>' +
                    '<h1>Password Updated!</h1>' +
                    '<p style="color: #94a3b8;">Your password has been reset successfully. You can now return to the ReadMate app and log in with your new password.</p>';
                } else {
                  errorDiv.innerText = data.error || 'Failed to update password.';
                  errorDiv.style.display = 'block';
                  btn.disabled = false;
                  btn.innerText = 'Update Password';
                }
              } catch (err) {
                errorDiv.innerText = 'Network error. Please try again.';
                errorDiv.style.display = 'block';
                btn.disabled = false;
                btn.innerText = 'Update Password';
              }
            });
          </script>
        </body>
      </html>
    `);
});

router.post('/do-reset-password', async (req, res) => {
  const { token, password } = req.body;
  if (!token || !password) {
    return res.status(400).json({ error: 'Token and new password are required.' });
  }

  if (password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters long.' });
  }

  try {
    const decoded = jwt.verify(token.trim(), JWT_SECRET);
    if (!decoded || decoded.type !== 'reset') {
      return res.status(400).json({ error: 'Password reset link is invalid or has expired.' });
    }

    const userId = decoded.userId;
    const passwordHash = await bcrypt.hash(password, 10);

    await pool.query(
      'UPDATE users SET password_hash = $1 WHERE id = $2',
      [passwordHash, userId]
    );

    console.log(`[PASSWORD RESET SUCCESS] User ID ${userId} reset password via web form.`);
    return res.json({ message: 'Password updated successfully.' });
  } catch (err) {
    console.error('[DO RESET PASSWORD ERROR]', err);
    return res.status(400).json({ error: 'Password reset link is invalid or has expired.' });
  }
});

router.put('/password', authenticateToken, passwordUpdateValidation, async (req, res) => {
  const { password } = req.body;
  try {
    const passwordHash = await bcrypt.hash(password, 10);
    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, req.user.id]);
    return res.json({ message: 'Password updated successfully.' });
  } catch (err) {
    return res.status(500).json({ error: 'Server error updating password.' });
  }
});

router.put('/yearly-goal', authenticateToken, async (req, res) => {
  const { goal } = req.body;
  if (typeof goal !== 'number') return res.status(400).json({ error: 'Goal must be a number.' });

  try {
    await pool.query('UPDATE profiles SET yearly_goal = $1 WHERE id = $2', [goal, req.user.id]);
    return res.json({ message: 'Yearly goal updated.' });
  } catch (err) {
    return res.status(500).json({ error: 'Server error.' });
  }
});

router.delete('/account', authenticateToken, async (req, res) => {
  const { password } = req.body;
  if (!password) return res.status(400).json({ error: 'Password confirmation is required.' });

  try {
    const userRes = await pool.query('SELECT email, password_hash FROM users WHERE id = $1', [req.user.id]);
    if (userRes.rows.length === 0) return res.status(404).json({ error: 'User not found.' });

    const isValid = await bcrypt.compare(password, userRes.rows[0].password_hash);
    if (!isValid) return res.status(400).json({ error: 'Incorrect password. Verification failed.' });

    const userEmail = userRes.rows[0].email || req.user.email;
    const username = req.user.username;

    // Delete user from database (cascade deletes profiles and books)
    await pool.query('DELETE FROM users WHERE id = $1', [req.user.id]);

    // Clean up uploaded cover files for this user
    const uploadsDir = path.join(__dirname, '../../uploads');
    if (fs.existsSync(uploadsDir)) {
      try {
        const files = fs.readdirSync(uploadsDir);
        const userPrefix = `${req.user.id}_`;
        for (const file of files) {
          if (file.startsWith(userPrefix)) {
            fs.unlinkSync(path.join(uploadsDir, file));
          }
        }
      } catch (fsErr) {
        console.error('[CLEANUP UPLOADS ERROR]', fsErr);
      }
    }

    sendAccountDeletionEmail(userEmail, username).catch(err => {
      console.error('[ACCOUNT DELETION EMAIL ERROR]', err);
    });

    return res.json({ message: 'Account deleted successfully.' });
  } catch (err) {
    console.error('[DELETE ACCOUNT ERROR]', err);
    return res.status(500).json({ error: 'Server error deleting account.' });
  }
});

module.exports = router;
