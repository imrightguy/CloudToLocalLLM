# CloudToLocalLLM - Twitch Co-Pilot
FROM python:3.12-slim
WORKDIR /app

# Create zoidbot user
RUN addgroup --gid 1001 --system zoidbot && \
    adduser --system --uid 1001 --home /app --shell /bin/sh --ingroup zoidbot zoidbot

# Install deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY bot.py api.py ./

# Fix ownership
RUN chown -R zoidbot:zoidbot /app

EXPOSE 8510

USER zoidbot

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8510/health')" || exit 1

CMD ["python3", "api.py"]
