<?php
// app/config.php

function getDatabaseConnection() {
    $host = $_ENV['DB_HOST'] ?? 'mysql';
    $dbname = $_ENV['DB_NAME'] ?? 'hello_world';
    $username = $_ENV['DB_USER'] ?? 'app_user';
    $password = $_ENV['DB_PASSWORD'] ?? 'app_password';
    
    try {
        $dsn = "mysql:host={$host};dbname={$dbname};charset=utf8mb4";
        $pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        
        // Create visits table if it doesn't exist
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS visits (
                id INT AUTO_INCREMENT PRIMARY KEY,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                ip_address VARCHAR(45)
            )
        ");
        
        return $pdo;
    } catch (PDOException $e) {
        error_log("Database connection failed: " . $e->getMessage());
        return null;
    }
}
?>