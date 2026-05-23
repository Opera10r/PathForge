import { generateLicenseKey } from './auth.js';
import { getLicense, putLicense } from './kv.js';
import { sendLicenseEmail } from './email.js';

async function verifyStripeSignature(rawBody, signature, secret) {
  const parts = {};
  for (const item of signature.split(',')) {
    const [key, value] = item.split('=');
    parts[key] = value;
  }

  const timestamp = parts['t'];
  const sig = parts['v1'];
  if (!timestamp || !sig) return false;

  const payload = `${timestamp}.${rawBody}`;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const mac = await crypto.subtle.sign('HMAC', key, encoder.encode(payload));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  return expected === sig;
}

export async function handleStripeWebhook(request, env) {
  const rawBody = await request.text();
  const signature = request.headers.get('Stripe-Signature');

  if (!signature) {
    return new Response('Missing signature', { status: 400 });
  }

  const valid = await verifyStripeSignature(rawBody, signature, env.STRIPE_WEBHOOK_SECRET);
  if (!valid) {
    return new Response('Invalid signature', { status: 401 });
  }

  const event = JSON.parse(rawBody);

  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object;
      const email = session.customer_details?.email;
      const customerId = session.customer;
      const subscriptionId = session.subscription;

      const licenseKey = generateLicenseKey();

      await putLicense(licenseKey, {
        email,
        status: 'active',
        product: 'pathforge',
        customer_id: customerId,
        subscription_id: subscriptionId,
        created_at: new Date().toISOString(),
        copies_count: 0,
      }, env);

      if (subscriptionId) {
        await env.LICENSES.put(`sub:${subscriptionId}`, licenseKey);
      }

      if (email) {
        await sendLicenseEmail(email, licenseKey, env);
      }

      return new Response(JSON.stringify({ license_key: licenseKey }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    case 'customer.subscription.deleted': {
      const sub = event.data.object;
      const subId = sub.id;

      const licenseKeyForSub = await env.LICENSES.get(`sub:${subId}`);
      if (licenseKeyForSub) {
        const license = await getLicense(licenseKeyForSub, env);
        if (license) {
          license.status = 'cancelled';
          license.cancelled_at = new Date().toISOString();
          await putLicense(licenseKeyForSub, license, env);
        }
      }

      return new Response('OK', { status: 200 });
    }

    default:
      return new Response('Unhandled event', { status: 200 });
  }
}
