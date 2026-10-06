FROM python:3.12-slim-trixie AS builder

RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

WORKDIR /app
COPY srcs/billing-app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


FROM python:3.12-slim-trixie

RUN useradd --create-home appuser

ENV PATH=/opt/venv/bin:$PATH
WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY srcs/billing-app/app ./app
COPY srcs/billing-app/server.py .

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=5s --timeout=5s --start-period=15s --retries=10 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3)" || exit 1

CMD ["python", "server.py"]
