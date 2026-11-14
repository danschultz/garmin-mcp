# syntax=docker/dockerfile:1

# Separate stage so Dependabot can track the uv version.
FROM ghcr.io/astral-sh/uv:0.13.8 AS uv

FROM python:3.12-slim AS builder

# Upstream commit to build (https://github.com/taxuspt/garmin_mcp).
# Bumped automatically by .github/workflows/update-upstream.yml.
ARG GARMIN_MCP_REF=a2ca5fcac34524b83814fe2fcf3d479f8a75983f

# Overrides upstream's garminconnect pin (==0.3.2 at the ref above). Versions
# before 0.3.20 skip loading the mobile sign-in page before posting
# credentials, so Garmin's Cloudflare answers every login with 429/403.
# https://github.com/cyberjunky/python-garminconnect/pull/479
# Remove once upstream pins >=0.3.20.
ARG GARMINCONNECT_VERSION=0.3.20

COPY --from=uv /uv /usr/local/bin/uv
ADD https://github.com/taxuspt/garmin_mcp.git#${GARMIN_MCP_REF} /src

RUN echo "garminconnect==${GARMINCONNECT_VERSION}" > /tmp/overrides.txt \
 && uv venv /opt/venv \
 && VIRTUAL_ENV=/opt/venv uv pip install --no-cache --override /tmp/overrides.txt /src

FROM python:3.12-slim

ARG GARMIN_MCP_REF
ARG GARMINCONNECT_VERSION
LABEL org.opencontainers.image.source="https://github.com/danschultz/garmin-mcp" \
      org.opencontainers.image.description="taxuspt/garmin_mcp with Docker secret (_FILE) support" \
      io.github.taxuspt.garmin_mcp.ref="${GARMIN_MCP_REF}" \
      io.github.cyberjunky.garminconnect.version="${GARMINCONNECT_VERSION}"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:${PATH}" \
    HOME=/home/app

RUN groupadd --gid 10001 app \
 && useradd --uid 10001 --gid app --create-home --home-dir /home/app app \
 && install -d -o app -g app -m 700 /home/app/.garminconnect

COPY --from=builder /opt/venv /opt/venv
COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh

USER app
WORKDIR /home/app

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["garmin-mcp"]
