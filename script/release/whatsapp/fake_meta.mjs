// Isolated R03 acceptance provider. It binds only to loopback and can deliver
// callbacks only to the explicitly selected local Rails port.
import http from 'node:http';
import { createHmac } from 'node:crypto';

if (process.env.RAILS_ENV !== 'test')
  throw new Error('Test environment required');
const port = Number(process.env.FAKE_META_PORT || 3214);
const railsPort = Number(process.env.FAKE_META_RAILS_PORT || 3213);
let callback;
let unhealthy = false;
let accepted;
let deliveries = 0;

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://127.0.0.1:${port}`);
  let raw = '';
  for await (const part of request) raw += part;
  const body = raw ? JSON.parse(raw) : {};
  const send = (code, value) => {
    response.writeHead(code, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify(value));
  };
  try {
    if (url.pathname === '/_test/state')
      return send(200, {
        registered: !!callback,
        unhealthy,
        deliveries,
        accepted,
      });
    if (url.pathname === '/_test/health') {
      unhealthy = body.fail === true;
      return send(200, { unhealthy });
    }
    if (url.pathname === '/_test/deliver') {
      if (!callback) return send(409, { error: 'callback_not_registered' });
      const payload = JSON.stringify({
        object: 'whatsapp_business_account',
        entry: [
          {
            id: '9003',
            changes: [
              {
                field: 'messages',
                value: {
                  metadata: {
                    phone_number_id: '3003',
                    display_phone_number: '255700000003',
                  },
                  contacts: [
                    {
                      wa_id: '255711111111',
                      profile: { name: 'Amina — local test' },
                    },
                  ],
                  messages: [
                    {
                      id: 'wamid.R03.BROWSER.ONE',
                      from: '255711111111',
                      timestamp: String(Math.floor(Date.now() / 1000)),
                      type: 'text',
                      text: {
                        body: 'Habari, ningependa kujua kuhusu huduma zenu.',
                      },
                    },
                  ],
                },
              },
            ],
          },
        ],
      });
      const signature =
        'sha256=' +
        createHmac('sha256', 'r03-signing-secret')
          .update(payload)
          .digest('hex');
      const result = await fetch(callback, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Hub-Signature-256': signature,
        },
        body: payload,
      });
      accepted = { status: result.status, ...(await result.json()) };
      deliveries += 1;
      return send(200, accepted);
    }
    if (request.method === 'GET' && url.pathname.endsWith('/message_templates'))
      return send(200, { data: [] });
    if (request.method === 'GET' && url.pathname.endsWith('/phone_numbers'))
      return send(200, {
        data: [{ id: '3003', display_phone_number: '255700000003' }],
      });
    if (request.method === 'GET' && url.pathname.endsWith('/9003'))
      return send(200, { id: '9003', name: 'R03 Synthetic Business' });
    if (request.method === 'GET' && url.pathname.endsWith('/3003')) {
      if (unhealthy)
        return send(401, {
          error: {
            code: 190,
            message: 'Synthetic failure r03-access-secret r03-signing-secret',
          },
        });
      return send(200, {
        id: '3003',
        display_phone_number: '255700000003',
        verified_name: 'R03 Synthetic Business',
        quality_rating: 'GREEN',
        status: 'CONNECTED',
        code_verification_status: 'VERIFIED',
        platform_type: 'CLOUD_API',
        throughput: { level: 'STANDARD' },
      });
    }
    if (request.method === 'POST' && body.webhook_configuration) {
      const target = new URL(body.webhook_configuration.override_callback_uri);
      if (target.hostname !== '127.0.0.1' || target.port !== String(railsPort))
        return send(400, { error: 'local_callback_required' });
      const verify = new URL(target);
      verify.searchParams.set('hub.mode', 'subscribe');
      verify.searchParams.set('hub.challenge', 'r03-local-verification');
      verify.searchParams.set(
        'hub.verify_token',
        body.webhook_configuration.verify_token
      );
      const checked = await fetch(verify);
      if (
        !checked.ok ||
        !(await checked.text()).includes('r03-local-verification')
      )
        return send(400, { error: 'verification_failed' });
      callback = target.href;
      return send(200, { success: true });
    }
    if (
      request.method === 'POST' &&
      /\/(subscribed_apps|register)$/.test(url.pathname)
    )
      return send(200, { success: true });
    return send(404, { error: 'unsupported_fake_provider_request' });
  } catch {
    return send(500, { error: 'fake_provider_error' });
  }
});
server.listen(port, '127.0.0.1', () =>
  process.stdout.write(`Synthetic Meta provider on ${port}\n`)
);
