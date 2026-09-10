// Local synthetic R04 provider; it cannot contact Meta or send callbacks.
import http from 'node:http';

if (process.env.RAILS_ENV !== 'test') throw new Error('Test environment required');
const port = Number(process.env.FAKE_META_PORT || 3225);
const requests = [];
http
  .createServer(async (request, response) => {
    const send = (status, data) => {
      response.writeHead(status, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify(data));
    };
    if (request.url === '/_test/state') return send(200, { requests });
    if (request.method !== 'POST' || !request.url.endsWith('/messages'))
      return send(404, { error: 'local_fixture_route_missing' });
    let raw = '';
    for await (const part of request) raw += part;
    const body = JSON.parse(raw);
    const content = body.text?.body || '';
    const id = `wamid.R04.BROWSER.${requests.length + 1}`;
    requests.push({ id, recipient: body.to || body.recipient, content });
    if (content.startsWith('Failed:'))
      return send(400, { error: { code: 100, message: 'Synthetic rejection' } });
    if (content.startsWith('Unknown:'))
      return send(503, { error: { code: 2, message: 'Synthetic uncertain result' } });
    return send(200, { messages: [{ id }] });
  })
  .listen(port, '127.0.0.1', () => process.stdout.write(`R04 fake provider ready on ${port}\n`));
