<?php
// Compatibility endpoint for tools that request /api/invoice.php?id=1001.
$_GET['route'] = 'api-invoice';
require dirname(__DIR__) . '/index.php';
