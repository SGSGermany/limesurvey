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

if [ -e "/var/www/limesurvey_version_info" ]; then
    exit
fi

VERSION="$(sed -ne 's/^VERSION=\(.*\)$/\1/p' /usr/src/limesurvey/version_info)"

# sync LimeSurvey files
echo "Initializing LimeSurvey $VERSION..."
rsync -rlptog --delete --chown www-data:www-data \
    "/usr/src/limesurvey/limesurvey/" \
    "/var/www/html/"

rsync -lptog --chown www-data:www-data \
    "/usr/src/limesurvey/version_info" \
    "/var/www/limesurvey_version_info"

# run install script
/usr/lib/limesurvey/setup/install.sh
