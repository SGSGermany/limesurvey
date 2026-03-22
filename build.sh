#!/bin/bash
# LimeSurvey
# A php-fpm container running LimeSurvey.
#
# Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C.UTF-8

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

[ -x "$(type -P curl 2>/dev/null)" ] \
    || { echo "Missing script dependency: curl" >&2; exit 1; }

[ -x "$(type -P unzip 2>/dev/null)" ] \
    || { echo "Missing script dependency: unzip" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/php.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

if [ -z "${VERSION:-}" ]; then
    VERSION="$("$BUILD_DIR/latest-version.sh")"
fi

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

PHP_FPM_OPEN_BASEDIR_CONF=( "/var/www/" "/etc/limesurvey/" "/usr/local/lib/php/" "/tmp/php/" "/dev/urandom" )
cmd php_patch_config_list -a "$CONTAINER" "/etc/php-fpm/pool.d/www.conf" \
    "php(_admin)?_(flag|value)" \
    "php_admin_value[open_basedir]" "$(IFS=:; echo "${PHP_FPM_OPEN_BASEDIR_CONF[*]}")"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

pkg_install "$CONTAINER" --virtual .limesurvey-run-deps \
    rsync

php_install_ext "$CONTAINER" \
    pdo_mysql \
    gd \
    ldap \
    zip \
    imap

user_add "$CONTAINER" mysql 65538

echo + "curl -L -o …/usr/src/limesurvey/limesurvey.zip $(quote "$(printf "$ARCHIVE_URL_TEMPLATE" "$VERSION")")" >&2
curl -L -o "$MOUNT/usr/src/limesurvey/limesurvey.zip" "$(printf "$ARCHIVE_URL_TEMPLATE" "$VERSION")"

echo + "unzip -d …/usr/src/limesurvey/ …/usr/src/limesurvey/limesurvey.zip" >&2
unzip -d "$MOUNT/usr/src/limesurvey/" "$MOUNT/usr/src/limesurvey/limesurvey.zip"

echo + "ln -s /etc/limesurvey/config.inc.php …/usr/src/limesurvey/limesurvey/application/config/config.php" >&2
ln -s "/etc/limesurvey/config.inc.php" "$MOUNT/usr/src/limesurvey/limesurvey/application/config/config.php"

echo + "ln -s /etc/limesurvey/security.inc.php …/usr/src/limesurvey/limesurvey/application/config/security.php" >&2
ln -s "/etc/limesurvey/security.inc.php" "$MOUNT/usr/src/limesurvey/limesurvey/application/config/security.php"

echo + "rm …/usr/src/limesurvey/limesurvey.zip" >&2
rm "$MOUNT/usr/src/limesurvey/limesurvey.zip"

cmd buildah run "$CONTAINER" -- \
    /bin/sh -c "printf '%s=%s\n' \"\$@\" > /usr/src/limesurvey/version_info" -- \
        VERSION "$VERSION"

cleanup "$CONTAINER"

con_cleanup "$CONTAINER"

cmd buildah config \
    --env LIMESURVEY_VERSION="$VERSION" \
    "$CONTAINER"

cmd buildah config \
    --entrypoint '[ "/entrypoint.sh" ]' \
    "$CONTAINER"

cmd buildah config \
    --volume "/var/www" \
    --volume "/run/mysql" \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="LimeSurvey" \
    --annotation org.opencontainers.image.description="A php-fpm container running LimeSurvey." \
    --annotation org.opencontainers.image.version="$VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/limesurvey" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    --annotation org.opencontainers.image.created="$(date -u +'%+4Y-%m-%dT%H:%M:%SZ')" \
    "$CONTAINER"

con_commit "$CONTAINER" "$IMAGE" "${TAGS[@]}"
