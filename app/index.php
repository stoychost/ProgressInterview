<?php
// app/index.php
require_once 'config.php';

// Get database connection
$pdo = getDatabaseConnection();

// Insert a visit log
try {
    $stmt = $pdo->prepare("INSERT INTO visits (timestamp, ip_address) VALUES (NOW(), ?)");
    $stmt->execute([$_SERVER['REMOTE_ADDR'] ?? 'unknown']);
    
    // Get total visit count
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM visits");
    $visitCount = $stmt->fetch()['total'];
} catch (PDOException $e) {
    $visitCount = "Error counting visits";
}

// Simple health check endpoint
if ($_GET['health'] ?? false) {
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'healthy',
        'timestamp' => date('Y-m-d H:i:s'),
        'database' => $pdo ? 'connected' : 'disconnected'
    ]);
    exit;
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
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Hello World Microservice</h1>
        <p>Welcome to our containerized PHP microservice!</p>
        
        <div class="stats">
            <h3>📊 Service Stats</h3>
            <p><strong>Total Visits:</strong> <?php echo htmlspecialchars($visitCount); ?></p>
            <p><strong>Current Time:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
            <p><strong>Server:</strong> <?php echo gethostname(); ?></p>
            <p><strong>PHP Version:</strong> <?php echo phpversion(); ?></p>
        </div>
        
        <div class="stats">
            <h3>🔗 API Endpoints</h3>
            <p><a href="?health=1" style="color: #ffeb3b;">Health Check</a> - JSON health status</p>
        </div>
        
        <div class="stats">
            <h3>🐳 Container Info</h3>
            <p><strong>Environment:</strong> <?php echo $_ENV['APP_ENV'] ?? 'development'; ?></p>
            <p><strong>Database Host:</strong> <?php echo $_ENV['DB_HOST'] ?? 'localhost'; ?></p>
        </div>
    </div>
</body>
</html>