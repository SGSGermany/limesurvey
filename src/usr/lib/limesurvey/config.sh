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

    [ -e "$SECRET" ] || return 0
    [ -f "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Not a file" >&2; return 1; }
    [ -r "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Permission denied" >&2; return 1; }
    cat "$SECRET" || return 1
}

# database config
if [ ! -f "/etc/limesurvey/config.database.inc.php" ]; then
    MYSQL_DATABASE="$(read_secret "limesurvey_mysql_database")"
    MYSQL_USER="$(read_secret "limesurvey_mysql_user")"
    MYSQL_PASSWORD="$(read_secret "limesurvey_mysql_password")"

    if [ -n "$MYSQL_DATABASE" ] || [ -n "$MYSQL_USER" ] || [ -n "$MYSQL_PASSWORD" ]; then
        {
            printf '<?php\n';
            [ -z "$MYSQL_DATABASE" ] || printf "\$databaseConfig['database'] = '%s';\n" "$MYSQL_DATABASE";
            [ -z "$MYSQL_USER" ]     || printf "\$databaseConfig['user'] = '%s';\n" "$MYSQL_USER";
            [ -z "$MYSQL_PASSWORD" ] || printf "\$databaseConfig['password'] = '%s';\n" "$MYSQL_PASSWORD";
        } > "/etc/limesurvey/config.database.inc.php"
    fi
fi

# email config
if [ ! -f "/etc/limesurvey/config.email.inc.php" ]; then
    EMAIL_HOST="$(read_secret "limesurvey_email_host")"
    EMAIL_SSL="$(read_secret "limesurvey_email_ssl")"
    EMAIL_USER="$(read_secret "limesurvey_email_user")"
    EMAIL_PASSWORD="$(read_secret "limesurvey_email_password")"

    if [ -n "$EMAIL_HOST" ]; then
        {
            printf '<?php\n';
            printf "\$emailConfig['method'] = '%s';\n" "smtp";
            printf "\$emailConfig['host'] = '%s';\n" "$EMAIL_HOST";
            [ -z "$EMAIL_SSL" ]      || printf "\$emailConfig['ssl'] = '%s';\n" "$EMAIL_SSL";
            [ -z "$EMAIL_USER" ]     || printf "\$emailConfig['user'] = '%s';\n" "$EMAIL_USER";
            [ -z "$EMAIL_PASSWORD" ] || printf "\$emailConfig['password'] = '%s';\n" "$EMAIL_PASSWORD";
        } > "/etc/limesurvey/config.email.inc.php"
    fi
fi

# site admin config
if [ ! -f "/etc/limesurvey/config.admin.inc.php" ]; then
    ADMIN_NAME="$(read_secret "limesurvey_admin_name")"
    ADMIN_EMAIL="$(read_secret "limesurvey_admin_email")"

    if [ -n "$ADMIN_NAME" ] || [ -n "$ADMIN_EMAIL" ]; then
        {
            printf '<?php\n';
            [ -z "$ADMIN_NAME" ]     || printf "\$adminConfig['name'] = '%s';\n" "$ADMIN_NAME";
            [ -z "$ADMIN_EMAIL" ]    || printf "\$adminConfig['email'] = '%s';\n" "$ADMIN_EMAIL";
        } > "/etc/limesurvey/config.admin.inc.php"
    fi
fi

# session config
if [ ! -f "/etc/limesurvey/config.session.inc.php" ]; then
    SESSION_NAME="$(read_secret "limesurvey_session_name")"

    if [ -z "$SESSION_NAME" ]; then
        SESSION_NAME="LS-$(tr -dc 'A-Z' < /dev/urandom 2> /dev/null | head -c 16 || true)"
    fi

    {
        printf '<?php\n';
        printf "\$sessionConfig['name'] = '%s';\n" "$SESSION_NAME";
    } > "/etc/limesurvey/config.session.inc.php"
fi

# encryption
if [ ! -f "/etc/limesurvey/security.inc.php" ]; then
    ENCRYPTION_NONCE="$(read_secret "limesurvey_encryption_nonce")"
    ENCRYPTION_KEY="$(read_secret "limesurvey_encryption_key")"

    if [ -z "$ENCRYPTION_NONCE" ] || [ -z "$ENCRYPTION_KEY" ]; then
        if ! mountpoint -q "/etc/limesurvey" && [ -z "${ENCRYPTION_IGNORE:-}" ]; then
            # we must fail here because LimeSurvey will silently create encryption keys otherwise,
            # so that we might loose access to encrypted survey data as soon as the container is restarted
            echo "Failed to setup LimeSurvey encryption: Unable to persistently store encryption keys" >&2
            exit 1
        fi

        ENCRYPTION_NONCE="$(php -r 'echo sodium_bin2hex(random_bytes(SODIUM_CRYPTO_SECRETBOX_NONCEBYTES));')"
        ENCRYPTION_KEY="$(php -r 'echo sodium_bin2hex(sodium_crypto_secretbox_keygen());')"
    fi

    {
        printf '<?php\n';
        printf "\$config['encryptionnonce'] = '%s';\n" "$ENCRYPTION_NONCE";
        printf "\$config['encryptionsecretboxkey'] = '%s';\n" "$ENCRYPTION_KEY";
        printf 'return $config;\n';
    } > "/etc/limesurvey/security.inc.php"
fi
