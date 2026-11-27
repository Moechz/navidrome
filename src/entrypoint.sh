#!/bin/sh
# ===========================================================================
# Entrypoint wrapper for the official Navidrome image (review finding S11).
#
# The upstream image starts /app/navidrome straight from its ENTRYPOINT, and its
# Dockerfile does not set USER, so the container would inherit whatever the
# runtime gives it. This package pins uid/gid 1000, drops every capability and
# sets no-new-privileges in docker-compose.yml; this script runs once, as uid
# 1000, right before the server EXECs, and only tightens what the app writes:
#
#   1. umask 077 - every file Navidrome creates (SQLite database, WAL/journal,
#      logs, image cache, transcoding temp files) is created without group or
#      world write access, instead of the image default 0022.
#   2. /data holds navidrome.db with the library, the users and their password
#      hashes, so the tree is made owner-only: 0700 directories, no group/world
#      bits on files.
#   3. /music is the user's own library and stays group-readable/traversable, so
#      a shared music folder keeps working while nothing becomes world writable.
#   4. Every chmod/find failure is ignored on purpose: the platform can hand
#      over root-owned mount points, which a non-root process cannot change.
#      Navidrome still starts; it just keeps the permissions it was given.
#
# This script must not contain a literal double dollar sign (the packaging step
# uses it as the escape sequence) and is never executed as root.
# ===========================================================================
set -u

umask 077

if [ -d /data ]; then
    chmod 0700 /data 2>/dev/null || true
    find /data -xdev -exec chmod go-rwx {} + 2>/dev/null || true
fi

if [ -d /music ]; then
    chmod 0750 /music 2>/dev/null || true
fi

exec /app/navidrome
