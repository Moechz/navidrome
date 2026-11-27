# Privacy Policy — Navidrome for TerraMaster TOS

**Application:** `navidromedocker` (Navidrome 0.64.2-3, TOS 7 Docker application)
**Publisher / data controller:** Moechz — <moechz@163.com>
**Last updated:** 27 November 2026
**Public URL of this policy:** <https://github.com/Moechz/navidrome/blob/main/PRIVACY.md>
**Upstream project:** <https://github.com/navidrome/navidrome>

This policy describes exactly what the package does with data. It covers the
application as delivered by this package: the official upstream image
`deluan/navidrome:0.64.2` (pinned by digest) started with the compose file and
the entrypoint wrapper in this repository.

---

## 1. Summary

- The application runs **entirely on your NAS**. The developer does not receive,
  collect, host or have access to your library, your users or your usage.
- There is **no account**, **no registration**, **no advertising** and **no
  analytics or crash-reporting SDK** anywhere in the package.
- One telemetry channel exists in upstream Navidrome (the *insights collector*).
  **This package ships it disabled** (see §4).
- The only outbound requests are metadata lookups triggered by your own library
  scan, plus an optional login-page background image. Every endpoint is listed
  in §5 with the data it receives.

## 2. What is stored locally, and where

Everything below lives inside the application data folder
`/Volume1/DockerAppData/navidromedocker/` and never leaves the NAS unless you
configure an external service yourself.

| Path | Content |
|---|---|
| `data/navidrome.db` (+ `-wal`, `-shm`) | SQLite database: your music library index (artists, albums, tracks, genres, file paths), users, **passwords (AES-GCM encrypted, see §8)**, playlists, play counts, favourites, star ratings, shares, radio stations, plugin records |
| `data/navidrome.toml` | the application configuration file, created only if you add one |
| `data/cache/` | downloaded artist/album artwork and API response caches |
| `data/` (transcoding cache) | temporary transcoded audio fragments, rebuilt on demand |
| `data/` logs | application log on stdout, collected by the Docker logging driver unless you set `ND_LOGFILE` |
| `music/` | **your own music files**, mounted read-only in practice: the application indexes them and streams them, it does not modify them |

The package itself contains no credential, no account and no pre-seeded data.

## 3. What does *not* happen

- No data is uploaded to the developer, at install time or later.
- No usage statistics, crash reports or device identifiers are sent to the
  developer or to TerraMaster by this package.
- No third-party cookies, pixels or fingerprinting scripts are added. The web UI
  is served from the container itself and stores a JWT session token in your own
  browser.
- No data is sold, rented or shared with advertisers or data brokers.

## 4. Telemetry of the upstream project — disabled in this package

Upstream Navidrome contains an "insights collector". With its default
(`ND_ENABLEINSIGHTSCOLLECTOR=true`) the server would `POST` to
`https://insights.navidrome.org/collect` every 24 hours, starting 30 minutes
after the first start, sending:

- a random installation id (generated locally, stored in the database),
- Navidrome version, uptime, Go build settings and Go version,
- OS type, distribution/version, whether it runs in a container, architecture,
  CPU count,
- memory allocator statistics,
- **library counters** (number of tracks, albums, artists, playlists, shares,
  radios, users, file suffixes),
- a set of configuration **flags** (feature toggles, cache sizes, log level —
  not the values you type), and the list of installed plugins.

**This package sets `ND_ENABLEINSIGHTSCOLLECTOR=false` in `docker-compose.yml`,
so the collector never runs and nothing is sent.** You can confirm it in your own
instance: `GET /api/insights` answers `{"lastRun":"disabled"}`.

## 5. Third-party endpoints the application can contact

These requests are made by the Navidrome server process, on your behalf, and are
part of normal operation. Data that reaches them is limited to what is listed.
Your public IP address is visible to every endpoint you contact, as with any
HTTP request.

| # | Service | Endpoint(s) | Data sent | Why | Destination / region |
|---|---|---|---|---|---|
| 1 | **Deezer** (metadata agent, enabled by default) | `api.deezer.com`, `pipe.deezer.com/api` | artist name, MusicBrainz artist id, and the language code configured for metadata (default `en`) | artist biography, photos, top tracks and related artists | Deezer SA — France / EU |
| 2 | **Last.fm** (metadata agent and optional scrobbling, enabled by default) | `ws.audioscrobbler.com/2.0/`, `www.last.fm` | artist, album and track names from your library, the shared Navidrome Last.fm API key, and — **only if you link your own Last.fm account** — your Last.fm session key and the listens you play (artist, title, album, timestamp) | artist/album information, similar artists, and scrobbling you enabled yourself | Audioscrobbler / Last.fm — United States |
| 3 | **ListenBrainz** (metadata agent and optional scrobbling, enabled by default) | `api.listenbrainz.org/1/`, `labs.api.listenbrainz.org` | artist names and MusicBrainz ids; and — **only if you paste your own user token** — the listens you play | artist popularity, similar artists, and scrobbling you enabled yourself | MetaBrainz Foundation — United States |
| 4 | **Navidrome project website** (login page background) | `www.navidrome.org/images/index.yml`, `www.navidrome.org/images/*.webp` | nothing but the HTTP request itself (your IP) | the decorative background image on the login screen. It falls back to an embedded image when offline. Set `ND_UILOGINBACKGROUNDURL` to your own picture to avoid the request entirely | United States |
| 5 | **Navidrome insights collector** | `insights.navidrome.org/collect` | nothing — **disabled in this package**, see §4 | anonymous project statistics upstream collects by default | United States (not contacted) |

Notes on the table:

- Google Gravatar is **not** used: upstream defaults `ND_ENABLEGRAVATAR=false`
  and this package does not change it, so no e-mail hash is sent anywhere.
- Spotify was removed from Navidrome upstream (the `Spotify.ID`/`Spotify.Secret`
  options are gone in 0.64.2), so no Spotify endpoint is contacted.
- Links such as "open this artist on Last.fm / MusicBrainz" are ordinary
  hyperlinks: they are followed only when **you** click them, in your browser,
  and are not requests made by the application.
- Subsonic-compatible client apps are not operated by the publisher. Whatever
  those clients send to their own vendors is outside this package's control.

### Turning the third-party lookups off

Every automatic lookup can be disabled. Add any of the following to the
`environment:` block of the application's compose file and restart it:

| Variable | Effect |
|---|---|
| `ND_ENABLEEXTERNALSERVICES=false` | master switch: disables Deezer, Last.fm and ListenBrainz metadata, the insights collector (already off) and external album-art URLs, and switches the login background to the built-in offline image |
| `ND_AGENTS=""` | disables only the metadata agents, keeping the rest as it is |
| `ND_ENABLEARTWORKPRECACHE=false` | stops the background pre-fetch of artist/album images |
| `ND_UILOGINBACKGROUNDURL=<your image or url>` | replaces the login background, no request to navidrome.org |
| `ND_LASTFM_ENABLED=false`, `ND_DEEZER_ENABLED=false`, `ND_LISTENBRAINZ_ENABLED=false` | disable one service each |

## 6. Retention

| Data | Retention |
|---|---|
| Library index, users, playlists, play counts, ratings, shares | kept until **you** delete them. No automatic expiry. |
| Artwork / API cache | kept until you delete it, rebuilt on demand, safe to remove at any time |
| Transcoding cache | temporary, scoped by size (`ND_TRANSCODINGCACHESIZE`, default `100MB`), evicted automatically |
| Application logs | the Docker logging driver (default `json-file`, rotated by Docker) or your own `ND_LOGFILE` setting |
| Data held by Deezer / Last.fm / ListenBrainz | governed by those services' own policies, over which the publisher has no control; see their privacy pages |
| Data held by the developer | none — nothing is collected |

## 7. Your rights (access, correction, deletion, objection)

You are the controller of this installation, and every right can be exercised
directly on your NAS.

| Right | How to exercise it |
|---|---|
| **Access / export** | The complete state is the data folder above. Copy `/Volume1/DockerAppData/navidromedocker/data` — it contains the database with every record. Individual playlists can be exported from the web UI, and any Subsonic-compatible client can download the library. |
| **Correction** | Edit albums, artists, tracks, users, playlists and shares in the web UI (`http://<nas>:8157`), or edit the tags of the music files themselves and rescan. |
| **Deletion** | Stop the application, then delete `/Volume1/DockerAppData/navidromedocker/` (or use *Uninstall → delete data* in the TOS App Center). Removing only `data/` deletes users, hashes, play counts and playlists; `music/` holds your own files (finding F11). |
| **Restrict / object to processing** | Turn the third-party lookups off with the variables in §5, or disconnect the Last.fm / ListenBrainz account in *Personal → Settings*. With them off the application processes data only on your NAS. |
| **Withdraw scrobbling consent** | Remove the Last.fm/ListenBrainz link in the web UI; previously submitted listens must be deleted at those services (they expose their own deletion tools). |
| **Portability** | The SQLite database and the JSON/Subsonic APIs are open formats; a copy of the data folder is a complete, readable backup. |

**Assistance channel.** If you believe the application processed data you did not
expect, write to **moechz@163.com** with the subject `Navidrome data request`.
A reply follows within **30 days**. The publisher can only advise: it holds no
copy of your data and therefore cannot read, change or delete it for you.
You also have the right to lodge a complaint with your local data-protection
supervisory authority.

## 8. Security measures

- The container runs as an unprivileged user (**uid/gid 1000**), never as root,
  with **all Linux capabilities dropped** (`cap_drop: ALL`) and
  `no-new-privileges`, so a setuid helper inside the image cannot regain root.
- The entrypoint wrapper sets **umask 077** and makes the data directory
  **owner-only** (0700 tree, no group/world bits), because it holds the database
  with the password hashes. This applies as far as file ownership allows: the
  App Center chowns the mount to uid 1000 at install, and a root-owned mount is
  left untouched rather than blocking the start. A shared `music/` folder stays
  group-readable only through its own permissions, and nothing is world-writable.
- The image is pinned by **tag + digest** (`deluan/navidrome:0.64.2@sha256:38dc…`),
  so the installed bits are exactly the reviewed ones.
- Passwords are stored **AES-GCM encrypted** (Navidrome needs the cleartext to
  answer Subsonic token authentication, so it cannot hash them); the encryption
  key is generated on the first start and kept in the database. Treat the data
  folder as a credential store: it is kept owner-only by the entrypoint wrapper.
  The package ships no credential and no default account. Sessions use
  short-lived JWTs.
- The application is served over **plain HTTP** on port 8157. Use a TLS reverse
  proxy (or a VPN) before exposing it beyond your LAN, and keep the package
  updated through the App Center.
- Data protection beyond this is the NAS owner's responsibility: disk
  encryption, backups and account hygiene are outside the package.

## 9. Children

The application is a self-hosted utility for adults managing their own music
collection. It is not directed at children and collects nothing from them.

## 10. Changes to this policy

Material changes are committed to this file in the same repository and reflected
in the "Last updated" line above. The package release notes state which review
finding a change answers.

## 11. Contact

**Moechz** — <moechz@163.com> — <https://www.moechz.com/>

Repository: <https://github.com/Moechz/navidrome>
