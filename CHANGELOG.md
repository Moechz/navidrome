# Changelog

All notable user-visible changes to the Navidrome TOS application package.

## 0.64.2-3 — 2026-11-27

Remediation of the App Center **rejection** of 0.64.2-2. The aarch64 notice
listed `C3 C4 C5 C6 C7 C8 C9 F22 S11 T1`, the x86_64 notice listed
`C10 C2 C6 C8 C9 F11 S11 T1 V7`; this release answers the union, one item per
section below.

### C3 / C4 / C5 — privacy policy missing / incomplete / not accessible

- `PRIVACY.md` is rewritten as a complete policy: what is stored locally (per
  path), what leaves the NAS (per endpoint), retention, access / correction /
  deletion rights, security measures and the contact channel.
- `help` in `tosapp.json` **and** `src/config.ini` now points at the public
  policy `https://github.com/Moechz/navidrome/blob/main/PRIVACY.md` (it used to
  point at the GitHub issue list, which is not a policy — that was C5). Both
  copies are checked after unpacking the built package.

### C6 — data collection inconsistent with the declaration

Real finding: upstream Navidrome defaults to `EnableInsightsCollector=true` and
posts an install id, version, OS/arch, memory statistics, library counters,
configuration flags and the plugin list to
`https://insights.navidrome.org/collect` every 24 hours. The previous policy
claimed "no telemetry".

- `docker-compose.yml` now sets `ND_ENABLEINSIGHTSCOLLECTOR=false`, so the
  collector never runs. Verified from the API: `/api/insights` answers
  `{"lastRun":"disabled"}`, and `test/smoke.sh` asserts it.
- The remaining egress (metadata lookups) is described as it actually happens,
  including the artist names sent and the account-linked scrobbles.

### C7 — user data rights not provided

- `PRIVACY.md` §7 is a rights table: access / export, correction, deletion
  (data folder, App Center "delete data"), restriction / objection (switches to
  turn every third-party lookup off), withdrawal of scrobbling, portability.
- Assistance channel `moechz@163.com` with a 30-day answer commitment, plus the
  right to complain to a supervisory authority.

### C8 — third-party API usage not disclosed

- `PRIVACY.md` §5 lists every endpoint the server can contact: Deezer
  (`api.deezer.com`, `pipe.deezer.com`), Last.fm (`ws.audioscrobbler.com`,
  `www.last.fm`), ListenBrainz (`api.listenbrainz.org`,
  `labs.api.listenbrainz.org`), `www.navidrome.org` (login background) and the
  disabled `insights.navidrome.org`. Each row states the data sent and the
  destination country/region.
- Spotify is **not** listed: upstream removed the Spotify options in 0.64.x
  (`Spotify.ID` / `Spotify.Secret` are in `removedOptions`). Gravatar is not
  used (`ND_ENABLEGRAVATAR` stays at its default `false`).

### C9 — description inconsistent with the delivered functionality

- `descript` / `important` / `release_note` describe only what the package
  really delivers: library scan, web player, Subsonic and Jellyfin APIs,
  playlists, favourites, ratings, genre browsing, shares, internet radio,
  transcoding. The 508-character English text is inside the 512 limit.
- `zh-cn` and `zh-hk` were still the **beaverhabits** habit-tracker text; both
  are rewritten for Navidrome.
- No ASCII semicolon anywhere in the value lines of the 23-language file (the
  store parser treats `;` as an INI comment and truncates the text). Checked with
  `grep ';'` on the generated `src/navidromedocker.lang`.

### F22 — declared access path but no `webui.bz2` in the package

- `src/webui.bz2` added: a bzip2-compressed tar holding `index.html` at its root,
  which forwards the browser to `http://<host>:8157/` (same pattern as the
  `filebrowser` package).
- `scripts/build.sh` stages it into the package and excludes it from the
  byte-level CRLF/BOM cleanup (that cleanup would corrupt a binary archive).
- `tools/verify.py` now accepts exactly four required files **plus**
  `webui.bz2`, and fails the build if the bundle is missing, is not a bzip2
  tar, has no root-level `index.html`, has no `<title>`, or does not mention the
  application port. `tar tjvf src/webui.bz2` prints `index.html`.

### S11 — file permissions not minimised

- `user: "1000:1000"` (already present) plus `cap_drop: [ALL]` and
  `security_opt: no-new-privileges:true` — measured in the running container:
  `uid 1000`, `CapEff 0000000000000000`, `NoNewPrivs 1`.
- New `src/entrypoint.sh` (embedded in the compose block scalar, checked for
  equality by `verify.py`): `umask 077`, `/data` tree set owner-only (`0700`,
  no group/world bits), `/music` `0750`, all failures on root-owned mounts
  ignored so start-up never breaks.

### T1 — high or critical CVE

- **Upstream has no newer release.** Checked 2026-11-27: GitHub releases show
  `v0.64.2` (2026-09-24) as the newest release, and the Docker Hub tag list has
  no version tag after `0.64.2`; `latest` and `0.64.2` resolve to the same OCI
  index digest `sha256:38dc2727…`. Upstream already fixed two issues in 0.64.2
  itself (Content-Disposition sanitising, admin password in logs).
- The remaining findings are in the **base image packages**, not in Navidrome:
  querying OSV for the 194 installed apk packages of this image returns 32
  advisories in 6 packages — `curl 8.14.1-r3` (17), `pcre2 10.46-r0` (8),
  `gnutls 3.8.13-r0` (3), `zlib 1.3.2-r0` (2), `libpng 1.6.57-r0` (1),
  `musl 1.2.5-r12` (1). Each has a fix in a later Alpine 3.22 point release
  (e.g. `curl` `-r4`, `pcre2` `-r1`, `gnutls` 3.8.14, `zlib` `-r1`), but the
  published Navidrome image was built 2026-09-24 and still pins the older
  packages.
- A packaging repository cannot patch that: rebuilding the image would mean
  redistributing a modified Navidrome binary, which the store forbids and which
  would break the "official image, unmodified" guarantee. So:
  - the image is pinned **by digest**, so the reviewed bits are what gets
    installed and a silent re-tag cannot change them,
  - the running container has **no capabilities**, **no-new-privileges** and a
    non-root user, so a compromised process cannot escalate or write outside
    `/data` and `/music`,
  - the exposed surface is small: only port 8157 is published, and the
    vulnerable libraries are reachable only from data the user themselves owns
    (ffmpeg parses the user's own library, libcurl is not used by Navidrome's Go
    HTTP client at all),
  - **follow-up plan:** watch `navidrome/navidrome` releases and the Docker Hub
    image digest weekly; as soon as a rebuilt image (or a new upstream release)
    lands, bump the digest/tag, rebuild both architectures and submit a patch
    release. The same applies if the reviewer can share the scanner's CVE ids.
    Until then the item is documented instead of silently ignored.

### C2 / C10 / F11 / V7 — the x86_64 notice

- **C2 (intellectual property):** `tosapp.json` declared `GPL-3.0` while
  `LICENSE` in this repository was an MIT template — inconsistent, and the image
  is GPL software. `LICENSE` is now the verbatim GNU GPL v3 text taken from the
  upstream repository at tag `v0.64.2`; `license` and `upstream_license` are
  `GPL-3.0-or-later`; `NOTICE.md` records the verification (commit, licence,
  image digest, trademarks).
- **C10 (repository and directory layout):** `README.md` gained the required
  sections: repository layout, what it does, security measures, privacy,
  notices, data/uninstall, build, verification, store submission.
- **F11 (residual data after uninstall):** `README.md` and `PRIVACY.md` state
  what stays in `/Volume1/DockerAppData/navidromedocker/` after uninstall and how
  to delete it.
- **V7 (SHA-256 mismatch):** both packages are rebuilt from this tree.
  `scripts/build-dual.sh` writes `out/<appid>_<arch>.tar.gz.sha256`, and the
  platform `file_hash` reported by the submission task is compared with the local
  hash before the release note is accepted. The build is deterministic
  (uid/gid 0, mtimes 0, no gzip timestamp), so a rebuild of the same tree gives
  the same bytes.

### Package hygiene

- `tosapp.json` no longer carries the leftover `probe` block of a *different*
  application (`daya0576/beaverhabits`) in `docker-compose.yml`'s metadata, nor
  the stale `entrypoint`/`cmd` of that image. It is `mode: "wrapper"` now, which
  makes `verify.py` check the embedded entrypoint against `src/entrypoint.sh`.
- `upstream_version` is `0.64.2`, `version` `0.64.2-3`.

## 0.64.2-2 — 2026-11-24

- Version bump of 0.64.2-1, submitted to the App Center. **Rejected** on the
  items listed in 0.64.2-3; no functional change.

## 0.64.2-1 — 2026-11-14

### Added
- First release. Navidrome (`deluan/navidrome:0.64.2`, Docker Hub official image, unmodified)
  packaged as a TOS 7 Docker application, published on port 8157 and running
  as a non-root user (1000:1000).
- Persistent data is kept under `/Volume1/DockerAppData/navidromedocker/`.
