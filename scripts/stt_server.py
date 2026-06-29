#!/usr/bin/env python3
"""Local STT server using faster-whisper. Listens on :8646 for WAV POSTs."""
import sys, os, json, tempfile, logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from faster_whisper import WhisperModel

logging.basicConfig(level=logging.INFO, format='%(asctime)s STT %(message)s')
log = logging.getLogger('stt')

MODEL_SIZE = os.environ.get('STT_MODEL', 'base')
DEVICE = os.environ.get('STT_DEVICE', 'auto')
COMPUTE = os.environ.get('STT_COMPUTE', 'int8')
PORT = int(os.environ.get('STT_PORT', '8646'))

log.info(f"Loading faster-whisper {MODEL_SIZE} on {DEVICE}...")
model = WhisperModel(MODEL_SIZE, device=DEVICE, compute_type=COMPUTE)
log.info("Model loaded.")

class STTHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "model": MODEL_SIZE}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path != '/v1/audio/transcriptions':
            self.send_response(404)
            self.end_headers()
            return
        content_len = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_len)
        # Extract WAV from multipart
        boundary = None
        ct = self.headers.get('Content-Type', '')
        if 'boundary=' in ct:
            boundary = ct.split('boundary=')[1].strip()
        if boundary:
            # Simple multipart parser
            parts = body.split(f'--{boundary}'.encode())
            wav_data = None
            for part in parts:
                if b'audio/wav' in part or b'audio/x-wav' in part or b'name="file"' in part:
                    idx = part.find(b'\r\n\r\n')
                    if idx > 0:
                        wav_data = part[idx+4:]
                        if wav_data.endswith(b'\r\n'):
                            wav_data = wav_data[:-2]
                        if wav_data.endswith(b'--'):
                            wav_data = wav_data[:-2]
                        break
            if not wav_data:
                self._json(400, {"error": "no audio file found"})
                return
        else:
            wav_data = body

        # Write to temp file
        tmp = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
        tmp.write(wav_data)
        tmp.close()
        try:
            segments, info = model.transcribe(tmp.name, language='en')
            text = ' '.join(seg.text for seg in segments)
            self._json(200, {"text": text})
        except Exception as e:
            log.error(f"Transcription error: {e}")
            self._json(500, {"error": str(e)})
        finally:
            os.unlink(tmp.name)

    def _json(self, code, data):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def log_message(self, fmt, *args):
        log.info(f"{self.client_address[0]} - {fmt % args}")

log.info(f"STT server on :{PORT}")
HTTPServer(('127.0.0.1', PORT), STTHandler).serve_forever()
