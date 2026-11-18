const { body, validationResult } = require('express-validator');
const dns = require('dns').promises;

const COMMON_DOMAINS = new Set([
  'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'icloud.com',
  'protonmail.com', 'proton.me', 'live.com', 'msn.com', 'aol.com',
  'gmx.com', 'zoho.com', 'mail.com', 'yandex.com', 'comcast.net', 'sbcglobal.net'
]);

async function verifyMxRecord(domain) {
  const cleanDomain = domain.toLowerCase().trim();

  if (COMMON_DOMAINS.has(cleanDomain)) {
    return true;
  }

  try {
    const mxRecords = await Promise.race([
      dns.resolveMx(cleanDomain),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('DNS_TIMEOUT')), 5000)
      )
    ]);

    if (!mxRecords || mxRecords.length === 0) {
      throw new Error(`The email domain (@${cleanDomain}) is invalid or cannot receive emails. Please enter a valid email address.`);
    }

    const validMx = mxRecords.some(
      (r) => r.exchange && r.exchange !== '.' && r.exchange.trim() !== ''
    );
    if (!validMx) {
      throw new Error(`The email domain (@${cleanDomain}) is invalid or cannot receive emails. Please enter a valid email address.`);
    }

    return true;
  } catch (err) {
    if (err.message && err.message.includes('is invalid or cannot receive emails')) {
      throw err;
    }
    throw new Error(`The email domain (@${cleanDomain}) is invalid or cannot receive emails. Please enter a valid email address.`);
  }
}


const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const firstError = errors.array()[0].msg;
    return res.status(400).json({ error: firstError, errors: errors.array() });
  }
  next();
};

const RESERVED_USERNAMES = new Set([
  'admin', 'root', 'support', 'api', 'null', 'undefined', 'login', 'help',
  'system', 'superuser', 'owner', 'readmate', 'administrator', 'mod', 'moderator'
]);

const usernameValidator = body('username')
  .trim()
  .isLength({ min: 2, max: 15 })
  .withMessage('Username must be between 2 and 15 characters long.')
  .custom((value) => {
    if (/\s/.test(value)) {
      throw new Error('Username cannot contain spaces.');
    }
    if (value.length === 1 && !/^[a-zA-Z0-9]$/.test(value)) {
      throw new Error('Username must be an alphanumeric character.');
    }
    if (value.length > 1 && (!/^[a-zA-Z0-9]/.test(value) || !/[a-zA-Z0-9]$/.test(value))) {
      throw new Error('Username must start and end with a letter or number.');
    }
    if (!/^[a-zA-Z0-9_.-]+$/.test(value)) {
      throw new Error('Username contains invalid characters. Only letters, numbers, _, -, and . are allowed.');
    }
    if (/([._-]{2,})/.test(value)) {
      throw new Error('Username cannot contain consecutive special characters (e.g., __, .., --).');
    }
    if (RESERVED_USERNAMES.has(value.toLowerCase())) {
      throw new Error(`The username "${value}" is reserved and cannot be used.`);
    }
    return true;
  });

const emailValidator = body('email')
  .trim()
  .custom(async (value) => {
    if (!value) throw new Error('Email address is required.');

    if (value.length > 254) throw new Error('Email address exceeds maximum length of 254 characters.');

    if (/\s/.test(value)) throw new Error('Email address cannot contain spaces.');

    const atParts = value.split('@');
    if (atParts.length !== 2) throw new Error('Email address must contain exactly one "@" symbol.');

    const [localPart, domainPart] = atParts;

    if (!localPart || localPart.length === 0) throw new Error('Email local part (before @) cannot be empty.');
    if (!domainPart || domainPart.length === 0) throw new Error('Email domain part (after @) cannot be empty.');

    if (localPart.length > 64) throw new Error('Email local part cannot exceed 64 characters.');

    if (localPart.startsWith('.') || localPart.endsWith('.')) throw new Error('Email local part cannot start or end with a dot.');
    if (/\.{2,}/.test(localPart)) throw new Error('Email cannot contain consecutive dots (..).');

    if (!/^[a-zA-Z0-9._%+-]+$/.test(localPart)) throw new Error('Email local part contains invalid characters.');

    if (!domainPart.includes('.')) throw new Error('Email domain must contain a dot and a valid top-level domain (e.g., .com).');

    const domainLabels = domainPart.split('.');
    const tld = domainLabels[domainLabels.length - 1];

    if (tld.length < 2) throw new Error('Top-level domain (e.g., .com, .io) must be at least 2 characters long.');

    for (const label of domainLabels) {
      if (!label || label.length === 0) throw new Error('Domain part contains empty or invalid labels.');
      if (label.length > 63) throw new Error('Domain label cannot exceed 63 characters.');
      if (label.startsWith('-') || label.endsWith('-')) throw new Error('Domain labels cannot start or end with a hyphen.');
      if (!/^[a-zA-Z0-9-]+$/.test(label)) throw new Error('Domain labels can only contain letters, numbers, and hyphens.');
    }

    await verifyMxRecord(domainPart);

    return true;
  })
  .normalizeEmail();

const passwordValidator = body('password')
  .custom((value) => {
    if (!value) throw new Error('Password is required.');

    if (value.length < 6) throw new Error('Password must be at least 6 characters long.');

    if (/\s/.test(value)) throw new Error('Password cannot contain spaces.');

    const hasLetter = /[a-zA-Z]/.test(value);
    const hasDigit = /[0-9]/.test(value);

    if (!hasLetter || !hasDigit) {
      throw new Error('Password must contain both letters and numbers.');
    }

    return true;
  });

const signupValidation = [
  usernameValidator,
  emailValidator,
  passwordValidator,
  validate,
];

const loginValidation = [
  body('identifier')
    .trim()
    .notEmpty()
    .withMessage('Please enter your email or username.'),
  body('password')
    .notEmpty()
    .withMessage('Please enter your password.'),
  validate,
];

const passwordUpdateValidation = [
  passwordValidator,
  validate,
];

const bookValidation = [
  body('title')
    .trim()
    .notEmpty()
    .withMessage('Book title is required.'),
  validate,
];

module.exports = {
  signupValidation,
  loginValidation,
  passwordUpdateValidation,
  bookValidation,
  RESERVED_USERNAMES,
  verifyMxRecord,
};
