<?php
$runtimePath = __DIR__ . '/runtime.php';
$runtime = is_readable($runtimePath) ? require $runtimePath : [];
$dbName = getenv('VULNFORGE_DB_NAME') ?: ($runtime['db_name'] ?? 'vulnforge');
$dbUser = getenv('VULNFORGE_DB_USER') ?: ($runtime['db_user'] ?? 'vulnforge_lab');
$dbPass = getenv('VULNFORGE_DB_PASS') ?: ($runtime['db_pass'] ?? 'lab-only-password');

return [
    'db' => [
        'dsn' => getenv('VULNFORGE_DSN') ?: 'mysql:host=localhost;dbname=' . $dbName . ';charset=utf8mb4',
        'user' => $dbUser,
        'pass' => $dbPass,
    ],
    'lab_name' => 'Northstar Outfitters Internal Portal',
    'base_url' => getenv('VULNFORGE_BASE_URL') ?: 'http://127.0.0.1:8080',
    'debug' => true,
];
