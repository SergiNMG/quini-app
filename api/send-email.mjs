import { Resend } from 'resend';

const MAX_RECIPIENTS = 10;

export default async function handler(request, response) {
  if (request.method !== 'POST') {
    response.setHeader('Allow', 'POST');
    return response.status(405).json({ error: 'Method not allowed' });
  }

  const { to, subject, html, text } = request.body ?? {};
  const recipients = Array.isArray(to) ? to : [to];

  if (
    !process.env.RESEND_API_KEY ||
    !process.env.RESEND_FROM_EMAIL ||
    !recipients.length ||
    recipients.length > MAX_RECIPIENTS ||
    recipients.some((email) => typeof email !== 'string') ||
    typeof subject !== 'string' ||
    (!html && !text)
  ) {
    return response.status(400).json({ error: 'Invalid email payload or server configuration' });
  }

  try {
    const resend = new Resend(process.env.RESEND_API_KEY);
    const { data, error } = await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL,
      to: recipients,
      subject,
      html,
      text,
    });

    if (error) return response.status(422).json({ error: error.message });
    return response.status(200).json({ data });
  } catch {
    return response.status(500).json({ error: 'Unable to send email' });
  }
}
