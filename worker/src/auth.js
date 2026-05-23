import { getLicense } from './kv.js';

export async function validateLicense(key, env) {
  if (!key) return null;
  const license = await getLicense(key, env);
  if (!license) return null;
  if (license.status !== 'active') return null;
  return license;
}

export function generateLicenseKey() {
  const uuid = crypto.randomUUID().replace(/-/g, '');
  return `pf_${uuid}`;
}
