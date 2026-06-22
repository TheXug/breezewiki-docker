# breezewiki-docker

A Dockerfile that builds [BreezeWiki](https://breezewiki.com) directly from source. BreezeWiki doesn't
ship an official Docker image, so this builds it on top of the official
`racket/racket` image, following the steps in the
[BreezeWiki docs](https://docs.breezewiki.com/Running.html).

## Deploying with Portainer

Use `portainer.yml` as your Docker compose template for Portainer's web editor. Make sure you replace
the example domain with whatever the url is (including https://).

To update later, redeploy the stack from Portainer (it'll pull the latest
commit from the branch and rebuild, since this uses `build:` rather than a
fixed image tag). See [Updating](#updating) below for pinning a specific
version instead of always tracking `main`.

Ensure that, if you use a reverse proxy, it is on the same network as your BreezeWiki stack.

## Docker / Docker Compose


### Docker Compose

```bash
git clone https://github.com/thexug/breezewiki-docker.git
cd breezewiki-docker
BW_CANONICAL_ORIGIN=https://wiki.yourdomain.com docker compose up -d --build
```

`BW_CANONICAL_ORIGIN` is required. If you don't want to keep typing it for
each command, use a .env

### `docker`

```bash
docker build -t breezewiki:local .
docker run -d \
  --name breezewiki \
  -p 10416:10416 \
  -e bw_canonical_origin=https://wiki.yourdomain.com \
  --restart unless-stopped \
  breezewiki:local
```

Make sure it's online:

```bash
curl -I http://localhost:10416/
```

and open `http://localhost:10416` (or wherever you've published the port) in a browser.

## Configuration

BreezeWiki reads settings from a `config.ini` file, environment variables, or
both (env vars win if both are set). Full reference:
[docs.breezewiki.com/Configuration.html](https://docs.breezewiki.com/Configuration.html).

Environment variables - prefix any setting with `bw_`, e.g.:

```bash
-e bw_canonical_origin=https://wiki.yourdomain.com
-e bw_debug=false
-e bw_feature_search_suggestions=true
```

Config file - copy `config.ini.example` to `config.ini`, edit it, and mount
it into the container:

```bash
docker run -d -p 10416:10416 -v ./config.ini:/breezewiki/config.ini:ro breezewiki:local
```

The one setting worth setting for any public-facing instance is
`canonical_origin` (or `bw_canonical_origin`/`BW_CANONICAL_ORIGIN`), the
public URL where people will reach your instance. See the Portainer or
plain-Docker sections above for where to set it depending on how you're deploying.

## Running behind a reverse proxy

BreezeWiki only speaks plain HTTP on port 10416. TLS termination and
domain routing are expected to happen in front of it. The general shape is
the same regardless of which proxy you use: forward `https://wiki.yourdomain.com`
to `http://<host-running-the-container>:10416`.

Examples:

#### Nginx

```nginx
server {
    listen 443 ssl;
    server_name wiki.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:10416;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### Caddy

```
wiki.yourdomain.com {
    reverse_proxy localhost:10416
}
```

#### Traefik (docker-compose labels)

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.breezewiki.rule=Host(`wiki.yourdomain.com`)"
  - "traefik.http.routers.breezewiki.entrypoints=websecure"
  - "traefik.http.routers.breezewiki.tls.certresolver=letsencrypt"
  - "traefik.http.services.breezewiki.loadbalancer.server.port=10416"
```

#### Nginx Proxy Manager

Add a Proxy Host with:
- **Forward Hostname/IP**: the host or container running BreezeWiki
- **Forward Port**: `10416`
- **Scheme**: `http`
- SSL: enable and request a Let's Encrypt certificate

Whichever proxy you use, make sure `BW_CANONICAL_ORIGIN` matches the public
HTTPS URL once DNS and proxy (if applicable) are in place.

## Updating

Since this builds from source rather than pulling a prebuilt image, updating
means rebuilding. In Portainer, (optionally, repull, and) redeploy the stack. From the CLI:

```bash
docker compose build --no-cache
docker compose up -d
```

By default the build always pulls the latest `main` branch. To pin a specific,
reproducible version instead, find a commit hash at
[gitdab.com/cadence/breezewiki/commits/branch/main](https://gitdab.com/cadence/breezewiki/commits/branch/main)
and set it as the `BREEZEWIKI_REF` build arg, either in `docker-compose.yml`,
or via `docker build --build-arg BREEZEWIKI_REF=<commit-hash> -t breezewiki:local .`
on the CLI.

## Notes

- Default port is `10416`, which is BreezeWiki's own default.
- This is **not official** and is **unaffiliated with BreezeWiki**. BreezeWiki's own docs note that Docker support is community-maintained, not upstream.
  If you hit BreezeWiki-specific bugs (rather than build/packaging issues), report them via the channels
  listed in the [BreezeWiki docs](https://docs.breezewiki.com/Reporting_Bugs.html)
  rather than here. An existing community image is also available at
  [PussTheCat-org/docker-breezewiki-quay](https://github.com/PussTheCat-org/docker-breezewiki-quay),
  worth comparing against.

## License

This repository (the `Dockerfile`, `docker-compose.yml`, and related files)
is provided under the MIT License.

[BreezeWiki itself](https://gitdab.com/cadence/breezewiki) is licensed under
the [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.html); this project
builds it unmodified from its published source and does not redistribute or
alter the source code.

## Issues

Please report any issues with this Docker integration. My configuration is Portainer + Nginx Proxy Manager (I like GUIs), so forgive me
for any mistakes which exist in any of the other implementations (and let me know, of course).
As stated before, any issues with BreezeWiki itself are not fixable by me. Ensure that an issue exists with BreezeWiki and not
this Docker integration by checking if it exists on the official BreezeWiki instance or instances often used by the anti-Fandom
community (like those included with IndieWikiBuddy, for instance).
