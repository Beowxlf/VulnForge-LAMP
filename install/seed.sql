-- VulnForge-LAMP clean-room seed. All identities, credentials, and records are fictional.
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS=0;
DROP TABLE IF EXISTS submissions, audit_logs, password_resets, coupons, support_tickets, invoices, products, flags, users, roles, app_settings;
SET FOREIGN_KEY_CHECKS=1;

CREATE TABLE roles (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(40) NOT NULL UNIQUE);
CREATE TABLE users (
 id INT AUTO_INCREMENT PRIMARY KEY, role_id INT NOT NULL, email VARCHAR(120) NOT NULL UNIQUE,
 display_name VARCHAR(100) NOT NULL, password_hash VARCHAR(255) NOT NULL, hash_scheme VARCHAR(20) NOT NULL DEFAULT 'md5',
 profile_bio TEXT, encoded_private_note TEXT, remember_hint VARCHAR(120), created_at DATETIME NOT NULL,
 FOREIGN KEY(role_id) REFERENCES roles(id)
);
CREATE TABLE products (id INT AUTO_INCREMENT PRIMARY KEY, sku VARCHAR(30), name VARCHAR(120), description TEXT, price DECIMAL(10,2), internal_note TEXT);
CREATE TABLE invoices (
 id INT PRIMARY KEY, user_id INT NOT NULL, invoice_number VARCHAR(30), item_summary VARCHAR(255), amount DECIMAL(10,2), payment_status VARCHAR(40), private_note TEXT,
 FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE support_tickets (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, subject VARCHAR(160), body TEXT, status VARCHAR(30), admin_only TINYINT(1) DEFAULT 0, internal_note TEXT,
 FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE flags (
 id INT AUTO_INCREMENT PRIMARY KEY, category VARCHAR(8) NOT NULL, challenge_name VARCHAR(160) NOT NULL,
 difficulty ENUM('Easy','Medium','Hard') NOT NULL, flag_value VARCHAR(160) NOT NULL UNIQUE,
 hint1 TEXT NOT NULL, hint2 TEXT NOT NULL, points INT NOT NULL DEFAULT 100
);
CREATE TABLE submissions (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, flag_id INT NOT NULL, submitted_at DATETIME NOT NULL,
 UNIQUE KEY uniq_submission(user_id,flag_id), FOREIGN KEY(user_id) REFERENCES users(id), FOREIGN KEY(flag_id) REFERENCES flags(id)
);
CREATE TABLE coupons (id INT AUTO_INCREMENT PRIMARY KEY, code VARCHAR(40) UNIQUE, percent_off INT, max_uses INT, uses INT DEFAULT 0, active TINYINT DEFAULT 1, internal_note TEXT);
CREATE TABLE password_resets (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, token VARCHAR(160), used TINYINT DEFAULT 0, expires_at DATETIME, FOREIGN KEY(user_id) REFERENCES users(id));
CREATE TABLE audit_logs (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NULL, event_type VARCHAR(80), details TEXT, created_at DATETIME, FOREIGN KEY(user_id) REFERENCES users(id));
CREATE TABLE app_settings (id INT AUTO_INCREMENT PRIMARY KEY, setting_key VARCHAR(100) UNIQUE, setting_value TEXT, is_public TINYINT DEFAULT 0);

INSERT INTO roles(name) VALUES ('admin'),('analyst'),('employee'),('guest');
-- Obvious lab-only passwords: admin123, analyst123, smith123, chen123, guest
INSERT INTO users(role_id,email,display_name,password_hash,hash_scheme,profile_bio,encoded_private_note,remember_hint,created_at) VALUES
(1,'admin@northstar.local','Avery Admin',MD5('admin123'),'md5','Fictional portal administrator.','RkxBR3tBMDdfREVGQVVMVF9BRE1JTl8wMX0=','base64(user:1)','2026-01-01'),
(2,'analyst@northstar.local','Riley Analyst',MD5('analyst123'),'md5','Inventory and fraud analyst.','RkxBR3tBMDNfV0VBS19FTkNPRElOR18wMX0=','base64(user:2)','2026-01-01'),
(3,'j.smith@northstar.local','Jordan Smith',MD5('smith123'),'md5','Retail operations coordinator.','RmljdGlvbmFsIGVtcGxveWVlIG5vdGU=','base64(user:3)','2026-01-01'),
(3,'m.chen@northstar.local','Morgan Chen',MD5('chen123'),'md5','Wholesale account coordinator. FLAG{A04_WEAK_HASH_PROFILE_02}','RmFrZSBub3RlIG9ubHk=','base64(user:4)','2026-01-01'),
(4,'guest@northstar.local','Guest Player',MD5('guest'),'md5','Local training player.','Tm8gc2VjcmV0cyBoZXJl','base64(user:5)','2026-01-01');

INSERT INTO products(sku,name,description,price,internal_note) VALUES
('NS-100','Trailhead Daypack','Lightweight fictional 20L daypack.',49.95,'seasonal'),
('NS-210','Aurora Camp Lantern','Rechargeable fictional lantern.',34.50,'FLAG{A05_SQLI_CATALOG_01}'),
('NS-315','Summit Brew Kit','Compact fictional camp coffee set.',28.00,'bundle candidate'),
('NS-410','Timberline Shell','Water-resistant fictional jacket.',119.00,'clearance review');

INSERT INTO invoices(id,user_id,invoice_number,item_summary,amount,payment_status,private_note) VALUES
(1001,3,'INV-2026-1001','Trailhead Daypack x2',99.90,'Paid','standard employee purchase'),
(1002,4,'INV-2026-1002','Timberline Shell x1',119.00,'Paid','Cross-account marker: FLAG{A01_INVOICE_IDOR_01}'),
(1003,2,'INV-2026-1003','Aurora Camp Lantern x10',345.00,'Review','analyst test record');

INSERT INTO support_tickets(user_id,subject,body,status,admin_only,internal_note) VALUES
(3,'Size exchange','Need a fictional jacket exchange.','Open',0,'normal queue'),
(4,'Wholesale portal question','Cannot view the wholesale price list.','Open',0,'normal queue'),
(1,'Admin migration incident','Review role migration before launch.','Restricted',1,'FLAG{A01_ADMIN_TICKET_BYPASS_02}');

INSERT INTO coupons(code,percent_off,max_uses,uses,active,internal_note) VALUES
('WELCOME10',10,1,0,1,'new fake accounts'),
('LABREFUND',25,1,0,1,'Negative quantities reveal FLAG{A06_REFUND_LOGIC_01}');

INSERT INTO password_resets(user_id,token,used,expires_at) VALUES
(2,'reset-2-2026',0,'2030-01-01'),
(4,'reset-4-2026',0,'2030-01-01');

INSERT INTO app_settings(setting_key,setting_value,is_public) VALUES
('portal_version','0.9.4-lab',1),
('diagnostic_region','hyperv-private-switch',1),
('debug_marker','FLAG{A02_VERBOSE_DIAGNOSTICS_02}',1),
('import_review_marker','FLAG{A08_CLIENT_ROLE_TRUST_01}',0),
('exception_marker','FLAG{A10_VERBOSE_EXCEPTION_01}',0),
('api_exception_marker','FLAG{A10_API_ERROR_LEAK_02}',0),
('logging_gap_marker','FLAG{A09_MISSING_AUDIT_EVENT_02}',0),
('reset_marker','FLAG{A06_PREDICTABLE_RESET_02}',0),
('command_marker','FLAG{A05_SIMULATED_COMMAND_CHAIN_02}',0),
('remember_marker','FLAG{A07_PREDICTABLE_REMEMBER_TOKEN_02}',0),
('vendor_output_marker','FLAG{A03_UNSAFE_HELPER_OUTPUT_01}',0);

INSERT INTO flags(category,challenge_name,difficulty,flag_value,hint1,hint2,points) VALUES
('A01','Someone Else’s Invoice','Easy','FLAG{A01_INVOICE_IDOR_01}','Invoice identifiers may be more trusted than the signed-in owner.','Compare nearby fictional invoice numbers.',100),
('A01','Restricted Support Preview','Medium','FLAG{A01_ADMIN_TICKET_BYPASS_02}','One support view trusts a preview control.','Inspect how the restricted ticket route decides authorization.',150),
('A02','Nightly Backup Exposure','Easy','FLAG{A02_EXPOSED_BACKUP_01}','Operational leftovers may be web-accessible.','Browse the intentionally indexed backup alias.',100),
('A02','Diagnostics Overshare','Easy','FLAG{A02_VERBOSE_DIAGNOSTICS_02}','Status pages should reveal less in production.','Request the detailed diagnostics view.',100),
('A03','Outdated Package Notes','Easy','FLAG{A03_OUTDATED_PACKAGE_DOC_02}','The fictional dependency ships documentation.','Review the fake package README.',100),
('A03','Unsafe Helper Banner','Medium','FLAG{A03_UNSAFE_HELPER_OUTPUT_01}','A vendor helper has a verbose mode.','Use the vendor-demo debug control.',150),
('A04','Base64 Is Not Encryption','Easy','FLAG{A04_WEAK_ENCODING_01}','A profile field is merely encoded.','Decode the analyst’s private-note value.',100),
('A04','Legacy Password Storage','Medium','FLAG{A04_WEAK_HASH_PROFILE_02}','The portal identifies its legacy hash scheme.','Authenticate as a seeded user and inspect another fake profile.',150),
('A05','Catalog Query Injection','Medium','FLAG{A05_SQLI_CATALOG_01}','Search text is inserted into a database query.','Cause the catalog to return internal_note values.',200),
('A05','Diagnostic Command Chain','Easy','FLAG{A05_SIMULATED_COMMAND_CHAIN_02}','The lab command console accepts more than one simulated operation.','Chain show marker after a normal status command.',100),
('A06','Negative Refund Quantity','Medium','FLAG{A06_REFUND_LOGIC_01}','The refund calculator validates neither sign nor workflow state.','Try a negative quantity with LABREFUND.',150),
('A06','Predictable Reset Token','Medium','FLAG{A06_PREDICTABLE_RESET_02}','Reset tokens are derived from public local IDs and a year.','Inspect token shape, then use a seeded fake user ID.',150),
('A07','Factory Admin Credentials','Easy','FLAG{A07_DEFAULT_ADMIN_01}','The lab guide documents obvious credentials.','Sign in as the fictional administrator.',100),
('A07','Remember-Me Impersonation','Medium','FLAG{A07_PREDICTABLE_REMEMBER_TOKEN_02}','The cookie is encoded, not signed.','Base64-encode a different local user identifier.',150),
('A08','Unsigned Profile Import','Medium','FLAG{A08_CLIENT_ROLE_TRUST_01}','Imported JSON is trusted as an authority.','Import a profile containing an admin role.',150),
('A08','Trusted Upload Metadata','Easy','FLAG{A08_UNSIGNED_UPLOAD_META_02}','The uploads directory includes client-controlled metadata.','Inspect dot-file metadata or the welcome upload.',100),
('A09','Writable-Looking Application Log','Easy','FLAG{A09_TAMPERABLE_LOG_01}','Application logs are exposed with weak lab permissions.','Review the sample log alias.',100),
('A09','Authentication Event Gap','Medium','FLAG{A09_MISSING_AUDIT_EVENT_02}','Some sensitive actions never reach the audit table.','Compare login/import behavior with the log viewer.',150),
('A10','Verbose Product Exception','Easy','FLAG{A10_VERBOSE_EXCEPTION_01}','Unexpected product IDs trigger debug output.','Request a non-numeric product detail ID.',100),
('A10','API Exception Detail','Easy','FLAG{A10_API_ERROR_LEAK_02}','The local API returns debug context on errors.','Call the invoice API without its required identifier.',100);

INSERT INTO audit_logs(user_id,event_type,details,created_at) VALUES
(NULL,'system.boot','Training portal initialized','2026-01-15 08:00:01'),
(3,'invoice.view','invoice=1001','2026-01-15 08:05:22'),
(NULL,'report.complete','Report generated successfully; actor omitted','2026-01-15 08:07:03');
