const nodemailer = require('nodemailer');
require('dotenv').config();

function getTransporter() {
  const user = process.env.EMAIL_USER || process.env.SMTP_USER;
  const pass = process.env.EMAIL_PASS || process.env.SMTP_PASS;

  if (!user || !pass) {
    return null;
  }

  const host = process.env.SMTP_HOST || 'smtp-relay.brevo.com';
  const port = parseInt(process.env.SMTP_PORT || '587', 10);

  const transportConfig = {
    host: host,
    port: port,
    secure: port === 465,
    auth: {
      user: user,
      pass: pass,
    },
  };

  if (process.env.EMAIL_SERVICE) {
    transportConfig.service = process.env.EMAIL_SERVICE;
  }

  return nodemailer.createTransport(transportConfig);
}

function getSenderEmail() {
  let sender = process.env.EMAIL_FROM;

  if (!sender || sender.includes('@smtp-brevo.com')) {
    sender = process.env.EMAIL_USER;
  }

  if (!sender || sender.includes('@smtp-brevo.com')) {
    sender = 'adibansal1703@gmail.com';
  }

  return sender;
}

async function verifySmtpConnection() {
  const transporter = getTransporter();
  if (!transporter) {
    console.log('[MAILER] SMTP credentials not configured in .env. Links will be printed in terminal console.');
    return;
  }

  try {
    await transporter.verify();
    console.log('[MAILER] Connected to Brevo/SMTP server successfully! Real email delivery enabled.');
  } catch (err) {
    console.warn('[MAILER WARN] Brevo/SMTP authentication failed:', err.message);
  }
}

async function sendConfirmationLinkEmail(recipientEmail, confirmUrl) {
  console.log(`\n=================================================`);
  console.log(`🔗 EMAIL CONFIRMATION LINK`);
  console.log(`User Email: ${recipientEmail}`);
  console.log(`Click Link: ${confirmUrl}`);
  console.log(`=================================================\n`);

  const transporter = getTransporter();

  if (!transporter) {
    console.log(`[MAILER] SMTP credentials not set in .env. Confirmation link printed above.`);
    return false;
  }

  const senderEmail = getSenderEmail();
  const senderName = process.env.EMAIL_FROM_NAME || 'ReadMate App';

  try {
    const mailOptions = {
      from: `"${senderName}" <${senderEmail}>`,
      to: recipientEmail,
      subject: '✉️ Confirm your ReadMate Account',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;">
          <div style="text-align: center; margin-bottom: 24px;">
            <h1 style="color: #00BFA6; margin: 0; font-size: 28px;">ReadMate</h1>
            <p style="color: #666; margin-top: 4px; font-size: 14px;">Your Personal Mobile Books Tracker</p>
          </div>
          <h2 style="color: #333; font-size: 20px;">Confirm your email address</h2>
          <p style="font-size: 15px; color: #444; line-height: 1.5;">
            Thank you for creating an account on ReadMate! Please click the button below to confirm your email address and activate your account.
          </p>
          <div style="text-align: center; margin: 32px 0;">
            <a href="${confirmUrl}" target="_blank" style="background-color: #00BFA6; color: #ffffff; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; display: inline-block;">
              Confirm My Account
            </a>
          </div>
          <p style="font-size: 13px; color: #888; line-height: 1.4;">
            If the button above does not work, copy and paste this link into your browser:<br/>
            <a href="${confirmUrl}" style="color: #00BFA6;">${confirmUrl}</a>
          </p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
          <p style="font-size: 12px; color: #aaa; text-align: center; margin: 0;">
            If you did not request this email, you can safely ignore it.
          </p>
        </div>
      `,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`[MAILER SUCCESS] Sent to ${recipientEmail}. ID: ${info.messageId} Response: ${info.response}`);
    return true;
  } catch (err) {
    console.error(`[MAILER ERROR] Failed to send email to ${recipientEmail}:`, err.message);
    return false;
  }
}

async function sendAccountDeletionEmail(recipientEmail, username) {
  console.log(`\n=================================================`);
  console.log(`🗑️ ACCOUNT DELETION NOTICE`);
  console.log(`User Email: ${recipientEmail}`);
  console.log(`Username: ${username || 'N/A'}`);
  console.log(`=================================================\n`);

  const transporter = getTransporter();

  if (!transporter) {
    console.log(`[MAILER] SMTP credentials not set in .env. Deletion notification printed above.`);
    return false;
  }

  const senderEmail = getSenderEmail();
  const senderName = process.env.EMAIL_FROM_NAME || 'ReadMate App';

  try {
    const mailOptions = {
      from: `"${senderName}" <${senderEmail}>`,
      to: recipientEmail,
      subject: '🗑️ Your ReadMate Account Has Been Deleted',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;">
          <div style="text-align: center; margin-bottom: 24px;">
            <h1 style="color: #00BFA6; margin: 0; font-size: 28px;">ReadMate</h1>
            <p style="color: #666; margin-top: 4px; font-size: 14px;">Your Personal Mobile Books Tracker</p>
          </div>
          <h2 style="color: #333; font-size: 20px;">Account Successfully Deleted</h2>
          <p style="font-size: 15px; color: #444; line-height: 1.5;">
            Hi ${username ? `<strong>@${username}</strong>` : 'there'},
          </p>
          <p style="font-size: 15px; color: #444; line-height: 1.5;">
            This email confirms that your ReadMate account associated with <strong>${recipientEmail}</strong> and all your personal reading data have been permanently deleted from our system.
          </p>
          <p style="font-size: 15px; color: #444; line-height: 1.5;">
            We're sorry to see you go! If you ever decide to return, you can create a new account at any time.
          </p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
          <p style="font-size: 12px; color: #aaa; text-align: center; margin: 0;">
            If you did not request this account deletion, please contact support immediately.
          </p>
        </div>
      `,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`[MAILER SUCCESS] Account deletion email sent to ${recipientEmail}. ID: ${info.messageId}`);
    return true;
  } catch (err) {
    console.error(`[MAILER ERROR] Failed to send deletion email to ${recipientEmail}:`, err.message);
    return false;
  }
}

async function sendPasswordResetEmail(recipientEmail, resetUrl) {
  console.log(`\n=================================================`);
  console.log(`🔐 PASSWORD RESET LINK`);
  console.log(`User Email: ${recipientEmail}`);
  console.log(`Click Link: ${resetUrl}`);
  console.log(`=================================================\n`);

  const transporter = getTransporter();

  if (!transporter) {
    console.log(`[MAILER] SMTP credentials not set in .env. Password reset link printed above.`);
    return false;
  }

  const senderEmail = getSenderEmail();
  const senderName = process.env.EMAIL_FROM_NAME || 'ReadMate App';

  try {
    const mailOptions = {
      from: `"${senderName}" <${senderEmail}>`,
      to: recipientEmail,
      subject: '🔑 Reset Your ReadMate Password',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;">
          <div style="text-align: center; margin-bottom: 24px;">
            <h1 style="color: #00BFA6; margin: 0; font-size: 28px;">ReadMate</h1>
            <p style="color: #666; margin-top: 4px; font-size: 14px;">Your Personal Mobile Books Tracker</p>
          </div>
          <h2 style="color: #333; font-size: 20px;">Password Reset Request</h2>
          <p style="font-size: 15px; color: #444; line-height: 1.5;">
            We received a request to reset the password for your ReadMate account (<strong>${recipientEmail}</strong>). Please click the button below to set a new password.
          </p>
          <div style="text-align: center; margin: 32px 0;">
            <a href="${resetUrl}" target="_blank" style="background-color: #00BFA6; color: #ffffff; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; display: inline-block;">
              Reset My Password
            </a>
          </div>
          <p style="font-size: 13px; color: #888; line-height: 1.4;">
            If the button above does not work, copy and paste this link into your web browser:<br/>
            <a href="${resetUrl}" style="color: #00BFA6;">${resetUrl}</a>
          </p>
          <p style="font-size: 13px; color: #888; line-height: 1.4;">
            This link will expire in 1 hour.
          </p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
          <p style="font-size: 12px; color: #aaa; text-align: center; margin: 0;">
            If you did not request a password reset, you can safely ignore this email.
          </p>
        </div>
      `,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`[MAILER SUCCESS] Password reset email sent to ${recipientEmail}. ID: ${info.messageId}`);
    return true;
  } catch (err) {
    console.error(`[MAILER ERROR] Failed to send password reset email to ${recipientEmail}:`, err.message);
    return false;
  }
}

module.exports = {
  sendConfirmationLinkEmail,
  sendAccountDeletionEmail,
  sendPasswordResetEmail,
  verifySmtpConnection,
};
