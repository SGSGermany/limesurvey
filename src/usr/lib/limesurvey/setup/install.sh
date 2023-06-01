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

read_secret() {
    local SECRET="/run/secrets/$1"

    [ -e "$SECRET" ] || { echo "Failed to read '$SECRET' secret: No such file or directory" >&2; return 1; }
    [ -f "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Not a file" >&2; return 1; }
    [ -r "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Permission denied" >&2; return 1; }
    cat "$SECRET" || return 1
}

# run LimeSurvey's setup routine, if necessary
if ! limesurvey updatedb > /dev/null; then
    LIMESURVEY_ADMIN_USER="$(read_secret "limesurvey_admin_user")"
    LIMESURVEY_ADMIN_PASSWORD="$(read_secret "limesurvey_admin_password")"
    LIMESURVEY_ADMIN_NAME="$(read_secret "limesurvey_admin_name")"
    LIMESURVEY_ADMIN_EMAIL="$(read_secret "limesurvey_admin_email")"

    echo "Running LimeSurvey setup routine..."
    limesurvey install \
        "$LIMESURVEY_ADMIN_USER" \
        "$LIMESURVEY_ADMIN_PASSWORD" \
        "$LIMESURVEY_ADMIN_NAME" \
        "$LIMESURVEY_ADMIN_EMAIL"

    echo "Created LimeSurvey admin '$LIMESURVEY_ADMIN_USER'"
fi
