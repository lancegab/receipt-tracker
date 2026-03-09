import nodemailer from 'nodemailer';

function createTransporter() {
  const host = process.env.SMTP_HOST;
  const port = parseInt(process.env.SMTP_PORT || '587');
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    return null;
  }

  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });
}

const FROM = process.env.SMTP_FROM || 'noreply@expensetracker.app';

export async function sendPasswordResetEmail(
  email: string,
  token: string
): Promise<void> {
  const resetUrl = `${process.env.APP_URL || 'http://localhost:3000'}/reset-password?token=${token}`;

  const html = `
    <h2>Password Reset</h2>
    <p>You requested a password reset for your Expense Tracker account.</p>
    <p>Click the link below to reset your password. This link expires in 1 hour.</p>
    <p><a href="${resetUrl}" style="display:inline-block;padding:12px 24px;background:#6750A4;color:white;text-decoration:none;border-radius:8px;">Reset Password</a></p>
    <p>If you didn't request this, you can safely ignore this email.</p>
  `;

  const transporter = createTransporter();
  if (!transporter) {
    console.log('[EMAIL] SMTP not configured. Reset token for', email, ':', token);
    console.log('[EMAIL] Reset URL:', resetUrl);
    return;
  }

  await transporter.sendMail({
    from: FROM,
    to: email,
    subject: 'Password Reset - Expense Tracker',
    html,
  });
}
