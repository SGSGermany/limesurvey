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

[ -x "$(type -P xmllint 2>/dev/null)" ] \
    || { echo "Missing script dependency: xmllint" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

VERSION_REGEX="\([0-9]\+\.[0-9]\+\.[0-9]\++[0-9]\{6\}\)"

echo + "curl -sSL $(quote "$DOWNLOADS_WEBPAGE_URL")" >&2
DOWNLOADS_WEBPAGE="$(_curl "$DOWNLOADS_WEBPAGE_URL" | sed -e '1,/^$/d')"
[ -n "$DOWNLOADS_WEBPAGE" ] || { echo "Failed to request LimeSurvey downloads webpage: $DOWNLOADS_WEBPAGE_URL" >&2; exit 1; }

echo + "xmllint --html --xpath $(quote "//a[starts-with(@href, '${ARCHIVE_URL_TEMPLATE%/*}')]/@href") -" \
    "| awk 'match(\$0, /^\s*href=\"([^\"]+)\"\s*/, m) { print m[1] }'" >&2
ARCHIVE_URL="$(xmllint --html --xpath "//a[starts-with(@href, '${ARCHIVE_URL_TEMPLATE%/*}')]/@href" - 2> /dev/null <<< "$DOWNLOADS_WEBPAGE" \
    | awk 'match($0, /^\s*href="([^"]+)"\s*/, m) { print m[1] }')"
[ -n "$ARCHIVE_URL" ] || { echo "Malformed LimeSurvey downloads webpage: $DOWNLOADS_WEBPAGE_URL" >&2; exit 1; }

ARCHIVE_URL_REGEX="$(printf "$(sed -e 's/[]\/$*.^[]/\\&/g' <<< "$ARCHIVE_URL_TEMPLATE")" "$VERSION_REGEX")"

echo + "sed -ne $(quote "1s/^$ARCHIVE_URL_REGEX$/\1/p")" >&2
VERSION="$(sed -ne "1s/^$ARCHIVE_URL_REGEX$/\1/p" <<< "$ARCHIVE_URL")"
[ -n "$VERSION" ] || { echo "Malformed LimeSurvey archive URL: $ARCHIVE_URL" >&2; exit 1; }

echo "$VERSION"
