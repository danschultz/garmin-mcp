# garmin-mcp

Container image for [taxuspt/garmin_mcp](https://github.com/taxuspt/garmin_mcp), built from a pinned upstream commit.

Upstream doesn't publish an image. This wrapper builds one and adds:

- **Docker secret support for the HTTP bearer token.** Set `GARMIN_MCP_HTTP_TOKEN_FILE=/path/to/secret` and the entrypoint reads the file into `GARMIN_MCP_HTTP_TOKEN`. (Upstream already supports `GARMIN_EMAIL_FILE` and `GARMIN_PASSWORD_FILE`.)
- **Non-root user.** Runs as `app` (uid/gid `10001`), with `HOME=/home/app`.
- **Pinned, reproducible builds.** The upstream commit is set by `GARMIN_MCP_REF` in the `Dockerfile`.

```
ghcr.io/danschultz/garmin-mcp:<version>
```

## Usage

The default command is `garmin-mcp`. Pass a different command to run something else, such as the one-time MFA login:

```sh
docker run -it --rm \
  -v garmin-tokens:/home/app/.garminconnect \
  ghcr.io/danschultz/garmin-mcp:<version> garmin-mcp-auth
```

Serving over streamable HTTP:

```yaml
services:
  garmin-mcp:
    image: ghcr.io/danschultz/garmin-mcp:<version>
    secrets:
      - garmin_mcp_http_token
    environment:
      GARMIN_MCP_TRANSPORT: streamable-http
      GARMIN_MCP_HOST: 0.0.0.0
      GARMIN_MCP_PORT: 8000
      GARMIN_MCP_HTTP_TOKEN_FILE: /run/secrets/garmin_mcp_http_token
      GARMINTOKENS: /home/app/.garminconnect
      GARMIN_TOOL_PROFILE: health
    volumes:
      - garmin-tokens:/home/app/.garminconnect
```

The token directory must be writable by uid `10001` so token refreshes can be saved.

## Supported `_FILE` variables

| `_FILE` variable | Populates | Description |
|---|---|---|
| `GARMIN_MCP_HTTP_TOKEN_FILE` | `GARMIN_MCP_HTTP_TOKEN` | Bearer token required on HTTP requests |

If both `FOO` and `FOO_FILE` are set, `FOO` wins. A `FOO_FILE` that points to a missing file stops the container on startup.

## Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `pr.yml` | Pull request | Builds the image, smoke-tests it, and pushes `pr-<number>` |
| `release.yml` | Manual (`version` input) | Tags `v<version>`, pushes `<version>`, `<major>.<minor>`, `<major>` and `latest`, and creates a GitHub release that records the upstream commit |
| `update-upstream.yml` | 1st of each month, or manual | Opens a PR bumping `GARMIN_MCP_REF` when upstream `main` moves |

Dependabot keeps GitHub Actions, the Python base image and uv up to date.

### Upgrading upstream

1. Review the diff linked in the `update-upstream` PR and merge it.
2. Run **Release** with the next version.
3. Bump the image tag wherever it's deployed.

### Repository setup

- **Settings → Actions → General → Workflow permissions:** turn on *Allow GitHub Actions to create and approve pull requests*. Without it, `update-upstream.yml` can't open PRs.
- **Optional: `UPSTREAM_BUMP_TOKEN` secret.** PRs opened with the default `GITHUB_TOKEN` don't trigger `pr.yml`. Add a fine-grained PAT with *Contents* and *Pull requests* write access on this repo so upstream-bump PRs are built and tested automatically.
