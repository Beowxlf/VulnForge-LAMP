<?php
require __DIR__ . '/../app/helpers/bootstrap.php';
require __DIR__ . '/../app/vendor/fake-vendor/unsafe-helper/Helper.php';
use FakeVendor\UnsafeHelper\Helper;

$route = $_GET['route'] ?? 'home';
if ($route === 'logout') { session_destroy(); setcookie('remember_lab','',time()-3600,'/'); header('Location: /'); exit; }

if ($route === 'api-invoice') {
    header('Content-Type: application/json');
    if (!isset($_GET['id'])) {
        http_response_code(500);
        echo json_encode(['error'=>'MissingArgumentException: invoice id required','file'=>'/var/www/vulnforge/public/index.php','line'=>214,'debug'=>app_setting('api_exception_marker')], JSON_PRETTY_PRINT);
        exit;
    }
    $stmt=db()->prepare('SELECT id,invoice_number,item_summary,amount,payment_status,private_note FROM invoices WHERE id=?');
    $stmt->execute([$_GET['id']]); echo json_encode($stmt->fetch() ?: ['error'=>'not found'], JSON_PRETTY_PRINT); exit;
}

render_header(ucwords(str_replace('-', ' ', $route)));

switch ($route) {
case 'home':
    echo '<section class="hero"><p class="pill">Fictional internal commerce portal</p><h1>Gear operations, without the paperwork avalanche.</h1><p>Northstar staff use this private portal to review products, invoices, support requests, and account settings.</p><a class="button" href="/?route=login">Enter training portal</a></section>';
    echo '<div class="grid">';
    card('Product operations','Browse the fictional outdoor catalog and inventory notes.');
    card('Customer support','Track fake employee and wholesale support cases.');
    card('Security lab','Find and submit 20 OWASP-aligned challenge flags.<!-- FLAG LOCATIONS VARY: comments, records, files, metadata, APIs, logs, and debug output. -->');
    echo '</div>';
    break;
case 'login':
    $message='';
    if ($_SERVER['REQUEST_METHOD']==='POST') {
        $stmt=db()->prepare('SELECT * FROM users WHERE email=?'); $stmt->execute([$_POST['email'] ?? '']); $row=$stmt->fetch();
        if ($row && md5($_POST['password'] ?? '') === $row['password_hash']) {
            $_SESSION['user_id']=$row['id'];
            if (!empty($_POST['remember'])) setcookie('remember_lab',base64_encode('user:'.$row['id']),time()+86400*30,'/');
            // Authentication is intentionally not audited.
            header('Location: /?route=dashboard'); exit;
        }
        $message='<div class="error">Login failed. Detailed failures are intentionally not recorded.</div>';
    }
    echo '<section class="card"><h1>Employee sign in</h1>'.$message.'<form method="post"><label>Email</label><input name="email" type="email" required><label>Password</label><input name="password" type="password" required><label><input style="width:auto" type="checkbox" name="remember" value="1"> Remember this lab browser</label><button>Sign in</button></form><p class="muted">Authorized local training accounts only. Credentials are fake and listed in the player guide.</p></section>';
    break;
case 'dashboard':
    $u=require_login();
    echo '<h1>Welcome, '.h($u['display_name']).'</h1><p>Role: <span class="pill">'.h($u['role_name']).'</span></p><div class="grid">';
    card('Invoices','<a class="button" href="/?route=invoices">View invoices</a>');
    card('Support','<a class="button" href="/?route=support">Open ticket queue</a>');
    card('Profile','<a class="button" href="/?route=profile">Manage profile</a>');
    card('Uploads','<a class="button" href="/?route=uploads">File exchange</a>');
    if ($u['email']==='admin@northstar.local') card('Factory setup complete','The default administrator marker is <span class="flag">FLAG{A07_DEFAULT_ADMIN_01}</span>.');
    if (!empty($_SESSION['remember_restored'])) card('Remembered session restored','Unsigned token accepted. Review marker: <span class="flag">'.h(app_setting('remember_marker')).'</span>.');
    echo '</div>';
    break;
case 'products':
    $q=$_GET['q'] ?? '';
    if ($q !== '') {
        // Deliberate SQL injection challenge: local fake catalog only.
        $sql="SELECT id,sku,name,description,price,internal_note FROM products WHERE name LIKE '%$q%' OR description LIKE '%$q%'";
        try { $products=db()->query($sql)->fetchAll(); } catch(Throwable $e) { $products=[]; echo '<div class="error">Catalog query error: '.h($e->getMessage()).'</div>'; }
    } else $products=db()->query('SELECT id,sku,name,description,price,NULL internal_note FROM products')->fetchAll();
    echo '<h1>Product catalog</h1><form><input type="hidden" name="route" value="products"><label>Catalog search</label><input name="q" value="'.h($q).'" placeholder="lantern"><button>Search</button></form><section class="card"><table><tr><th>SKU</th><th>Product</th><th>Price</th><th>Details</th></tr>';
    foreach($products as $p) echo '<tr><td>'.h($p['sku']).'</td><td>'.h($p['name']).'<br><span class="muted">'.h($p['description']).'</span>'.($p['internal_note']?'<br><code>'.h($p['internal_note']).'</code>':'').'</td><td>$'.h($p['price']).'</td><td><a href="/?route=product&id='.h($p['id']).'">Open</a></td></tr>';
    echo '</table></section>';
    break;
case 'product':
    $id=$_GET['id'] ?? '';
    if (!ctype_digit((string)$id)) {
        echo '<h1>Product service exception</h1><div class="error">InvalidArgumentException: product identifier must be an integer\n at CatalogRepository->find('.h($id).')\n at /var/www/vulnforge/app/controllers/ProductController.php:47\n debug_marker='.h(app_setting('exception_marker')).'</div>';
    } else {
        $stmt=db()->prepare('SELECT * FROM products WHERE id=?');$stmt->execute([$id]);$p=$stmt->fetch();
        card($p['name'] ?? 'Not found',$p?'<p>'.h($p['description']).'</p><strong>$'.h($p['price']).'</strong>':'No fictional product matches.');
    }
    break;
case 'search':
    $term=$_GET['term'] ?? '';
    echo '<h1>Portal search</h1><form><input type="hidden" name="route" value="search"><label>Search public portal text</label><input name="term" value="'.h($term).'"><button>Search</button></form>';
    if($term!=='') echo Helper::renderGreeting($term).'<p class="muted">Result generated by fake-vendor/unsafe-helper 0.8.1.</p>';
    break;
case 'vendor-demo':
    echo '<h1>Dependency support console</h1><p>Installed: fake-vendor/unsafe-helper 0.8.1 (fictional).</p>';
    if(($_GET['debug'] ?? '')==='1') echo '<pre>'.h(Helper::debugBanner()).'</pre>'; else echo '<a class="button" href="/?route=vendor-demo&debug=1">Enable verbose vendor banner</a>';
    break;
case 'invoices':
    $u=require_login();
    $stmt=db()->prepare('SELECT id,invoice_number,item_summary,amount,payment_status FROM invoices WHERE user_id=?');$stmt->execute([$u['id']]);
    echo '<h1>My invoices</h1><section class="card"><table><tr><th>Number</th><th>Summary</th><th>Amount</th></tr>';
    foreach($stmt as $i) echo '<tr><td><a href="/?route=invoice&id='.$i['id'].'">'.h($i['invoice_number']).'</a></td><td>'.h($i['item_summary']).'</td><td>$'.h($i['amount']).'</td></tr>'; echo '</table></section>';
    break;
case 'invoice':
    require_login(); $stmt=db()->prepare('SELECT invoices.*,users.display_name FROM invoices JOIN users ON users.id=invoices.user_id WHERE invoices.id=?');$stmt->execute([$_GET['id']??0]);$i=$stmt->fetch();
    if($i){ audit('invoice.view','invoice='.$i['id']); card('Invoice '.$i['invoice_number'],'<p>Customer: '.h($i['display_name']).'</p><p>'.h($i['item_summary']).'</p><p>Total: $'.h($i['amount']).'</p><p>Status: '.h($i['payment_status']).'</p><p class="notice">'.h($i['private_note']).'</p>'); } else card('Invoice not found','No record.');
    break;
case 'support':
    $u=require_login(); $stmt=db()->prepare('SELECT id,subject,status,admin_only FROM support_tickets WHERE user_id=? AND admin_only=0');$stmt->execute([$u['id']]);
    echo '<h1>Support queue</h1><section class="card"><table><tr><th>ID</th><th>Subject</th><th>Status</th></tr>';
    foreach($stmt as $t) echo '<tr><td><a href="/?route=ticket&id='.$t['id'].'">'.$t['id'].'</a></td><td>'.h($t['subject']).'</td><td>'.h($t['status']).'</td></tr>';echo '</table></section>';
    break;
case 'ticket':
    $u=require_login(); $stmt=db()->prepare('SELECT * FROM support_tickets WHERE id=?');$stmt->execute([$_GET['id']??0]);$t=$stmt->fetch();
    $allowed=$t && ($t['user_id']==$u['id'] || $u['role_name']==='admin' || ($_GET['preview']??'')==='admin');
    if(!$allowed) echo '<div class="error">Ticket is restricted.</div>'; else card('Ticket #'.$t['id'].' — '.$t['subject'],'<p>'.h($t['body']).'</p><p>Status: '.h($t['status']).'</p><p class="notice">Internal: '.h($t['internal_note']).'</p>');
    break;
case 'profile':
    $u=require_login();
    if($_SERVER['REQUEST_METHOD']==='POST' && isset($_POST['bio'])) { $stmt=db()->prepare('UPDATE users SET profile_bio=? WHERE id=?');$stmt->execute([$_POST['bio'],$u['id']]);header('Location: /?route=profile');exit; }
    echo '<h1>Profile</h1><div class="grid"><section class="card"><form method="post"><label>Display name</label><input disabled value="'.h($u['display_name']).'"><label>Biography</label><textarea name="bio">'.h($u['profile_bio']).'</textarea><button>Save</button></form></section><section class="card"><h2>Private note export</h2><p>Legacy reversible format:</p><code>'.h($u['encoded_private_note']).'</code><p class="muted">hash_scheme='.h($u['hash_scheme']).'</p><a class="button secondary" href="/?route=profile-import">Import profile JSON</a></section></div>';
    break;
case 'profile-import':
    $u=require_login();$result='';
    if($_SERVER['REQUEST_METHOD']==='POST') {
        $data=json_decode($_POST['profile_json']??'',true);
        if(is_array($data)) { $_SESSION['imported_role']=$data['role']??$u['role_name']; $result='<div class="notice">Unsigned profile accepted. Effective imported role: '.h($_SESSION['imported_role']).'</div>'; if(($_SESSION['imported_role'])==='admin') $result.='<p class="flag">'.h(app_setting('import_review_marker')).'</p>'; }
        else $result='<div class="error">Invalid JSON</div>';
    }
    echo '<section class="card"><h1>Profile import</h1>'.$result.'<p>Restore a profile document exported by this fictional portal.</p><form method="post"><label>Profile JSON</label><textarea name="profile_json">{"display_name":"Guest Player","role":"guest"}</textarea><button>Import without signature</button></form></section>';
    break;
case 'admin':
    $u=require_login();$effective=$_SESSION['imported_role']??$u['role_name'];
    if($effective!=='admin' && ($_GET['admin']??'')!=='1') echo '<div class="error">Administrator role required.</div>';
    else { echo '<h1>Administration</h1><p>Effective role: '.h($effective).'</p>'; card('Portal settings','Debug mode: enabled<br>Training marker: '.h(app_setting('import_review_marker'))); }
    break;
case 'uploads':
    require_login();$msg='';
    if($_SERVER['REQUEST_METHOD']==='POST' && isset($_FILES['lab_file']) && $_FILES['lab_file']['error']===UPLOAD_ERR_OK) {
        $name=basename($_FILES['lab_file']['name']); move_uploaded_file($_FILES['lab_file']['tmp_name'],__DIR__.'/../uploads/'.$name);$msg='<div class="notice">Uploaded as '.h($name).'. Server-side execution is disabled in the Apache alias.</div>';
    }
    echo '<section class="card"><h1>File exchange</h1>'.$msg.'<form method="post" enctype="multipart/form-data"><label>Fake lab document</label><input type="file" name="lab_file" required><button>Upload</button></form><p><a href="/uploads/">Browse shared uploads</a></p></section>';
    break;
case 'diagnostics':
    echo '<h1>System status</h1><div class="grid">';card('Portal','Version '.h(app_setting('portal_version')).'<br>Database: reachable<br>Mail: disabled');card('Lab boundary','Bind: 127.0.0.1:8080<br>Region: '.h(app_setting('diagnostic_region')));echo '</div>';
    if(($_GET['detail']??'')==='1') echo '<pre>APP_ENV=training\nAPP_DEBUG=true\nDB_HOST=localhost\nDOCUMENT_ROOT=/var/www/vulnforge/public\n'.h(app_setting('debug_marker')).'</pre>'; else echo '<a class="button" href="/?route=diagnostics&detail=1">Detailed status</a>';
    break;
case 'command-console':
    $input=$_GET['check']??'status';$out=[];
    // Intentionally injectable command grammar, but no OS shell is called. Only these fixed fake-data operations exist.
    foreach(preg_split('/\s*;\s*/',$input) as $cmd){ if($cmd==='status')$out[]='orders: ok';elseif($cmd==='count')$out[]='fake records: 4';elseif($cmd==='show marker')$out[]=app_setting('command_marker');else $out[]='unknown simulated command: '.$cmd; }
    echo '<section class="card"><h1>Warehouse command console</h1><p class="notice">Safety boundary: this interpreter never invokes the operating-system shell and can only read fixed fake lab values.</p><form><input type="hidden" name="route" value="command-console"><label>Health operation</label><input name="check" value="'.h($input).'"><button>Run</button></form><pre>'.h(implode("\n",$out)).'</pre></section>';
    break;
case 'refund':
    $result='';if($_SERVER['REQUEST_METHOD']==='POST'){$qty=(int)($_POST['quantity']??0);$code=$_POST['coupon']??'';$stmt=db()->prepare('SELECT * FROM coupons WHERE code=?');$stmt->execute([$code]);$c=$stmt->fetch();if($c){$refund=20*$qty*(1+$c['percent_off']/100);$result='<div class="notice">Calculated fictional refund: $'.h(number_format($refund,2)).'</div>';if($qty<0)$result.='<p class="flag">'.h($c['internal_note']).'</p>';}}
    echo '<section class="card"><h1>Refund estimator</h1>'.$result.'<form method="post"><label>Quantity returned</label><input type="number" name="quantity" value="1"><label>Coupon</label><input name="coupon" value="WELCOME10"><button>Estimate</button></form></section>';
    break;
case 'password-reset':
    $result=''; if($_SERVER['REQUEST_METHOD']==='POST'){$stmt=db()->prepare('SELECT password_resets.*,users.email FROM password_resets JOIN users ON users.id=password_resets.user_id WHERE token=?');$stmt->execute([$_POST['token']??'']);$r=$stmt->fetch();if($r)$result='<div class="notice">Token accepted for '.h($r['email']).'. Training marker: '.h(app_setting('reset_marker')).'</div>';else$result='<div class="error">Unknown token.</div>';}
    echo '<section class="card"><h1>Password reset verification</h1>'.$result.'<p>No email is sent; this lab contacts no third parties.</p><form method="post"><label>Reset token</label><input name="token" placeholder="reset-userid-year"><button>Verify</button></form></section>';
    break;
case 'logs':
    $u=require_login();echo '<h1>Audit log viewer</h1><p class="notice">This viewer omits failed authentication, profile imports, and effective-role changes.</p><section class="card"><table><tr><th>Time</th><th>Event</th><th>Details</th></tr>';
    foreach(db()->query('SELECT * FROM audit_logs ORDER BY created_at DESC') as $l)echo '<tr><td>'.h($l['created_at']).'</td><td>'.h($l['event_type']).'</td><td>'.h($l['details']).'</td></tr>';echo '</table></section>';
    if(($_GET['compare']??'')==='1')echo '<p class="flag">'.h(app_setting('logging_gap_marker')).'</p>';else echo '<a class="button" href="/?route=logs&compare=1">Compare expected security events</a>';
    break;
case 'scoreboard':
    $u=require_login();$message='';if($_SERVER['REQUEST_METHOD']==='POST') {[$ok,$text]=submit_flag($u,$_POST['flag']??'');$message='<div class="'.($ok?'notice':'error').'">'.h($text).'</div>';}
    $total=(int)db()->query('SELECT COUNT(*) FROM flags')->fetchColumn();$stmt=db()->prepare('SELECT COUNT(*) FROM submissions WHERE user_id=?');$stmt->execute([$u['id']]);$solved=(int)$stmt->fetchColumn();$pct=$total?(int)(100*$solved/$total):0;
    echo '<h1>Challenge scoreboard</h1>'.$message.'<section class="card"><h2>'.h($solved).' / '.h($total).' flags discovered</h2><div class="progress"><span style="width:'.$pct.'%"></span></div><form method="post"><label>Submit a flag</label><input name="flag" placeholder="FLAG{CATEGORY_DESCRIPTION_01}" required><button>Submit</button></form></section><section class="card"><table><tr><th>Category</th><th>Challenge</th><th>Difficulty</th><th>Status</th></tr>';
    $stmt=db()->prepare('SELECT flags.*,submissions.id solved FROM flags LEFT JOIN submissions ON submissions.flag_id=flags.id AND submissions.user_id=? ORDER BY flags.category,flags.id');$stmt->execute([$u['id']]);foreach($stmt as $f)echo '<tr><td>'.h($f['category']).'</td><td>'.h($f['challenge_name']).'</td><td>'.h($f['difficulty']).'</td><td>'.($f['solved']?'✓ Discovered':'Undiscovered').'</td></tr>';echo '</table></section>';
    break;
case 'changelog':
    echo '<h1>Changelog</h1><section class="card"><h2>0.9.4-lab</h2><ul><li>Added fictional invoice API.</li><li>Enabled dependency support console at <a href="/?route=vendor-demo">vendor-demo</a>.</li><li>Warehouse team testing <a href="/?route=command-console">local command console</a>.</li><li>Refund team testing <a href="/?route=refund">estimator</a>.</li><li>Security reviewing <a href="/?route=password-reset">reset verifier</a> and <a href="/?route=logs">audit viewer</a>.</li></ul></section>';
    break;
default:
    http_response_code(404);echo '<h1>Page not found</h1><p>Try the portal navigation.</p>';
}
render_footer();
