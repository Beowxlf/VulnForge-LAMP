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

function request_id(): string {
    static $requestId;
    if ($requestId === null) {
        $provided = (string)($_SERVER['HTTP_X_REQUEST_ID'] ?? '');
        $requestId = preg_match('/^[A-Za-z0-9._-]{8,80}$/', $provided)
            ? $provided
            : bin2hex(random_bytes(12));
        if (PHP_SAPI !== 'cli' && !headers_sent()) header('X-Request-ID: '.$requestId);
    }
    return $requestId;
}
function telemetry_text(string $value, int $limit=240): string {
    $value = preg_replace('/[\x00-\x1F\x7F]/u', ' ', $value) ?? '';
    return function_exists('mb_substr') ? mb_substr($value, 0, $limit) : substr($value, 0, $limit);
}
function telemetry_user(?array $user=null): ?array {
    if ($user) return $user;
    if (empty($_SESSION['user_id'])) return null;
    try {
        $stmt = db()->prepare('SELECT users.id,users.email,roles.name role_name FROM users JOIN roles ON roles.id=users.role_id WHERE users.id=?');
        $stmt->execute([$_SESSION['user_id']]);
        return $stmt->fetch() ?: null;
    } catch (Throwable $e) {
        return null;
    }
}
function app_event(string $eventType, string $eventCategory, string $outcome, string $message, array $context=[]): void {
    $user = telemetry_user($context['user'] ?? null);
    $event = [
        'timestamp' => gmdate('c'),
        'app' => 'northstar-vulnforge',
        'environment' => 'training',
        'host' => gethostname() ?: 'unknown',
        'request_id' => request_id(),
        'src_ip' => telemetry_text((string)($_SERVER['REMOTE_ADDR'] ?? 'unknown'), 64),
        'user_agent' => telemetry_text((string)($_SERVER['HTTP_USER_AGENT'] ?? 'unknown'), 300),
        'method' => telemetry_text((string)($_SERVER['REQUEST_METHOD'] ?? 'CLI'), 16),
        'route' => telemetry_text((string)($context['route'] ?? ($_GET['route'] ?? 'home')), 120),
        'http_status' => (int)($context['http_status'] ?? (http_response_code() ?: 200)),
        'username' => $user['email'] ?? null,
        'user_id' => isset($user['id']) ? (int)$user['id'] : null,
        'role' => $user['role_name'] ?? null,
        'event_type' => $eventType,
        'event_category' => $eventCategory,
        'owasp_category' => $context['owasp_category'] ?? null,
        'challenge_id' => $context['challenge_id'] ?? null,
        'outcome' => $outcome,
        'message' => telemetry_text($message),
    ];
    $line = json_encode($event, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if ($line === false) return;
    $path = getenv('VULNFORGE_EVENT_LOG') ?: '/var/log/vulnforge/app_events.jsonl';
    @file_put_contents($path, $line.PHP_EOL, FILE_APPEND | LOCK_EX);
}
function suspicious_parameter_pattern(string $value): ?string {
    if (preg_match('/(?:\bunion\b\s+\bselect\b|\bor\b\s+[\'\"]?\d+[\'\"]?\s*=|--|\/\*)/i', $value)) return 'sql_metacharacter_sequence';
    if (preg_match('/<\s*script\b|javascript\s*:/i', $value)) return 'script_markup_sequence';
    if (preg_match('/(?:\.\.\/|\.\.\\\\)/', $value)) return 'path_traversal_sequence';
    return null;
}
function log_suspicious_parameter(string $parameter, string $value, string $route, ?array $user=null): ?string {
    $pattern = suspicious_parameter_pattern($value);
    if ($pattern !== null) {
        app_event('suspicious_parameter_pattern', 'input_validation', 'observed', 'Suspicious parameter metadata: parameter='.$parameter.' pattern='.$pattern.' length='.strlen($value), [
            'route' => $route,
            'user' => $user,
            'owasp_category' => 'A05',
        ]);
    }
    return $pattern;
}
function register_telemetry_shutdown(): void {
    register_shutdown_function(function (): void {
        $error = error_get_last();
        if (!$error || !in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR], true)) return;
        app_event('application_exception', 'application', 'error', 'Fatal application exception type='.$error['type'], [
            'http_status' => http_response_code() >= 400 ? http_response_code() : 500,
            'owasp_category' => 'A10',
        ]);
    });
}
request_id();
register_telemetry_shutdown();
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
    if (!$found) {
        app_event('flag_submission_failure', 'training', 'failure', 'Flag submission was not recognized; raw submitted value omitted.', ['user'=>$user]);
        return [false, 'That flag is not recognized.'];
    }
    $insert = db()->prepare('INSERT IGNORE INTO submissions(user_id,flag_id,submitted_at) VALUES(?,?,NOW())');
    $insert->execute([$user['id'], $found['id']]);
    app_event('flag_submission_success', 'training', 'success', 'Flag submission accepted.', ['user'=>$user, 'challenge_id'=>(int)$found['id']]);
    return [true, 'Accepted: ' . $found['challenge_name']];
}
function nav_link(string $label, string $route, string $current): string {
    $active = $route === $current ? ' class="active" aria-current="page"' : '';
    return '<a'.$active.' href="/?route='.h($route).'">'.h($label).'</a>';
}
function status_badge(string $status): string {
    $normalized = strtolower(trim($status));
    $class = 'neutral';
    if (in_array($normalized, ['paid', 'resolved', 'active', 'complete', 'discovered', 'reachable'], true)) $class = 'success';
    elseif (in_array($normalized, ['open', 'pending', 'processing', 'in review'], true)) $class = 'warning';
    elseif (in_array($normalized, ['failed', 'overdue', 'restricted', 'disabled'], true)) $class = 'danger';
    return '<span class="status status-'.$class.'">'.h(ucwords($status)).'</span>';
}
function page_header(string $title, string $eyebrow, string $description=''): void {
    echo '<div class="page-header"><div><p class="eyebrow">'.h($eyebrow).'</p><h1>'.h($title).'</h1>';
    if ($description !== '') echo '<p class="page-description">'.h($description).'</p>';
    echo '</div></div>';
}
function empty_table_row(int $columns, string $title, string $message): string {
    return '<tr><td colspan="'.$columns.'"><div class="empty-state"><strong>'.h($title).'</strong><span>'.h($message).'</span></div></td></tr>';
}
function render_header(string $title): void {
    $u = current_user();
    $route = $_GET['route'] ?? 'home';
    echo '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#12324a"><title>'.h($title).' · Northstar Outfitters</title><link rel="icon" href="/assets/img/northstar-mark.svg" type="image/svg+xml"><link rel="stylesheet" href="/assets/css/main.css"><script defer src="/assets/js/main.js"></script></head><body>';
    echo '<a class="skip-link" href="#main-content">Skip to content</a><header class="site-header"><div class="header-inner"><a class="brand" href="/?route=home"><img src="/assets/img/northstar-mark.svg" alt="" width="40" height="40"><span><strong>Northstar Outfitters</strong><small>Internal Operations Portal</small></span></a><button class="nav-toggle" type="button" aria-expanded="false" aria-controls="primary-nav"><span class="sr-only">Toggle navigation</span><span></span><span></span><span></span></button><nav class="primary-nav" id="primary-nav" aria-label="Primary navigation">';
    foreach (['Home'=>'home','Catalog'=>'products','Portal Search'=>'search','System Status'=>'diagnostics'] as $label=>$navRoute) echo nav_link($label, $navRoute, $route);
    if ($u) {
        echo nav_link('Dashboard', 'dashboard', $route).nav_link('Scoreboard', 'scoreboard', $route);
        echo '<a class="signout" href="/?route=logout">Sign out</a>';
    } else echo nav_link('Employee Sign In', 'login', $route);
    echo '</nav></div></header>';
    if ($u) {
        echo '<div class="utility-bar"><div class="utility-inner"><nav class="workspace-nav" aria-label="Employee workspace">';
        foreach (['Overview'=>'dashboard','Invoices'=>'invoices','Support'=>'support','Profile'=>'profile','File Exchange'=>'uploads','Admin Console'=>'admin','Audit Viewer'=>'logs'] as $label=>$navRoute) echo nav_link($label, $navRoute, $route);
        echo '</nav><div class="user-chip"><span class="avatar">'.h(strtoupper(substr($u['display_name'], 0, 1))).'</span><span><strong>'.h($u['display_name']).'</strong><small>'.h(ucwords($u['role_name'])).' · Northstar Staff</small></span></div></div></div>';
    }
    echo '<main id="main-content"><div class="lab-banner" role="note"><span class="lab-icon">!</span><div><strong>Private training environment</strong><span>TRAINING LAB — fake people, records, credentials, and services only. Keep this portal on an isolated lab network.</span></div></div>';
}
function render_footer(): void {
    echo '</main><footer class="site-footer"><div class="footer-inner"><div><a class="footer-brand" href="/?route=home">Northstar Outfitters</a><p>Outdoor equipment, logistics, and retail support · Fictional training organization</p></div><div class="footer-links"><a href="/?route=changelog">Release notes</a><a href="/?route=diagnostics">System status</a><a href="/?route=scoreboard">Training progress</a></div></div><div class="safety-footer"><strong>This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet.</strong><span>Northstar Outfitters is fictional. No third-party services are contacted. © <span data-current-year>2026</span> Northstar Training Lab.</span></div></footer></body></html>';
}
function card(string $title, string $body, string $class=''): void { echo '<section class="card '.h($class).'"><h2>'.h($title).'</h2>'.$body.'</section>'; }
