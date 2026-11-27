# NOTICE — third-party components and attributions

This package (`navidromedocker`, TOS 7 Docker application) is an independent
packaging by **Moechz** of the upstream **Navidrome** project. It is not
affiliated with, sponsored or endorsed by the upstream project or by
TerraMaster.

## 1. Upstream application — Navidrome

| | |
|---|---|
| Project | <https://github.com/navidrome/navidrome> |
| Reviewed release | **v0.64.2** (tag `v0.64.2`, commit `101145742f4762164202cb4858c9126258bdc463`) |
| Licence | **GPL-3.0-or-later** — verified against the `LICENSE` file in the upstream repository at tag `v0.64.2`, which is the verbatim GNU GPL v3 text. The metadata `GPL-3.0` of earlier releases of this package was incomplete: the correct identifier is GPL-3.0-or-later (review item C2) |
| Copyright | © the Navidrome authors and contributors |
| Relationship | The upstream application is used **unmodified**. No upstream source code is redistributed in this repository |

The full licence text is in [LICENSE](LICENSE) (GNU GPL v3), which is the text
shipped by the upstream project.

## 2. Container image

| | |
|---|---|
| Image | `deluan/navidrome:0.64.2` |
| Registry | Docker Hub (the only registry the TOS store accepts) |
| Digest | `sha256:38dc2727bfcfd5ede290f8ada114fc90368146f265ae4701ddddbcbe2a44ee52` (OCI image index) |
| Platforms | `linux/amd64`, `linux/arm64` |
| Built | 2026-09-24, for the upstream v0.64.2 release |
| Base | Alpine Linux 3.22.6 (the image's own `/etc/alpine-release`) |

The digest is pinned in `tosapp.json` and `docker-compose.yml`, so the store
installs exactly the image that was reviewed.

### Base-image packages and CVEs (review item T1)

The image bundles Alpine packages (ffmpeg, curl, gnutls, pcre2, zlib, libpng,
musl) that carry published advisories in the Alpine 3.22 branch, fixed in later
point releases of that branch. A packaging-only repository cannot rebuild the
upstream image: patching it would mean redistributing a modified Navidrome
binary, which the store rules forbid and which would also break the "official
image, unmodified" property this package is built on. The mitigation and the
follow-up plan are documented in [CHANGELOG.md](CHANGELOG.md) under 0.64.2-3 /
T1: digest pin, `cap_drop: ALL`, `no-new-privileges`, non-root uid 1000 and the
commitment to rebuild the package as soon as upstream publishes a release (or a
rebuilt image) that carries the fixed packages.

## 3. Third-party services

The application can contact Deezer, Last.fm, ListenBrainz and the Navidrome
project website, and it ships upstream's insights collector **disabled**. The
endpoint table, the data each service receives and the switches that turn them
off are in [PRIVACY.md](PRIVACY.md) §5.

## 4. Components of this packaging

Authored for this package and released under **GPL-3.0-or-later**:

- TOS metadata (`tosapp.json`, `src/config.ini`), the 23-language file
  (`src/navidromedocker.lang`), the icon (`src/navidromedocker.svg`),
- the compose project (`src/docker-compose.yml`), the entrypoint wrapper
  (`src/entrypoint.sh`), the front-end bundle (`src/webui.bz2`),
- the build and verification scripts (`scripts/`, `tools/`), the tests
  (`test/`), and this documentation.

## 5. Trademarks

"Navidrome" is the name of the upstream project. "TerraMaster" and "TOS" are
trademarks or registered trademarks of TerraMaster. All trademarks are used here
descriptively only, to identify the software being packaged and the platform it
runs on.

## 6. Icon

The application icon is a mark assembled for this package (pure vector, no
third-party logo, no embedded bitmap). It is not the upstream project logo.

## 7. Contact

Moechz — <moechz@163.com> — <https://www.moechz.com/>
Repository: <https://github.com/Moechz/navidrome>
