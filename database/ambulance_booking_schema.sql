CREATE DATABASE IF NOT EXISTS ambulance_booking_db;

USE ambulance_booking_db;

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    blood_group VARCHAR(10),
    medical_details TEXT,
    emergency_contact VARCHAR(15),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE admins (
    admin_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ambulances (
    ambulance_id INT AUTO_INCREMENT PRIMARY KEY,
    driver_name VARCHAR(100) NOT NULL,
    driver_phone VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    vehicle_number VARCHAR(30) NOT NULL UNIQUE,
    ambulance_type VARCHAR(50),
    current_latitude DECIMAL(10,8),
    current_longitude DECIMAL(11,8),
    status ENUM('PendingApproval', 'Available', 'Busy', 'Inactive') DEFAULT 'PendingApproval',
    is_approved BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bookings (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    ambulance_id INT,
    pickup_latitude DECIMAL(10,8) NOT NULL,
    pickup_longitude DECIMAL(11,8) NOT NULL,
    destination_hospital VARCHAR(150),
    patient_condition TEXT,
    status ENUM('Requested', 'Accepted', 'Rejected', 'InProgress', 'Completed', 'Cancelled') DEFAULT 'Requested',
    booking_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    accepted_time DATETIME NULL,
    completed_time DATETIME NULL,

    CONSTRAINT fk_booking_user
        FOREIGN KEY (user_id) REFERENCES users(user_id),

    CONSTRAINT fk_booking_ambulance
        FOREIGN KEY (ambulance_id) REFERENCES ambulances(ambulance_id)
);

CREATE TABLE booking_status_history (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    status VARCHAR(50) NOT NULL,
    remarks TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_history_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
);
