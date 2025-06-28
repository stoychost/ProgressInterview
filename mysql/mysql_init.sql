-- mysql/init.sql
-- Database initialization script

USE hello_world;

-- Create visits table
CREATE TABLE IF NOT EXISTS visits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,
    INDEX idx_timestamp (timestamp),
    INDEX idx_ip_address (ip_address)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create application logs table
CREATE TABLE IF NOT EXISTS app_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    level ENUM('DEBUG', 'INFO', 'WARN', 'ERROR') DEFAULT 'INFO',
    message TEXT NOT NULL,
    context JSON,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_level (level),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert some sample data
INSERT INTO visits (ip_address, user_agent) VALUES 
('127.0.0.1', 'Docker Health Check'),
('10.0.0.1', 'Sample User Agent');

INSERT INTO app_logs (level, message, context) VALUES 
('INFO', 'Application initialized', '{"component": "database", "action": "init"}'),
('INFO', 'Sample data inserted', '{"component": "database", "action": "seed"}');

-- Create a view for visit statistics
CREATE VIEW visit_stats AS
SELECT 
    DATE(timestamp) as visit_date,
    COUNT(*) as total_visits,
    COUNT(DISTINCT ip_address) as unique_visitors
FROM visits 
GROUP BY DATE(timestamp)
ORDER BY visit_date DESC;

-- Grant additional permissions to app user
GRANT SELECT, INSERT, UPDATE ON hello_world.* TO 'app_user'@'%';
FLUSH PRIVILEGES;