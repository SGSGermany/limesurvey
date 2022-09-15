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
export LC_ALL=C

read_secret() {
    local SECRET="/run/secrets/$1"

    [ -e "$SECRET" ] || return 0
    [ -f "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Not a file" >&2; return 1; }
    [ -r "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Permission denied" >&2; return 1; }
    cat "$SECRET" || return 1
}

if [ -f "/etc/limesurvey/security.inc.php" ]; then
    exit
fi

LIMESURVEY_ENCRYPTION_NONCE="$(read_secret "limesurvey_encryption_nonce")"
LIMESURVEY_ENCRYPTION_KEY="$(read_secret "limesurvey_encryption_key")"

if [ -z "$LIMESURVEY_ENCRYPTION_NONCE" ] || [ -z "$LIMESURVEY_ENCRYPTION_KEY" ]; then
    if ! mountpoint -q "/etc/limesurvey" && [ -z "${LIMESURVEY_ENCRYPTION_IGNORE:-}" ]; then
        # we must fail here because LimeSurvey will silently create encryption keys otherwise,
        # so that we might loose access to encrypted survey data as soon as the container is restarted
        echo "Failed to setup LimeSurvey encryption: Unable to persistently store encryption keys" >&2
        exit 1
    fi

    LIMESURVEY_ENCRYPTION_NONCE="$(php -r 'echo sodium_bin2hex(random_bytes(SODIUM_CRYPTO_SECRETBOX_NONCEBYTES));')"
    LIMESURVEY_ENCRYPTION_KEY="$(php -r 'echo sodium_bin2hex(sodium_crypto_secretbox_keygen());')"
fi

{
    printf '<?php\n';
    printf "\$config['encryptionnonce'] = '%s';\n" "$LIMESURVEY_ENCRYPTION_NONCE";
    printf "\$config['encryptionsecretboxkey'] = '%s';\n" "$LIMESURVEY_ENCRYPTION_KEY";
} > "/etc/limesurvey/security.inc.php"
