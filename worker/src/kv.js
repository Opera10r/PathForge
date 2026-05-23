const PREFIX = 'license:';

export async function getLicense(key, env) {
  const raw = await env.LICENSES.get(`${PREFIX}${key}`);
  if (!raw) return null;
  return JSON.parse(raw);
}

export async function putLicense(key, data, env) {
  await env.LICENSES.put(`${PREFIX}${key}`, JSON.stringify(data));
}

export async function deleteLicense(key, env) {
  await env.LICENSES.delete(`${PREFIX}${key}`);
}
