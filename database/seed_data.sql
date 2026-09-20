USE ambulance_booking_db;

-- 1. Admins
INSERT INTO admins (full_name, email, password_hash)
VALUES
('System Admin (Tamil Nadu Emergency)', 'admin@emergency.com', 'AQAAAAEAACcQAAAAEJ/demo_admin_hash_placeholder');

-- 2. Tamil Nadu Premier Hospitals & Trauma Care Centers
INSERT INTO hospitals (hospital_id, name, contact_phone, address, latitude, longitude, has_emergency_icu, available_icu_beds, total_beds) VALUES
(1, 'Rajiv Gandhi Govt General Hospital (RGGGH)', '044-25305000', 'EVR Periyar Salai, Park Town, Chennai, Tamil Nadu 600003', 13.0805, 80.2764, 1, 45, 500),
(2, 'Apollo Hospitals Main & Emergency Trauma', '044-28290200', '21 Greams Road, Thousand Lights, Chennai, Tamil Nadu 600006', 13.0604, 80.2496, 1, 28, 250),
(3, 'MIOT International Multi-Specialty Hospital', '044-42002288', '4/112 Mount Poonamallee Rd, Manapakkam, Chennai, Tamil Nadu 600089', 13.0204, 80.1772, 1, 32, 300),
(4, 'Sri Ramachandra Medical Centre (SRMC)', '044-45928500', 'No. 1 Mount Poonamallee Rd, Porur, Chennai, Tamil Nadu 600116', 13.0382, 80.1444, 1, 25, 400),
(5, 'SIMS Hospital (SRM Emergency & Trauma)', '044-20002001', '1 Jawaharlal Nehru Salai, Vadapalani, Chennai, Tamil Nadu 600026', 13.0526, 80.2098, 1, 19, 220),
(6, 'Kauvery Hospital Chennai', '044-40006000', '81 TTK Road, Alwarpet, Chennai, Tamil Nadu 600018', 13.0336, 80.2505, 1, 18, 180),
(7, 'Ganga Hospital & Trauma Care Centre', '0422-2485000', '313 Mettupalayam Road, Saibaba Colony, Coimbatore, Tamil Nadu 641043', 11.0267, 76.9458, 1, 30, 280),
(8, 'Government Rajaji Hospital (GRH Trauma)', '0452-2532535', 'Panagal Road, Alagar Kovil, Madurai, Tamil Nadu 625020', 9.9288, 78.1312, 1, 35, 450),
(9, 'Christian Medical College (CMC Trauma)', '0416-2281000', 'Ida Scudder Road, Vellore, Tamil Nadu 632004', 12.9260, 79.1353, 1, 40, 600),
(10, 'Kauvery Hospital Trichy', '0431-4077777', '1 Royal Road, Cantonment, Tiruchirappalli, Tamil Nadu 620001', 10.8058, 78.6856, 1, 22, 200)
ON DUPLICATE KEY UPDATE name=VALUES(name), address=VALUES(address), contact_phone=VALUES(contact_phone);

-- 3. Tamil Nadu Emergency Ambulance Fleet
INSERT INTO ambulances (driver_name, driver_phone, email, password_hash, vehicle_number, ambulance_type, current_latitude, current_longitude, status, is_approved)
VALUES
('M. Murugan (108 Paramedic)', '9876543210', 'robert.driver@emergency.com', 'AQAAAAEAACcQAAAAEJ/demo_driver_hash_placeholder', 'TN-01-EM-1080', 'Advanced Life Support', 13.0850, 80.2720, 'Available', TRUE),
('S. Selvam (Cardiac ICU)', '9840123456', 'selvam.driver@emergency.com', 'AQAAAAEAACcQAAAAEJ/demo_driver_hash_placeholder', 'TN-07-ICU-2026', 'Cardiac Life Support', 13.0604, 80.2496, 'Available', TRUE),
('K. Anbarasan (Trauma Care)', '9840987654', 'anbarasan.driver@emergency.com', 'AQAAAAEAACcQAAAAEJ/demo_driver_hash_placeholder', 'TN-09-TR-1008', 'Trauma Life Support', 13.0418, 80.2341, 'Available', TRUE)
ON DUPLICATE KEY UPDATE driver_name=VALUES(driver_name), vehicle_number=VALUES(vehicle_number);
