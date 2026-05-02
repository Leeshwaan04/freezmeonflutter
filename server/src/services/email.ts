import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT ?? '587'),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

const FROM = process.env.EMAIL_FROM ?? 'noreply@freezme.in';
const BASE_URL = process.env.APP_BASE_URL ?? 'https://freezme.in';

export async function sendPasswordResetEmail(email: string, token: string): Promise<void> {
  const link = `${BASE_URL}/reset-password?token=${token}`;
  await transporter.sendMail({
    from: `Freezme <${FROM}>`,
    to: email,
    subject: 'Reset your Freezme password',
    html: `
      <p>Hi,</p>
      <p>We received a request to reset your Freezme password.</p>
      <p><a href="${link}" style="background:#6B2FD9;color:white;padding:12px 24px;border-radius:8px;text-decoration:none;display:inline-block;">Reset Password</a></p>
      <p>This link expires in 1 hour. If you didn't request this, ignore this email.</p>
      <p>The Freezme Team</p>
    `,
  });
}

export async function sendEmailVerificationEmail(email: string, token: string): Promise<void> {
  const link = `${BASE_URL}/verify-email?token=${token}`;
  await transporter.sendMail({
    from: `Freezme <${FROM}>`,
    to: email,
    subject: 'Verify your Freezme email',
    html: `
      <p>Hi,</p>
      <p>Thanks for signing up for Freezme! Please verify your email address.</p>
      <p><a href="${link}" style="background:#6B2FD9;color:white;padding:12px 24px;border-radius:8px;text-decoration:none;display:inline-block;">Verify Email</a></p>
      <p>This link expires in 24 hours.</p>
      <p>The Freezme Team</p>
    `,
  });
}
