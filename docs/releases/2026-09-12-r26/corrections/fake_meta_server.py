#!/usr/bin/env python3
"""Deterministic local Meta boundary used only for R26 browser acceptance."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


templates = {}
previous_templates = {}
reconcile_counts = {}
edit_reconcile_counts = {}


class Handler(BaseHTTPRequestHandler):
    def json_response(self, status, payload):
        encoded = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length) or b"{}")
        if self.path.endswith("/message_templates"):
            provider_id = f"fake-{payload['name']}"
            templates[payload["name"]] = {**payload, "id": provider_id}
            reconcile_counts[payload["name"]] = 0
            print(f"CREATE {provider_id} {json.dumps(payload, sort_keys=True)}", flush=True)
            return self.json_response(200, {"id": provider_id, "status": "PENDING"})

        provider_id = self.path.rsplit("/", 1)[-1]
        for name, template in templates.items():
            if template["id"] == provider_id:
                previous_templates[name] = template.copy()
                templates[name] = {**template, **payload}
                edit_reconcile_counts[name] = 0
                print(f"EDIT {provider_id} {json.dumps(payload, sort_keys=True)}", flush=True)
                return self.json_response(200, {"success": True})
        return self.json_response(404, {"error": "unknown template"})

    def do_GET(self):
        parsed = urlparse(self.path)
        name = parse_qs(parsed.query).get("name", [""])[0]
        template = templates.get(name)
        if name in edit_reconcile_counts:
            edit_reconcile_counts[name] += 1
            attempt = edit_reconcile_counts[name]
            if attempt == 1:
                result = {**previous_templates[name], "status": "APPROVED"}
                print(f"RECONCILE {name} OLD_APPROVAL", flush=True)
            elif attempt == 2:
                result = {**template, "id": "fake-wrong-provider", "status": "APPROVED"}
                print(f"RECONCILE {name} WRONG_PROVIDER_ID", flush=True)
            else:
                result = {**template, "status": "APPROVED"}
                print(f"RECONCILE {name} APPROVED", flush=True)
            return self.json_response(200, {"data": [result]})

        reconcile_counts[name] = reconcile_counts.get(name, 0) + 1
        attempt = reconcile_counts[name]
        if not template or attempt == 2:
            print(f"RECONCILE {name} UNKNOWN", flush=True)
            return self.json_response(200, {"data": []})

        status = "REJECTED" if attempt == 1 else "APPROVED"
        result = {**template, "status": status}
        if status == "REJECTED":
            result["rejected_reason"] = "FAKE_POLICY_REVIEW"
        print(f"RECONCILE {name} {status}", flush=True)
        return self.json_response(200, {"data": [result]})

    def log_message(self, _format, *_args):
        return


if __name__ == "__main__":
    print("Fake Meta server listening on 127.0.0.1:55548", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 55548), Handler).serve_forever()
