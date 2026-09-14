FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv \
    && useradd --create-home appuser

ENV PATH=/opt/venv/bin:$PATH

WORKDIR /app

COPY srcs/inventory-app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY srcs/inventory-app/app ./app
COPY srcs/inventory-app/server.py .

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=5s --timeout=5s --start-period=15s --retries=10 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3)" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "server:app"]
