<?php
// app/index.php
require_once 'config.php';

// Simple health check endpoint (check this FIRST, before database)
if ($_SERVER['REQUEST_URI'] === '/health' || (isset($_GET['health']) && $_GET['health'])) {
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'healthy',
        'timestamp' => date('Y-m-d H:i:s'),
        'port' => 8000,
        'server' => gethostname()
    ]);
    exit;
}

// Initialize variables
$pdo = null;
$visitCount = 0;
$dbError = null;

// Get database connection
try {
    $pdo = getDatabaseConnection();
    
    if ($pdo) {
        // Insert a visit log
        $stmt = $pdo->prepare("INSERT INTO visits (timestamp, ip_address) VALUES (NOW(), ?)");
        $stmt->execute([$_SERVER['REMOTE_ADDR'] ?? 'unknown']);
        
        // Get total visit count
        $stmt = $pdo->query("SELECT COUNT(*) as total FROM visits");
        $visitCount = $stmt->fetch()['total'];
    }
} catch (Exception $e) {
    $dbError = $e->getMessage();
    error_log("Database error: " . $dbError);
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello World Microservice</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .stats {
            margin-top: 20px;
            padding: 15px;
            background: rgba(255,255,255,0.1);
            border-radius: 5px;
        }
        .error {
            background: rgba(255,0,0,0.2);
            color: #ffcccc;
            padding: 15px;
            border-radius: 5px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Hello World Microservice</h1>
        <p>Welcome to our containerized PHP microservice!</p>
        
        <?php if ($dbError): ?>
        <div class="error">
            <h3>⚠️ Database Connection Error</h3>
            <p><strong>Error:</strong> <?php echo htmlspecialchars($dbError); ?></p>
            <p><strong>DB Host:</strong> <?php echo htmlspecialchars($_ENV['DB_HOST'] ?? 'Not set'); ?></p>
            <p><strong>DB Name:</strong> <?php echo htmlspecialchars($_ENV['DB_NAME'] ?? 'Not set'); ?></p>
            <p><strong>DB User:</strong> <?php echo htmlspecialchars($_ENV['DB_USER'] ?? 'Not set'); ?></p>
        </div>
        <?php endif; ?>
        
        <div class="stats">
            <h3>📊 Service Stats</h3>
            <p><strong>Database Status:</strong> <?php echo $pdo ? '✅ Connected' : '❌ Disconnected'; ?></p>
            <p><strong>Total Visits:</strong> <?php echo $pdo ? htmlspecialchars($visitCount) : 'N/A (Database offline)'; ?></p>
            <p><strong>Current Time:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
            <p><strong>Server:</strong> <?php echo gethostname(); ?></p>
            <p><strong>PHP Version:</strong> <?php echo phpversion(); ?></p>
        </div>
        
        <div class="stats">
            <h3>🔗 API Endpoints</h3>
            <p><a href="/health" style="color: #ffeb3b;">Health Check</a> - JSON health status</p>
        </div>
        
        <div class="stats">
            <h3>🐳 Container Info</h3>
            <p><strong>Environment:</strong> <?php echo $_ENV['APP_ENV'] ?? 'development'; ?></p>
            <p><strong>Database Host:</strong> <?php echo $_ENV['DB_HOST'] ?? 'localhost'; ?></p>
            <p><strong>Container IP:</strong> <?php echo $_SERVER['SERVER_ADDR'] ?? 'unknown'; ?></p>
        </div>
    </div>
</body>
</html>