FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /opt/venv \
    && useradd --create-home appuser \
    && install -d -o appuser -g appuser /var/log/api-gateway

ENV PATH=/opt/venv/bin:$PATH

WORKDIR /app

COPY srcs/api-gateway-app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY srcs/api-gateway-app/app ./app
COPY srcs/api-gateway-app/server.py .

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=5s --timeout=5s --start-period=15s --retries=10 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:3000/health', timeout=3)" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:3000", "--workers", "2", "--access-logfile", "-", "server:app"]
