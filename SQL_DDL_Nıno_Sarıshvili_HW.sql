-- Why we start with the parent table?

-- Tables must be created in the correct order due to FOREIGN KEY dependencies,
-- a child table references a parent table using a FOREIGN KEY.
-- if the parent table does not exist at the time of child table creation,
-- SQL will show the following error:
-- ERROR: relation "parent_table_name" does not exist
-- This happens because the database cannot validate the FOREIGN KEY reference.


-- create schema
CREATE SCHEMA IF NOT EXISTS hotel_schema;


-- we need to create types (enums that prevent invalid values)

CREATE TYPE hotel_schema.employee_role AS ENUM ('receptionist', 'cleaner', 'manager');

CREATE TYPE hotel_schema.booking_status AS ENUM ('confirmed', 'cancelled', 'completed');

CREATE TYPE hotel_schema.payment_status AS ENUM ('complete', 'pending', 'failed');

CREATE TYPE hotel_schema.room_status_enum AS ENUM (
    'Available',
    'Occupied',
    'Maintenance'
);

CREATE TYPE hotel_schema.payment_method_enum AS ENUM (
    'credit card',
    'bank transfer',
    'cash'
);


-- now I create the database 

CREATE TABLE IF NOT EXISTS hotel_schema.hotel (
    hotel_id INT GENERATED ALWAYS AS IDENTITY,
    hotel_num VARCHAR(20) NOT NULL,
    hotel_type VARCHAR(50) NOT NULL,
    location VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,

    CONSTRAINT pk_hotel PRIMARY KEY (hotel_id),

    -- unique constraint (prevents duplicate hotel identifiers)
    CONSTRAINT uq_hotel_num UNIQUE (hotel_num));
 -- didn't have this in the intitial data model but this makes sense cause there should beindividual hotel numbers


CREATE TABLE IF NOT EXISTS hotel_schema.room (
    room_id INT GENERATED ALWAYS AS IDENTITY,
    hotel_id INT NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    room_status hotel_schema.room_status_enum NOT NULL,
    description_text VARCHAR(200) NOT NULL,
    capacity INT NOT NULL,

    CONSTRAINT pk_room PRIMARY KEY (room_id),

    CONSTRAINT fk_room_hotel 
        FOREIGN KEY (hotel_id) 
        REFERENCES hotel_schema.hotel(hotel_id),
        
    CONSTRAINT chk_price_positive 
        CHECK (price >= 0),

    CONSTRAINT chk_capacity_positive
        CHECK (capacity > 0)
);
--prevents negative price


CREATE TABLE IF NOT EXISTS hotel_schema.customer (
customer_id INT GENERATED ALWAYS AS IDENTITY,
name VARCHAR(50) NOT NULL,
user_phone VARCHAR(12) NOT NULL,
user_email VARCHAR(100) not null,

CONSTRAINT pk_customer PRIMARY KEY (customer_id),
CONSTRAINT uq_customer_phone UNIQUE (user_phone),
CONSTRAINT uq_customer_email UNIQUE (user_email)
);

--UNIQUE prevents duplicate emails and ohone numbers as well as NOT NULL makes sure we retrieve this data

CREATE TABLE IF NOT EXISTS hotel_schema.employee (
    employee_id INT GENERATED ALWAYS AS IDENTITY,
    
    employee_role hotel_schema.employee_role NOT NULL,
    
    employee_name VARCHAR(50) NOT NULL,
    
    email VARCHAR(50) NOT NULL,
    
    phone VARCHAR(12) NOT NULL,

    CONSTRAINT pk_employee PRIMARY KEY (employee_id),
    CONSTRAINT uq_employee_email UNIQUE (email),
    CONSTRAINT uq_employee_phone UNIQUE (phone)
);


CREATE TABLE IF NOT EXISTS hotel_schema.booking (
    booking_id INT GENERATED ALWAYS AS IDENTITY,
    customer_id INT NOT NULL,
    room_id INT NOT NULL,
    
    booking_date DATE NOT NULL,
    booking_in_time TIME NOT NULL,
    booking_out_time TIME NOT NULL,
    
    booking_status hotel_schema.booking_status NOT NULL,
    
    CONSTRAINT pk_booking PRIMARY KEY (booking_id),

    CONSTRAINT fk_booking_customer 
        FOREIGN KEY (customer_id) 
        REFERENCES hotel_schema.customer(customer_id),

    CONSTRAINT fk_booking_room 
        FOREIGN KEY (room_id) 
        REFERENCES hotel_schema.room(room_id),

    CONSTRAINT chk_booking_date 
        CHECK (booking_date > DATE '2000-01-01'),

    CONSTRAINT chk_booking_time_order 
        CHECK (booking_out_time > booking_in_time)
);

--prevents invalid old dates
-- ensures that checking in is earlier than checking out


-- For many-to-many relationship, we create the bridge table last
CREATE TABLE IF NOT EXISTS hotel_schema.employee_booking (
    employee_booking_id INT GENERATED ALWAYS AS IDENTITY,
    employee_id INT NOT NULL,
    booking_id INT NOT NULL,
    hours_worked DECIMAL(5,2) NOT NULL,

    CONSTRAINT pk_employee_booking 
        PRIMARY KEY (employee_booking_id),

    CONSTRAINT fk_emp_booking_emp 
        FOREIGN KEY (employee_id) 
        REFERENCES hotel_schema.employee(employee_id),

    CONSTRAINT fk_emp_booking_booking 
        FOREIGN KEY (booking_id) 
        REFERENCES hotel_schema.booking(booking_id)

   
);


CREATE TABLE IF NOT EXISTS hotel_schema.payment (
    payment_id INT GENERATED ALWAYS AS IDENTITY,
    booking_id INT NOT NULL,
    amount_paid NUMERIC(10,2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    payment_status hotel_schema.payment_status NOT NULL DEFAULT 'pending',
-- I created a default value here 'pending'
    payment_method hotel_schema.payment_method_enum NOT NULL,

    CONSTRAINT pk_payment PRIMARY KEY (payment_id),

    CONSTRAINT fk_payment_booking 
        FOREIGN KEY (booking_id) 
        REFERENCES hotel_schema.booking(booking_id),

    CONSTRAINT chk_amount 
        CHECK (amount_paid >= 0)
);

CREATE TABLE IF NOT EXISTS hotel_schema.invoice (
    invoice_id INT GENERATED ALWAYS AS IDENTITY,
    booking_id INT NOT NULL,
    invoice_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    amount NUMERIC(10,2) NOT NULL,

    CONSTRAINT pk_invoice PRIMARY KEY (invoice_id),

    CONSTRAINT fk_invoice_payment 
        FOREIGN KEY (booking_id) REFERENCES hotel_schema.booking(booking_id),
        CONSTRAINT chk_amount 
        CHECK (amount >= 0)
);

CREATE TABLE IF NOT EXISTS hotel_schema.review (
    review_id INT GENERATED ALWAYS AS IDENTITY,
   
    booking_id INT NOT NULL,
    
    rating INT NOT NULL,
    comment TEXT NOT NULL,
    
    review_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_review PRIMARY KEY (review_id),

    CONSTRAINT fk_review_booking 
        FOREIGN KEY (booking_id) 
        REFERENCES hotel_schema.booking(booking_id),

    CONSTRAINT chk_rating 
        CHECK (rating BETWEEN 1 AND 5)
);



--if FK is missing:
--invalid references possible (e.g. booking with non-existing customer)
--data inconsistency
--broken joins

--INSERTING DATA

-- customers
INSERT INTO hotel_schema.customer (first_name, last_name, email)
SELECT 'Nino','Sarishvili','nino@mail.com'
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.customer WHERE email='nino@mail.com'
);

-- hotel
INSERT INTO hotel_schema.hotel (hotel_type)
SELECT 'business'
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.hotel WHERE hotel_type='business'
);

-- room
INSERT INTO hotel_schema.room (hotel_id, room_type_id, price)
SELECT h.hotel_id, 1, 100
FROM hotel_schema.hotel h
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.room WHERE room_type_id=1
);


--avoids duplicates using WHERE NOT EXISTS
--keeps referential integrity via joins

ALTER TABLE hotel_schema.customer 
ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;

-- repeat for all tables

--the database is normalized to 3NF, all non-key attributes depend only on primary key.
--constraints ensure data quality and prevent invalid inputs. foreign keys maintain referential integrity.
--using where not exists makes script rerunnable and avoids duplicates.

-- Data type risks:
-- using wrong data types can cause data loss or inconsistency.
-- for example:
-- using INT instead of NUMERIC for price would remove decimal precision
-- using VARCHAR instead of ENUM would allow invalid values
-- using small VARCHAR length may truncate data


-- CHECK constraints prevent invalid data:
-- chk_price_positive prevents negative prices, otherwise unrealistic values could be stored
-- chk_capacity_positive ensures room capacity is valid, otherwise zero/negative capacity possible
-- chk_booking_date prevents incorrect historical dates
-- chk_booking_time_order ensures logical time sequence

-- UNIQUE constraints:
-- prevent duplicate emails/phones, otherwise same user could be stored multiple times

-- NOT NULL constraints:
-- ensure required fields are always filled, otherwise incomplete records would exist






-- Insertıng data


-- HOTEL

INSERT INTO hotel_schema.hotel (hotel_num, hotel_type, location, description)
SELECT 'H001', 'business', 'Tbilisi', 'Business hotel in city center'
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.hotel WHERE hotel_num = 'H001'
);

INSERT INTO hotel_schema.hotel (hotel_num, hotel_type, location, description)
SELECT 'H002', 'luxury', 'Batumi', 'Luxury seaside hotel'
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.hotel WHERE hotel_num = 'H002'
);



-- CUSTOMER

INSERT INTO hotel_schema.customer (name, user_phone, user_email)
SELECT 'Ana Sarishvili', '555111222', 'ana@mail.com'
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.customer WHERE user_email = 'ana@mail.com'
);

INSERT INTO hotel_schema.customer (name, user_phone, user_email)
SELECT 'Nino Gelashvili', '555333444', 'nino@mail.com'
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.customer WHERE user_email = 'nino@mail.com'
);



-- ROOM

INSERT INTO hotel_schema.room (hotel_id, price, room_status, description_text, capacity)
SELECT h.hotel_id, 120, 'Available', 'Standard room', 2
FROM hotel_schema.hotel h
WHERE h.hotel_num = 'H001'
AND NOT EXISTS (
    SELECT 1 FROM hotel_schema.room 
    WHERE hotel_id = h.hotel_id AND description_text = 'Standard room'
);

INSERT INTO hotel_schema.room (hotel_id, price, room_status, description_text, capacity)
SELECT h.hotel_id, 250, 'Available', 'Luxury suite', 4
FROM hotel_schema.hotel h
WHERE h.hotel_num = 'H002'
AND NOT EXISTS (
    SELECT 1 FROM hotel_schema.room 
    WHERE hotel_id = h.hotel_id AND description_text = 'Luxury suite'
);



-- EMPLOYEE

INSERT INTO hotel_schema.employee (employee_role, employee_name, email, phone)
SELECT 'manager', 'Giorgi Manager', 'giorgi@hotel.com', '599111222'
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.employee WHERE email = 'giorgi@hotel.com'
);

INSERT INTO hotel_schema.employee (employee_role, employee_name, email, phone)
SELECT 'receptionist', 'Lika Reception', 'lika@hotel.com', '599333444'
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.employee WHERE email = 'lika@hotel.com'
);


-- BOOKING
INSERT INTO hotel_schema.booking (
    customer_id, room_id, booking_date, booking_in_time, booking_out_time, booking_status
)
SELECT 
    c.customer_id,
    r.room_id,
    CURRENT_DATE,
    '12:00',
    '14:00',
    'confirmed'
FROM hotel_schema.customer c
JOIN hotel_schema.room r ON r.capacity = 2
WHERE c.user_email = 'ana@mail.com'
AND NOT EXISTS (
    SELECT 1 FROM hotel_schema.booking 
    WHERE customer_id = c.customer_id AND room_id = r.room_id
);

INSERT INTO hotel_schema.booking (
    customer_id, room_id, booking_date, booking_in_time, booking_out_time, booking_status
)
SELECT 
    c.customer_id,
    r.room_id,
    CURRENT_DATE,
    '13:00',
    '15:00',
    'confirmed'
FROM hotel_schema.customer c
JOIN hotel_schema.room r ON r.capacity = 4
WHERE c.user_email = 'nino@mail.com'
AND NOT EXISTS (
    SELECT 1 FROM hotel_schema.booking 
    WHERE customer_id = c.customer_id AND room_id = r.room_id
);


-- EMPLOYEE_BOOKING
INSERT INTO hotel_schema.employee_booking (employee_id, booking_id, hours_worked)
SELECT e.employee_id, b.booking_id, 5
FROM hotel_schema.employee e
JOIN hotel_schema.booking b ON 1=1
WHERE e.employee_role = 'manager'
AND NOT EXISTS (
    SELECT 1 FROM hotel_schema.employee_booking 
    WHERE employee_id = e.employee_id AND booking_id = b.booking_id
);


-- PAYMENT
INSERT INTO hotel_schema.payment (booking_id, amount_paid, payment_status, payment_method)
SELECT b.booking_id, 200, 'complete', 'credit card'
FROM hotel_schema.booking b
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.payment WHERE booking_id = b.booking_id
);


-- INVOICE
INSERT INTO hotel_schema.invoice (booking_id, amount)
SELECT b.booking_id, 200
FROM hotel_schema.booking b
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.invoice WHERE booking_id = b.booking_id
);


-- REVIEW
INSERT INTO hotel_schema.review (booking_id, rating, comment)
SELECT b.booking_id, 5, 'Excellent stay'
FROM hotel_schema.booking b
WHERE NOT EXISTS (
    SELECT 1 FROM hotel_schema.review WHERE booking_id = b.booking_id
);


-- addıng record_ts

ALTER TABLE hotel_schema.hotel ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;
ALTER TABLE hotel_schema.room ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;
ALTER TABLE hotel_schema.customer ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;
ALTER TABLE hotel_schema.employee ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;
ALTER TABLE hotel_schema.booking ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;
ALTER TABLE hotel_schema.employee_booking ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;
ALTER TABLE hotel_schema.payment ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;
ALTER TABLE hotel_schema.invoice ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;
ALTER TABLE hotel_schema.review ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE NOT NULL;


SELECT hotel_id, record_ts FROM hotel_schema.hotel;


-- data is inserted using SELECT with WHERE NOT EXISTS to ensure the script is rerunnable and does not create duplicates.
-- primary keys are not hardcoded; instead, they are dynamically retrieved through joins.
-- this approach preserves referential integrity and ensures correct relationships between tables.
