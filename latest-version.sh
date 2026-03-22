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

[ -x "$(type -P xmllint 2>/dev/null)" ] || [ -x "$(type -P python3 2>/dev/null)" ] \
    || { echo "Missing script dependency: xmllint" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

VERSION_REGEX="\([0-9]\+\.[0-9]\+\.[0-9]\++[0-9]\{6\}\)"

_xpath_url() {
    local URL_PREFIX="$1"
    if [ -x "$(type -P xmllint 2>/dev/null)" ]; then
        echo + "xmllint --html --xpath $(quote "//a[starts-with(@href, '$URL_PREFIX')]/@href") -" \
            "| awk 'match(\$0, /^\s*href=\"([^\"]+)\"\s*/, m) { print m[1] }'" >&2
        xmllint --html --xpath "//a[starts-with(@href, '$URL_PREFIX')]/@href" - 2> /dev/null \
            | awk 'match($0, /^\s*href="([^"]+)"\s*/, m) { print m[1] }'
    else
        echo + "python3 -c <PYTHON_XPATH_PROGRAM> $(quote "$URL_PREFIX")" >&2
        python3 -c "$(printf '%s\n' \
            "import sys" \
            "from html.parser import HTMLParser" \
            "HTMLParser.handle_starttag=lambda _, tag, attrs: \\" \
            "    [ print(value) for attr, value in attrs if tag == 'a' and attr == 'href' and value and value.startswith(sys.argv[1]) ]" \
            "HTMLParser().feed(sys.stdin.read())" \
        )" "$URL_PREFIX"
    fi
}

echo + "curl -sSL $(quote "$DOWNLOADS_WEBPAGE_URL")" >&2
DOWNLOADS_WEBPAGE="$(_curl "$DOWNLOADS_WEBPAGE_URL" | sed -e '1,/^$/d')"
[ -n "$DOWNLOADS_WEBPAGE" ] || { echo "Failed to request LimeSurvey downloads webpage: $DOWNLOADS_WEBPAGE_URL" >&2; exit 1; }

ARCHIVE_URL="$(_xpath_url "$(sed -e 's#/[^/]*%s.*$##' <<< "$ARCHIVE_URL_TEMPLATE")" <<< "$DOWNLOADS_WEBPAGE")"
[ -n "$ARCHIVE_URL" ] || { echo "Malformed LimeSurvey downloads webpage: $DOWNLOADS_WEBPAGE_URL" >&2; exit 1; }

ARCHIVE_URL_REGEX="$(printf "$(sed -e 's/[]\/$*.^[]/\\&/g' <<< "$ARCHIVE_URL_TEMPLATE")" "$VERSION_REGEX")"

echo + "sed -ne $(quote "1s/^$ARCHIVE_URL_REGEX$/\1/p")" >&2
VERSION="$(sed -ne "1s/^$ARCHIVE_URL_REGEX$/\1/p" <<< "$ARCHIVE_URL")"
[ -n "$VERSION" ] || { echo "Malformed LimeSurvey archive URL: $ARCHIVE_URL" >&2; exit 1; }

echo "$VERSION"
