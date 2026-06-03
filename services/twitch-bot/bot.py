#!/usr/bin/env python3
"""
🎮 Twitch Stream Co-Pilot Agent
Watches a stream, sees the streamer's screen, controls chat.
"""

import os
import sys
import json
import asyncio
import logging
import re
import random
from datetime import datetime
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("twitch-bot")

# ── Config from environment ─────────────────────────────────────────────
TWITCH_CLIENT_ID = os.environ.get("TWITCH_CLIENT_ID", "")
TWITCH_CLIENT_SECRET = os.environ.get("TWITCH_CLIENT_SECRET", "")
BOT_ID = os.environ.get("BOT_ID", "")                     # bot's Twitch user ID
CHANNEL_NAME = os.environ.get("CHANNEL_NAME", "")         # channel to join
OWNER_ID = os.environ.get("OWNER_ID", "")                 # streamer's Twitch user ID
PREFIX = os.environ.get("CMD_PREFIX", "!")
# ────────────────────────────────────────────────────────────────────────

import twitchio
from twitchio.ext import commands


class StreamCoPilot(commands.Bot):
    def __init__(self):
        super().__init__(
            client_id=TWITCH_CLIENT_ID,
            client_secret=TWITCH_CLIENT_SECRET,
            bot_id=BOT_ID,
            owner_id=OWNER_ID or None,
            prefix=PREFIX,
        )
        self.streamer_status = "offline"
        self.last_chat_log = []
        self.chat_since_check = []
        self.viewer_count = 0
        self.game_name = ""
        self.stream_title = ""
        self.channel = None  # set after joining in event_ready
        self._stream_check_task = None

    async def event_ready(self):
        """Called when logged in and ready."""
        print(f"\n{'='*60}")
        print(f"  🎮 Twitch Co-Pilot connected as bot_id={self.bot_id}")
        if CHANNEL_NAME:
            print(f"  📺 Watching: {CHANNEL_NAME}")
            channel = self.get_channel(CHANNEL_NAME)
            if channel:
                await channel.join()
                self.channel = channel
                print(f"  ✅ Joined #{CHANNEL_NAME}")
        print(f"{'='*60}\n")
        print("💬 Listening to chat. Commands:")
        print(f"  {PREFIX}status  — stream status")
        print(f"  {PREFIX}hype    — send hype")
        print(f"  {PREFIX}ping    — pong\n")
        self._stream_check_task = asyncio.create_task(self._stream_check_loop())

    async def event_message(self, payload: twitchio.ChatMessage):
        """Every chat message in the channel."""
        if payload.chatter.id == self.bot_id:
            return
        if payload.source_broadcaster is not None:
            return

        ts = datetime.now().strftime("%H:%M:%S")
        entry = {
            "time": ts,
            "user": payload.chatter.name,
            "text": payload.content,
            "is_mod": payload.chatter.is_mod,
            "is_sub": payload.chatter.is_subscriber,
            "id": payload.id,
        }
        self.chat_since_check.append(entry)
        self.last_chat_log.append(entry)
        if len(self.last_chat_log) > 200:
            self.last_chat_log = self.last_chat_log[-100:]

        # Console log
        badge = ""
        if entry["is_mod"]:
            badge += "🛡️"
        if entry["is_sub"]:
            badge += "⭐"
        print(f"💬 [{ts}] {badge}{entry['user']}: {entry['text']}")

        # Auto-mod: links from non-mods
        if re.search(r'https?://[^\s]+', payload.content) and not payload.chatter.is_mod:
            print(f"  ⚠️ Link from non-mod: {payload.chatter.name}")

        # Auto-mod: caps spam
        caps = sum(1 for c in payload.content if c.isupper())
        if len(payload.content) > 15 and caps / max(len(payload.content), 1) > 0.7:
            print(f"  ⚠️ Caps spam: {payload.chatter.name}")

        await self.handle_commands(payload)

    # ── Commands ──

    @commands.command(name="ping")
    async def cmd_ping(self, ctx: commands.Context):
        await ctx.send("Pong! 🏓")

    @commands.command(name="status")
    async def cmd_status(self, ctx: commands.Context):
        status = "🔴 LIVE" if self.streamer_status == "live" else "⚫ OFFLINE"
        game = self.game_name or "N/A"
        title = (self.stream_title or "N/A")[:80]
        viewers = self.viewer_count
        await ctx.send(f"📺 {status} | 🎮 {game} | 👁️ {viewers} | {title}")

    @commands.command(name="hype")
    async def cmd_hype(self, ctx: commands.Context):
        hypes = [
            "Let's gooo! 🔥",
            "POGGERS! 🎉",
            "This is insane! 🔥",
            "STREAMER IS COOKING! 👨‍🍳🔥",
            "HYPEEEE! 🎉",
            "INSANE! 🤯",
        ]
        await ctx.send(random.choice(hypes))

    # ── Stream status polling ──

    async def _stream_check_loop(self):
        """Every 60s check if the stream is live via Helix API."""
        await asyncio.sleep(10)
        while True:
            try:
                await self._check_stream()
            except Exception as e:
                log.debug(f"Stream check error: {e}")
            await asyncio.sleep(60)

    async def _check_stream(self):
        if not CHANNEL_NAME:
            return
        users = await self.fetch_users(logins=[CHANNEL_NAME])
        if not users:
            return
        user_id = users[0].id
        streams = await self.fetch_streams(user_ids=[user_id])
        if streams:
            stream = streams[0]
            was_offline = self.streamer_status != "live"
            self.streamer_status = "live"
            self.viewer_count = stream.viewer_count
            self.game_name = stream.game_name or ""
            self.stream_title = stream.title or ""
            if was_offline:
                print(f"\n🔴 {CHANNEL_NAME} is LIVE!")
                print(f"   \"{self.stream_title}\" — {self.game_name}")
                print(f"   https://twitch.tv/{CHANNEL_NAME}")
        else:
            was_live = self.streamer_status == "live"
            self.streamer_status = "offline"
            if was_live:
                print(f"\n⚫ {CHANNEL_NAME} stream ended")

    # ── Chat query helpers ──

    def get_recent_chat(self, count=15) -> str:
        """Recent chat as formatted string."""
        recent = self.last_chat_log[-count:]
        if not recent:
            return "(no chat yet)"
        return "\n".join(f"[{m['time']}] {m['user']}: {m['text']}" for m in recent)

    def drain_chat(self) -> list:
        """Return new messages since last drain, clearing the buffer."""
        batch = self.chat_since_check.copy()
        self.chat_since_check.clear()
        return batch


async def main():
    missing = []
    if not TWITCH_CLIENT_ID:
        missing.append("TWITCH_CLIENT_ID")
    if not TWITCH_CLIENT_SECRET:
        missing.append("TWITCH_CLIENT_SECRET")
    if not BOT_ID:
        missing.append("BOT_ID")

    if missing:
        print("""
╔══════════════════════════════════════════════════════════════╗
║  🎮 Twitch Stream Co-Pilot                                 ║
╠══════════════════════════════════════════════════════════════╣
║  Missing: {0:45s} ║
║                                                              ║
║  REQUIRED:                                                   ║
║    TWITCH_CLIENT_ID     — from dev.twitch.tv/console/apps   ║
║    TWITCH_CLIENT_SECRET — from the same app                  ║
║    BOT_ID               — bot's Twitch user ID               ║
║                                                              ║
║  OPTIONAL:                                                   ║
║    CHANNEL_NAME         — channel to join & monitor          ║
║    OWNER_ID             — streamer's Twitch user ID          ║
║    CMD_PREFIX           — command prefix (default: !)        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
""".format(", ".join(missing)))
        sys.exit(1)

    bot = StreamCoPilot()
    print("🎮 Starting Twitch Co-Pilot...")
    await bot.start()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n👋 Shut down.")
