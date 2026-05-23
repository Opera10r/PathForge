import { validateLicense } from './auth.js';
import { handleStripeWebhook } from './stripe.js';

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
      });
    }

    // Routes
    switch (url.pathname) {
      case '/validate-license': {
        if (request.method !== 'POST') {
          return jsonResponse({ error: 'Method not allowed' }, 405);
        }

        const { license_key } = await request.json();
        const license = await validateLicense(license_key, env);

        if (!license) {
          return jsonResponse({ valid: false }, 200);
        }

        return jsonResponse({
          valid: true,
          email: license.email,
          status: license.status,
          product: license.product,
        }, 200);
      }

      case '/webhook': {
        if (request.method !== 'POST') {
          return jsonResponse({ error: 'Method not allowed' }, 405);
        }
        return handleStripeWebhook(request, env);
      }

      case '/health': {
        return jsonResponse({ status: 'ok', product: 'pathforge' });
      }

      default:
        return jsonResponse({ error: 'Not found' }, 404);
    }
  },
};
