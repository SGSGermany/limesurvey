#!/bin/sh
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

if [ -e "/var/www/limesurvey_version_info" ]; then
    OLD_HASH="$(sed -ne 's/^HASH=\(.*\)$/\1/p' /var/www/limesurvey_version_info)"
    NEW_HASH="$(sed -ne 's/^HASH=\(.*\)$/\1/p' /usr/src/limesurvey/version_info)"

    if [ -n "$OLD_HASH" ] && [ "$OLD_HASH" == "$NEW_HASH" ]; then
        exit
    fi

    OLD_VERSION="$(sed -ne 's/^VERSION=\(.*\)$/\1/p' /var/www/limesurvey_version_info)"
else
    OLD_VERSION=""
fi

NEW_VERSION="$(sed -ne 's/^VERSION=\(.*\)$/\1/p' /usr/src/limesurvey/version_info)"

# sync LimeSurvey files
if [ -z "$OLD_VERSION" ]; then
    echo "Initializing LimeSurvey $NEW_VERSION..."
else
    echo "Upgrading LimeSurvey $OLD_VERSION to $NEW_VERSION..."

    TMPDIR_UPLOAD="$(mktemp -d)"
    rsync -rlptog \
        "/var/www/html/upload/" \
        "$TMPDIR_UPLOAD/"
fi

rsync -rlptog --delete --chown www-data:www-data \
    "/usr/src/limesurvey/limesurvey/" \
    "/var/www/html/"

rsync -lptog --chown www-data:www-data \
    "/usr/src/limesurvey/version_info" \
    "/var/www/limesurvey_version_info"

# run install script
if [ -z "$OLD_VERSION" ]; then
    /usr/lib/limesurvey/setup/install.sh
else
    rsync -rlptog \
        "$TMPDIR_UPLOAD/" \
        "/var/www/html/upload/"
    rm -rf "$TMPDIR_UPLOAD"

    /usr/lib/limesurvey/setup/upgrade.sh
fi
