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

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"
source "$CI_TOOLS_PATH/helper/php.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

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

VERSION="$(git_latest "$LIMESURVEY_GIT_REPO" "$LIMESURVEY_VERSION_PATTERN")"

git_clone "$LIMESURVEY_GIT_REPO" "refs/tags/$VERSION" \
    "$MOUNT/usr/src/limesurvey/limesurvey" "…/usr/src/limesurvey/limesurvey"

echo + "HASH=\"\$(git -C …/usr/src/limesurvey/limesurvey rev-parse HEAD)\"" >&2
HASH="$(git -C "$MOUNT/usr/src/limesurvey/limesurvey" rev-parse HEAD)"

git_ungit "$MOUNT/usr/src/limesurvey/limesurvey" "…/usr/src/limesurvey/limesurvey"

echo + "ln -s /etc/limesurvey/config.inc.php …/usr/src/limesurvey/limesurvey/application/config/config.php" >&2
ln -s "/etc/limesurvey/config.inc.php" "$MOUNT/usr/src/limesurvey/limesurvey/application/config/config.php"

echo + "ln -s /etc/limesurvey/security.inc.php …/usr/src/limesurvey/limesurvey/application/config/security.php" >&2
ln -s "/etc/limesurvey/security.inc.php" "$MOUNT/usr/src/limesurvey/limesurvey/application/config/security.php"

cmd buildah run "$CONTAINER" -- \
    /bin/sh -c "printf '%s=%s\n' \"\$@\" > /usr/src/limesurvey/version_info" -- \
        VERSION "$VERSION" \
        HASH "$HASH"

cleanup "$CONTAINER"

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
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
