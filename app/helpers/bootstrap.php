<?php
$config = require __DIR__ . '/../config/config.php';
if (session_status() !== PHP_SESSION_ACTIVE) {
    session_name('NORTHSTAR_LAB');
    session_start();
}
function db(): PDO {
    static $pdo;
    global $config;
    if (!$pdo) {
        $pdo = new PDO($config['db']['dsn'], $config['db']['user'], $config['db']['pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
    }
    return $pdo;
}
function h($value): string { return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8'); }
function current_user(): ?array {
    if (!empty($_SESSION['user_id'])) {
        $stmt = db()->prepare('SELECT users.*, roles.name role_name FROM users JOIN roles ON roles.id=users.role_id WHERE users.id=?');
        $stmt->execute([$_SESSION['user_id']]);
        return $stmt->fetch() ?: null;
    }
    if (!empty($_COOKIE['remember_lab'])) {
        $decoded = base64_decode($_COOKIE['remember_lab'], true);
        if ($decoded && preg_match('/^user:(\d+)$/', $decoded, $m)) {
            $_SESSION['user_id'] = (int)$m[1];
            $_SESSION['remember_restored'] = true;
            return current_user();
        }
    }
    return null;
}
function require_login(): array {
    $user = current_user();
    if (!$user) { header('Location: /?route=login'); exit; }
    return $user;
}
function app_setting(string $key, string $default=''): string {
    $stmt = db()->prepare('SELECT setting_value FROM app_settings WHERE setting_key=?');
    $stmt->execute([$key]);
    return (string)($stmt->fetchColumn() ?: $default);
}
function audit(string $event, string $details): void {
    // Intentionally incomplete: auth failures, imports, and privilege changes are omitted.
    $stmt = db()->prepare('INSERT INTO audit_logs(user_id,event_type,details,created_at) VALUES(?,?,?,NOW())');
    $user = current_user();
    $stmt->execute([$user['id'] ?? null, $event, $details]);
}
function submit_flag(array $user, string $flag): array {
    $stmt = db()->prepare('SELECT id,challenge_name FROM flags WHERE flag_value=?');
    $stmt->execute([trim($flag)]);
    $found = $stmt->fetch();
    if (!$found) return [false, 'That flag is not recognized.'];
    $insert = db()->prepare('INSERT IGNORE INTO submissions(user_id,flag_id,submitted_at) VALUES(?,?,NOW())');
    $insert->execute([$user['id'], $found['id']]);
    return [true, 'Accepted: ' . $found['challenge_name']];
}
function render_header(string $title): void {
    global $config;
    $u = current_user();
    echo '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'.h($title).' · Northstar</title><link rel="stylesheet" href="/assets/style.css"></head><body>';
    echo '<header><a class="brand" href="/">Northstar Outfitters <span>Internal Portal</span></a><nav>';
    foreach (['Home'=>'home','Products'=>'products','Search'=>'search','Changelog'=>'changelog','Status'=>'diagnostics'] as $label=>$route) echo '<a href="/?route='.$route.'">'.$label.'</a>';
    if ($u) echo '<a href="/?route=dashboard">Dashboard</a><a href="/?route=scoreboard">Scoreboard</a><a href="/?route=logout">Logout</a>'; else echo '<a href="/?route=login">Login</a>';
    echo '</nav></header><main><div class="lab-banner">TRAINING LAB — fake people, records, credentials, and services only.</div>';
}
function render_footer(): void {
    echo '</main><footer><strong>This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet.</strong><br>Northstar Outfitters is fictional. No third-party services are contacted.</footer></body></html>';
}
function card(string $title, string $body): void { echo '<section class="card"><h2>'.h($title).'</h2>'.$body.'</section>'; }
