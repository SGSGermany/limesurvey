<?php
/**
 * LimeSurvey
 * A php-fpm container running LimeSurvey.
 *
 * Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
 *
 * This work is licensed under the terms of the MIT license.
 * For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
 *
 * SPDX-License-Identifier: MIT
 * License-Filename: LICENSE
 */

$config = [];

// load config.user.inc.php
if (file_exists('/etc/limesurvey/config.user.inc.php')) {
    require('/etc/limesurvey/config.user.inc.php');
}

// database config
$databaseConfig = [];

if (file_exists('/etc/limesurvey/config.database.inc.php')) {
    require('/etc/limesurvey/config.database.inc.php');
}

if (isset($config['components']['db']['connectionString'])) {
    if (isset($databaseConfig['database'])) {
        $databaseConfig['dsn'] = preg_replace(
            '/dbname=([^;]*)/',
            'dbname=' . $databaseConfig['database'],
            $config['components']['db']['connectionString']
        );
    } else {
        $databaseConfig['dsn'] = $config['components']['db']['connectionString'];
    }
} else {
    $databaseConfig['dsn'] = 'mysql:host=localhost;unix_socket=/run/mysql/mysql.sock;'
        . 'dbname=' . ($databaseConfig['database'] ?? 'limesurvey') . ';';
}

$databaseConfig['user'] ??= $config['components']['db']['username'] ?? 'limesurvey';
$databaseConfig['password'] ??= $config['components']['db']['password'] ?? '';

$config['config']['mysqlEngine'] ??= 'MYISAM';
$config['components']['db']['connectionString'] = $databaseConfig['dsn'];
$config['components']['db']['emulatePrepare'] ??= true;
$config['components']['db']['username'] = $databaseConfig['user'];
$config['components']['db']['password'] = $databaseConfig['password'];
$config['components']['db']['charset'] ??= 'utf8mb4';
$config['components']['db']['tablePrefix'] ??= 'lime_';

// email config
$emailConfig = [];

if (file_exists('/etc/limesurvey/config.email.inc.php')) {
    require('/etc/limesurvey/config.email.inc.php');
}

$config['config']['emailmethod'] =
    $emailConfig['method']
    ?? $config['config']['emailmethod']
    ?? null;

$config['config']['emailsmtphost'] =
    $emailConfig['host']
    ?? $config['config']['emailsmtphost']
    ?? '';

$config['config']['emailsmtpssl'] =
    $emailConfig['ssl']
    ?? $config['config']['emailsmtpssl']
    ?? '';

$config['config']['emailsmtpuser'] =
    $emailConfig['user']
    ?? $config['config']['emailsmtpuser']
    ?? '';

$config['config']['emailsmtppassword'] =
    $emailConfig['password']
    ?? $config['config']['emailsmtppassword']
    ?? '';

$config['config']['emailsmtpdebug'] ??= 0;

if ($config['config']['emailmethod'] === null) {
    $config['config']['emailmethod'] = ($config['config']['emailsmtphost'] !== '') ? 'smtp' : 'mail';
}

// site admin config
$adminConfig = [];

if (file_exists('/etc/limesurvey/config.admin.inc.php')) {
    require('/etc/limesurvey/config.admin.inc.php');
}

$config['config']['siteadminname'] =
    $adminConfig['admin_name']
    ?? $config['config']['siteadminname']
    ?? 'LimeSurvey Administrator';

$config['config']['siteadminemail'] =
    $adminConfig['admin_email']
    ?? $config['config']['siteadminemail']
    ?? 'admin@example.com';

$config['config']['siteadminbounce'] ??= $config['config']['siteadminemail'];

// session config
$sessionConfig = [];

if (file_exists('/etc/limesurvey/config.session.inc.php')) {
    require('/etc/limesurvey/config.session.inc.php');
}

if (!isset($sessionConfig['name'])) {
    if (isset($config['components']['session']['sessionName'])) {
        $sessionConfig['name'] = $config['components']['session']['sessionName'];
    } else {
        $sessionConfig['name'] = 'LS-';
        for ($i = 0; $i < 16; $i++) {
            // append 16 random ASCII chars matching uppercase A to Z
            $sessionConfig['name'] .= chr(random_int(65, 90));
        }
    }
}

$config['components']['session']['sessionName'] = $sessionConfig['name'];
$config['components']['session']['cookieParams']['secure'] ??= true;
$config['components']['session']['cookieParams']['httponly'] ??= true;

// logging
if (!isset($config['components']['log'])) {
    $config['components']['log'] = [
        'routes' => [
            'fileError' => [
                'class' => 'CFileLogRoute',
                'levels' => 'warning, error',
                'except' => 'exception.CHttpException.404',
            ],
        ],
    ];
}

// URL manager config
if (!isset($config['components']['urlManager'])) {
    $config['components']['urlManager'] = [
        'urlFormat' => 'path',
        'rules' => [],
        'showScriptName' => true,
    ];
}

// misc settings
$config['config']['updatable'] ??= false;
$config['config']['debug'] ??= 0;
$config['config']['debugsql'] ??= 0;
$config['config']['force_ssl'] ??= 'on';

return $config;
