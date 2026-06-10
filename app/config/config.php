<?php
return [
    'db' => [
        'dsn' => getenv('VULNFORGE_DSN') ?: 'mysql:host=localhost;dbname=vulnforge;charset=utf8mb4',
        'user' => getenv('VULNFORGE_DB_USER') ?: 'vulnforge_lab',
        'pass' => getenv('VULNFORGE_DB_PASS') ?: 'lab-only-password',
    ],
    'lab_name' => 'Northstar Outfitters Internal Portal',
    'base_url' => getenv('VULNFORGE_BASE_URL') ?: 'http://127.0.0.1:8080',
    'debug' => true,
];
