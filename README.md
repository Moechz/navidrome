# Navidrome for TerraMaster TOS 7

TerraMaster TOS 7 App Center package (Docker application) for
[Navidrome](https://github.com/navidrome/navidrome) — a self-hosted music server
that streams your own collection to the web and to Subsonic-compatible clients.

- Application id: `navidromedocker`
- Version: **0.64.2-3** (upstream 0.64.2)
- Open: `http://<NAS-IP>:8157/`
- Help / privacy policy: <https://github.com/Moechz/navidrome/blob/main/PRIVACY.md>

## Repository layout

| Path | Purpose |
|---|---|
| `tosapp.json` | package spec: image, ports, volumes, environment, descriptions, translations. The single source of truth for the build |
| `src/config.ini` | TOS App Center metadata (version/platform placeholders are filled in at build time) |
| `src/navidromedocker.lang` | 23-language text file (TOS requires 14), generated from `tosapp.json` translations |
| `src/navidromedocker.svg` | application icon |
| `src/docker-compose.yml` | the compose project: one service, hardened (see below) |
| `src/entrypoint.sh` | wrapper started before `/app/navidrome`: `umask 077`, owner-only `/data` |
| `src/webui.bz2` | TOS front-end bundle (tar.bz2 with a root-level `index.html` that forwards to port 8157 — review item F22) |
| `scripts/build.sh` | build one architecture: stage → verify → pack → sha256 |
| `scripts/build-dual.sh` | build both architectures and run the official check |
| `tools/verify.py` | review-standards self-check, run as a hard gate by `build.sh` |
| `test/install-and-verify.sh` | on-device functional check against a real installation |
| `test/smoke.sh` | functional smoke test: web UI, admin creation, login, native API, Subsonic API |
| `PRIVACY.md` | full privacy policy (local data, endpoint table, retention, rights, security) |
| `NOTICE.md` | third-party notices, licence verification, trademarks |
| `CHANGELOG.md` | version history, code by code |

## What it does

1. Indexes the folder mounted at `/music`
   (`/Volume1/DockerAppData/navidromedocker/music`) into a library of artists,
   albums, tracks, genres and playlists.
2. Serves its own web player on port 8157, and the Subsonic / Jellyfin APIs so
   third-party clients on the LAN can stream the same library.
3. Transcodes formats the browser cannot play (ffmpeg is included in the image).

The complete state (database, users, playlists, play counts, caches) lives in
`/Volume1/DockerAppData/navidromedocker/`.

## Security and least privilege

| Measure | Value |
|---|---|
| User | `user: "1000:1000"` — never root |
| Capabilities | `cap_drop: [ALL]`, measured `CapEff 0000000000000000` |
| Privilege escalation | `security_opt: no-new-privileges:true` |
| File creation | `umask 077` in `src/entrypoint.sh` |
| Data directory | `/data` tree owner-only (`0700`), `/music` `0750` |
| Image | pinned by tag **and** digest (`deluan/navidrome:0.64.2@sha256:38dc…`) |
| Published ports | 8157 only (plain HTTP — put a TLS proxy in front for remote access) |

## Privacy

The application runs entirely on your NAS: the developer receives no data. One
endpoint set leaves the NAS, and it is disclosed in full:

- **Deezer**, **Last.fm** and **ListenBrainz** metadata lookups triggered by your
  own library scan (artist names, MusicBrainz ids, and scrobbles only if you link
  an account yourself),
- the optional login-page background from `www.navidrome.org`,
- upstream's **insights telemetry is disabled** in this package
  (`ND_ENABLEINSIGHTSCOLLECTOR=false`, verifiable at `/api/insights`).

Full detail, the endpoint table, retention periods, your access/correction/
deletion rights and the contact channel: **[PRIVACY.md](PRIVACY.md)**.

## Notices and licences

Navidrome is **GPL-3.0-or-later** (verified against the upstream repository at
tag `v0.64.2`); the Docker image is the official Docker Hub image used
unmodified. This packaging is GPL-3.0-or-later as well. Full attribution,
trademark statement and icon provenance: **[NOTICE.md](NOTICE.md)**.

## Data, uninstall and residual files

| Path | Content | On uninstall |
|---|---|---|
| `/Volume1/DockerAppData/navidromedocker/data` | database (users, library, playlists, play counts), artwork cache, transcoding cache, logs | kept unless *Uninstall → delete data* is chosen |
| `/Volume1/DockerAppData/navidromedocker/music` | your own music files | never touched by the package |

Docker packages have no uninstall hook, so removing the application leaves the
data folder in place on purpose (a reinstall keeps your library). To remove
everything, uninstall with the data option, or delete
`/Volume1/DockerAppData/navidromedocker/` afterwards (review item F11).

## Build

```bash
scripts/build-dual.sh 0.64.2-3     # both architectures + official -c check
scripts/build.sh 0.64.2-3          # one architecture (x86_64 by default)
scripts/build.sh 0.64.2-3 aarch64
```

`build.sh` stages the five entries (`config.ini`, `<appid>.lang`, `<appid>.svg`,
`docker-compose.yml`, `webui.bz2`), substitutes the version/platform
placeholders, embeds `src/entrypoint.sh` into the compose block scalar, strips
BOM/CRLF (never from the binary `webui.bz2`) and then runs `tools/verify.py` as a
hard gate: archive layout, `webui.bz2` structure, JSON validity, required fields,
language coverage, version consistency, Docker-Hub-only images with a fixed tag,
reserved host ports, non-root user, per-service healthcheck/TZ/restart, data
paths below the application data root, never the `/Volume*` wildcard, comment-free
sequence blocks, `x-app-meta` last, no literal secrets, and the SVG rules.
The `.tar.gz` is deterministic (uid/gid 0, zeroed mtimes, gzip without a
timestamp) and a `.sha256` is written next to it.

## Verification

```bash
# official validator (both packages must say "check passed")
TOSAppSelfTestingTool -c out/navidromedocker_x86_64.tar.gz
TOSAppSelfTestingTool -c out/navidromedocker_aarch64.tar.gz

# functional smoke test against a running instance
bash test/smoke.sh http://127.0.0.1:8157

# inspect the front-end bundle shipped in the package
tar tjvf out/../src/webui.bz2     # -> index.html
```

`test/smoke.sh` proves the delivered functionality, not just that a port answers:
it creates the first admin, rejects a wrong password, logs in, calls the native
API with the issued JWT, checks that the insights collector reports
`"lastRun":"disabled"`, and calls the Subsonic API with a token.

## Store submission

Tag `v0.64.2-3` with the two assets `navidromedocker_x86_64.tar.gz` and
`navidromedocker_aarch64.tar.gz` (plus their `.sha256`). The two App Center
records (`navidromedocker` on `x86_64` and `aarch64`) are submitted separately;
the platform `file_hash` must equal the local SHA-256.

## Limitations

- No GPU: transcoding is CPU-bound; a library full of high-bitrate files can keep
  the NAS CPU busy.
- Only port 8157 is published. Subsonic clients need LAN access, a VPN or your own
  reverse proxy.
- The package terminates no TLS. Do not expose port 8157 directly to the internet.
- Artist biographies and photos depend on third-party metadata services; when
  they are disabled literally (see `PRIVACY.md` §5) the UI shows local artwork
  only.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.
