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

set -e

[ $# -gt 0 ] || set -- php-fpm "$@"
if [ "$1" == "php-fpm" ]; then
    if [ ! -f "/etc/limesurvey/config.database.inc.php" ]; then
        if
            [ -f "/run/secrets/limesurvey_mysql_database" ] \
            || [ -f "/run/secrets/limesurvey_mysql_user" ] \
            || [ -f "/run/secrets/limesurvey_mysql_password" ]
        then
            {
                printf '<?php\n';
                [ ! -f "/run/secrets/limesurvey_mysql_database" ] \
                    || printf "\$databaseConfig['database'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_mysql_database")";
                [ ! -f "/run/secrets/limesurvey_mysql_user" ] \
                    || printf "\$databaseConfig['user'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_mysql_user")";
                [ ! -f "/run/secrets/limesurvey_mysql_password" ] \
                    || printf "\$databaseConfig['password'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_mysql_password")";
            } > "/etc/limesurvey/config.database.inc.php"
        fi
    fi

    if [ ! -f "/etc/limesurvey/config.email.inc.php" ]; then
        if
            [ -f "/run/secrets/limesurvey_email_host" ] \
            || [ -f "/run/secrets/limesurvey_email_ssl" ] \
            || [ -f "/run/secrets/limesurvey_email_user" ] \
            || [ -f "/run/secrets/limesurvey_email_password" ] \
            || [ -f "/run/secrets/limesurvey_admin_name" ] \
            || [ -f "/run/secrets/limesurvey_admin_email" ]
        then
            {
                printf '<?php\n';
                [ ! -f "/run/secrets/limesurvey_email_host" ] \
                    || printf "\$emailConfig['method'] = '%s';\n" \
                        "smtp";
                [ ! -f "/run/secrets/limesurvey_email_host" ] \
                    || printf "\$emailConfig['host'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_email_host")";
                [ ! -f "/run/secrets/limesurvey_email_ssl" ] \
                    || printf "\$emailConfig['ssl'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_email_ssl")";
                [ ! -f "/run/secrets/limesurvey_email_user" ] \
                    || printf "\$emailConfig['user'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_email_user")";
                [ ! -f "/run/secrets/limesurvey_email_password" ] \
                    || printf "\$emailConfig['password'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_email_password")";
                [ ! -f "/run/secrets/limesurvey_admin_name" ] \
                    || printf "\$emailConfig['admin_name'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_admin_name")";
                [ ! -f "/run/secrets/limesurvey_admin_email" ] \
                    || printf "\$emailConfig['admin_email'] = '%s';\n" \
                        "$(cat "/run/secrets/limesurvey_admin_email")";
            } > "/etc/limesurvey/config.email.inc.php"
        fi
    fi

    if [ ! -f "/etc/limesurvey/config.session.inc.php" ]; then
        [ -f "/run/secrets/limesurvey_session_name" ] \
            && LIMESURVEY_SESSION_NAME="$(cat "/run/secrets/limesurvey_session_name")" \
            || LIMESURVEY_SESSION_NAME="LS-$(LC_ALL=C tr -dc 'A-Z' < /dev/urandom 2> /dev/null | head -c 16 || true)"

        {
            printf '<?php\n';
            printf "\$sessionConfig['name'] = '%s';\n" "$LIMESURVEY_SESSION_NAME";
        } > "/etc/limesurvey/config.session.inc.php"
    fi

    # setup encryption, if necessary
    /usr/lib/limesurvey/setup-encryption.sh

    # setup LimeSurvey, if necessary
    /usr/lib/limesurvey/setup.sh

    exec "$@"
fi

exec "$@"
