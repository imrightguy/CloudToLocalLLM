#!/usr/bin/env python3
"""Local STT server using faster-whisper, OpenAI-compatible /v1/audio/transcriptions.

Runs on the port LocalVoiceInputService expects (8643). Lightweight single-file,
no framework dependency beyond stdlib + faster-whisper.
"""

import json
import os
import sys
import tempfile
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

from faster_whisper import WhisperModel


MODEL_SIZE = os.environ.get("STT_MODEL", "base")
HOST = os.environ.get("STT_HOST", "127.0.0.1")
PORT = int(os.environ.get("STT_PORT", "8643"))


class STTHandler(BaseHTTPRequestHandler):
    model: WhisperModel = None  # set by main()

    def log_message(self, fmt, *args):
        """Quieter logging for demo use."""
        sys.stderr.write(f"[stt] {args[0]} {args[1]} {args[2]}\n")

    def _send_json(self, code, body):
        body_bytes = json.dumps(body).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body_bytes)))
        self.end_headers()
        self.wfile.write(body_bytes)

    def _send_error(self, code, msg):
        self._send_json(code, {"error": {"message": msg, "type": "api_error"}})

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health" or parsed.path == "/":
            self._send_json(200, {"status": "ok", "model": MODEL_SIZE})
        else:
            self._send_error(404, "Not Found")

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/v1/audio/transcriptions":
            self._send_error(404, f"Unknown endpoint: {parsed.path}")
            return

        content_type = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in content_type:
            self._send_error(400, "Expected multipart/form-data")
            return

        # Read the raw multipart body and extract the file field
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            self._send_error(400, "Empty request body")
            return

        body = self.rfile.read(content_length)
        boundary = content_type.split("boundary=", 1)[1].strip()
        if boundary.startswith('"') and boundary.endswith('"'):
            boundary = boundary[1:-1]

        # Crude but correct multipart parser for single-file uploads
        audio_data = self._extract_file(body, boundary)
        if audio_data is None:
            self._send_error(400, "No audio file found in multipart data")
            return

        try:
            tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            tmp.write(audio_data)
            tmp.close()

            segments, info = self.model.transcribe(
                tmp.name,
                language=None,
                beam_size=5,
                vad_filter=True,
            )
            text = " ".join(seg.text for seg in segments).strip()
            os.unlink(tmp.name)

            self._send_json(200, {"text": text})
        except Exception as e:
            self._send_error(500, str(e))

    def _extract_file(self, body: bytes, boundary: str) -> bytes | None:
        """Extract the first file payload from a multipart body."""
        boundary_bytes = f"--{boundary}".encode("utf-8")
        parts = body.split(boundary_bytes)
        for part in parts:
            if b"Content-Disposition" not in part:
                continue
            # Find the blank line separating headers from body
            header_end = part.find(b"\r\n\r\n")
            if header_end == -1:
                continue
            # Body ends at trailing \r\n-- or \r\n\r\n
            payload = part[header_end + 4:]
            # Strip trailing boundary markers
            if payload.endswith(b"--\r\n"):
                payload = payload[:-4]
            elif payload.endswith(b"\r\n"):
                payload = payload[:-2]
            if len(payload) > 0:
                return payload
        return None


def main():
    print(f"[stt] Loading faster-whisper model '{MODEL_SIZE}'...", file=sys.stderr)
    model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")
    STTHandler.model = model

    server = HTTPServer((HOST, PORT), STTHandler)
    print(f"[stt] Listening on http://{HOST}:{PORT}", file=sys.stderr)
    print(f"[stt] Endpoint: POST /v1/audio/transcriptions", file=sys.stderr)
    sys.stderr.flush()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[stt] Shutting down.", file=sys.stderr)
        server.server_close()


if __name__ == "__main__":
    main()
