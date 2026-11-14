CREATE DATABASE IF NOT EXISTS supportsphere;
USE supportsphere;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS feedback;
DROP TABLE IF EXISTS request_history;
DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS assistance_requests;
DROP TABLE IF EXISTS volunteer_skills;
DROP TABLE IF EXISTS skills;
DROP TABLE IF EXISTS volunteer_profiles;
DROP TABLE IF EXISTS requester_profiles;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
 user_id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(100) NOT NULL, email VARCHAR(150) NOT NULL UNIQUE,
 password VARCHAR(255) NOT NULL, phone VARCHAR(20) NOT NULL, role ENUM('REQUESTER','VOLUNTEER','ADMIN') NOT NULL,
 area VARCHAR(120), city VARCHAR(120), landmark VARCHAR(180), status ENUM('ACTIVE','BLOCKED') NOT NULL DEFAULT 'ACTIVE',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE requester_profiles (requester_id INT PRIMARY KEY, accessibility_notes VARCHAR(500), FOREIGN KEY(requester_id) REFERENCES users(user_id) ON DELETE CASCADE);
CREATE TABLE volunteer_profiles (
 volunteer_id INT PRIMARY KEY, experience_years INT NOT NULL DEFAULT 0, availability_start TIME NOT NULL, availability_end TIME NOT NULL,
 verification_status ENUM('PENDING','VERIFIED','REJECTED') DEFAULT 'PENDING', rating DECIMAL(3,2) DEFAULT 0.00, rating_count INT DEFAULT 0,
 FOREIGN KEY(volunteer_id) REFERENCES users(user_id) ON DELETE CASCADE
);
CREATE TABLE skills(skill_id INT PRIMARY KEY AUTO_INCREMENT, skill_name VARCHAR(80) UNIQUE NOT NULL);
CREATE TABLE volunteer_skills(volunteer_id INT NOT NULL, skill_id INT NOT NULL, PRIMARY KEY(volunteer_id,skill_id),
 FOREIGN KEY(volunteer_id) REFERENCES volunteer_profiles(volunteer_id) ON DELETE CASCADE, FOREIGN KEY(skill_id) REFERENCES skills(skill_id) ON DELETE CASCADE);
CREATE TABLE assistance_requests (
 request_id INT PRIMARY KEY AUTO_INCREMENT, requester_id INT NOT NULL, task_type VARCHAR(80) NOT NULL, description VARCHAR(500) NOT NULL,
 area VARCHAR(120) NOT NULL, city VARCHAR(120) NOT NULL, landmark VARCHAR(180), urgency ENUM('LOW','MEDIUM','HIGH','EMERGENCY') NOT NULL,
 preferred_date DATE NOT NULL, start_time TIME NOT NULL, end_time TIME NOT NULL,
 status ENUM('OPEN','ASSIGNED','IN_PROGRESS','COMPLETED','CANCELLED','EXPIRED') NOT NULL DEFAULT 'OPEN', cancellation_reason VARCHAR(300),
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(requester_id) REFERENCES users(user_id)
);
CREATE TABLE assignments(
 assignment_id INT PRIMARY KEY AUTO_INCREMENT, request_id INT NOT NULL UNIQUE, volunteer_id INT NOT NULL,
 assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, accepted_at TIMESTAMP NULL, started_at TIMESTAMP NULL, completed_at TIMESTAMP NULL,
 status ENUM('ASSIGNED','IN_PROGRESS','COMPLETED','CANCELLED') NOT NULL DEFAULT 'ASSIGNED', cancellation_reason VARCHAR(300),
 FOREIGN KEY(request_id) REFERENCES assistance_requests(request_id), FOREIGN KEY(volunteer_id) REFERENCES volunteer_profiles(volunteer_id)
);
CREATE TABLE request_history(
 history_id INT PRIMARY KEY AUTO_INCREMENT, request_id INT NOT NULL, old_status VARCHAR(30), new_status VARCHAR(30) NOT NULL,
 changed_by INT, note VARCHAR(300), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(request_id) REFERENCES assistance_requests(request_id) ON DELETE CASCADE, FOREIGN KEY(changed_by) REFERENCES users(user_id) ON DELETE SET NULL
);
CREATE TABLE feedback(
 feedback_id INT PRIMARY KEY AUTO_INCREMENT, request_id INT NOT NULL UNIQUE, requester_id INT NOT NULL, volunteer_id INT NOT NULL,
 rating INT NOT NULL CHECK(rating BETWEEN 1 AND 5), comment VARCHAR(500), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(request_id) REFERENCES assistance_requests(request_id), FOREIGN KEY(requester_id) REFERENCES users(user_id), FOREIGN KEY(volunteer_id) REFERENCES volunteer_profiles(volunteer_id)
);
CREATE TABLE notifications(
 notification_id INT PRIMARY KEY AUTO_INCREMENT, user_id INT NOT NULL, title VARCHAR(120) NOT NULL, message VARCHAR(400) NOT NULL,
 type VARCHAR(40) DEFAULT 'INFO', is_read BOOLEAN DEFAULT FALSE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
CREATE TABLE audit_logs(
 audit_id INT PRIMARY KEY AUTO_INCREMENT, user_id INT, action VARCHAR(120) NOT NULL, entity_type VARCHAR(50), entity_id INT,
 details VARCHAR(500), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(user_id) ON DELETE SET NULL
);
INSERT INTO skills(skill_name) VALUES ('Grocery Shopping'),('Medicine Collection'),('Transportation'),('Bill Payment'),('Appointment Assistance'),('Document Assistance'),('Household Assistance'),('Other');
INSERT INTO users(name,email,password,phone,role,area,city,landmark) VALUES
('System Admin','admin@supportsphere.com','240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9','9999999999','ADMIN','Model Town','Patiala','City Centre'),
('Demo Volunteer','volunteer@supportsphere.com','25a21eab5feca60534fc732ff65e27984b61e43d0c7a4614b9710cd01456c37a','9999999998','VOLUNTEER','Model Town','Patiala','City Centre'),
('Demo Requester','requester@supportsphere.com','ffe69b6b40565d95264b872fe4cf6c0ca0aa856f03df6f81ad912ac73775fbe0','9999999997','REQUESTER','Model Town','Patiala','City Centre');
INSERT INTO requester_profiles(requester_id) SELECT user_id FROM users WHERE email='requester@supportsphere.com';
INSERT INTO volunteer_profiles(volunteer_id,experience_years,availability_start,availability_end,verification_status,rating,rating_count)
SELECT user_id,2,'09:00:00','20:00:00','VERIFIED',4.50,2 FROM users WHERE email='volunteer@supportsphere.com';
INSERT INTO volunteer_skills(volunteer_id,skill_id) SELECT u.user_id,s.skill_id FROM users u JOIN skills s ON s.skill_name IN('Medicine Collection','Grocery Shopping') WHERE u.email='volunteer@supportsphere.com';
