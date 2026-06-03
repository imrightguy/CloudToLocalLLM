"""
Twitch Bot REST API — wraps the StreamCoPilot for external control.
Integrates as a CloudToLocalLLM service: services/twitch-bot/
"""

import os
import sys
import json
import asyncio
import logging
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("twitch-api")

# ── Import bot ──────────────────────────────────────────────────────────
sys.path.insert(0, os.path.dirname(__file__))
import bot

# ── Globals ─────────────────────────────────────────────────────────────
twitch_bot: bot.StreamCoPilot | None = None
bot_task: asyncio.Task | None = None


# ── Lifespan ────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start the Twitch bot on API startup."""
    global twitch_bot, bot_task

    # Check required env
    missing = []
    if not bot.TWITCH_CLIENT_ID: missing.append("TWITCH_CLIENT_ID")
    if not bot.TWITCH_CLIENT_SECRET: missing.append("TWITCH_CLIENT_SECRET")
    if not bot.BOT_ID: missing.append("BOT_ID")

    if missing:
        log.warning(f"Twitch bot disabled — missing env: {', '.join(missing)}")
        yield
        return

    twitch_bot = bot.StreamCoPilot()
    bot_task = asyncio.create_task(twitch_bot.start())
    log.info("Twitch bot started in background")
    yield
    if twitch_bot:
        await twitch_bot.close()
        bot_task.cancel()
        log.info("Twitch bot shut down")


# ── App ─────────────────────────────────────────────────────────────────

app = FastAPI(
    title="CloudToLocalLLM - Twitch Co-Pilot",
    version="1.0.0",
    lifespan=lifespan,
)


# ── Models ──────────────────────────────────────────────────────────────

class SendMessageRequest(BaseModel):
    message: str


# ── Endpoints ───────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    """Service health check."""
    if twitch_bot is None:
        return {"status": "disabled", "reason": "missing env"}
    return {
        "status": "running",
        "channel": bot.CHANNEL_NAME or "not set",
        "streamer_status": twitch_bot.streamer_status,
    }


@app.get("/chat/recent")
async def recent_chat(count: int = Query(default=15, ge=1, le=100)):
    """Get recent chat messages."""
    if not twitch_bot:
        raise HTTPException(503, "Twitch bot not started")
    return {
        "channel": bot.CHANNEL_NAME,
        "count": count,
        "messages": twitch_bot.last_chat_log[-count:],
    }


@app.get("/stream/status")
async def stream_status():
    """Current stream status."""
    if not twitch_bot:
        raise HTTPException(503, "Twitch bot not started")
    return {
        "channel": bot.CHANNEL_NAME,
        "status": twitch_bot.streamer_status,  # "live" or "offline"
        "title": twitch_bot.stream_title or "",
        "game": twitch_bot.game_name or "",
        "viewers": twitch_bot.viewer_count,
    }


@app.post("/chat/send")
async def send_chat(req: SendMessageRequest):
    """Send a message to Twitch chat."""
    if not twitch_bot:
        raise HTTPException(503, "Twitch bot not started")
    if not req.message.strip():
        raise HTTPException(400, "Message cannot be empty")
    channel = twitch_bot.get_channel(bot.CHANNEL_NAME)
    if not channel:
        raise HTTPException(503, "Not connected to channel")
    await channel.send(req.message)
    return {"sent": True, "message": req.message}


@app.get("/events/stream")
async def stream_events():
    """Server-Sent Events stream for real-time chat."""
    if not twitch_bot:
        raise HTTPException(503, "Twitch bot not started")

    async def event_generator():
        while True:
            messages = twitch_bot.drain_chat()
            if messages:
                for msg in messages:
                    yield f"data: {json.dumps(msg)}\n\n"
            # Also send stream status changes
            status = {
                "status": twitch_bot.streamer_status,
                "title": twitch_bot.stream_title or "",
                "game": twitch_bot.game_name or "",
                "viewers": twitch_bot.viewer_count,
            }
            yield f"event: status\ndata: {json.dumps(status)}\n\n"
            await asyncio.sleep(1)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


# ── Entrypoint ──────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("TWITCH_BOT_PORT", 8510))
    log.info(f"Starting Twitch Co-Pilot API on :{port}")
    uvicorn.run("api:app", host="0.0.0.0", port=port, reload=False)
