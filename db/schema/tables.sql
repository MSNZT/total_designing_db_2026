CREATE TABLE IF NOT EXISTS address (
    address_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    street VARCHAR(150) NOT NULL,
    house_number VARCHAR(20) NOT NULL,
    apartment_office VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS client (
    client_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    login VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(32) NOT NULL,
    phone_number VARCHAR(12) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS client_address (
    client_id UUID NOT NULL REFERENCES client(client_id),
    address_id UUID NOT NULL REFERENCES address(address_id),

    PRIMARY KEY(client_id, address_id)
);

CREATE TABLE IF NOT EXISTS restaurant (
    restaurant_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    restaurant_name VARCHAR(50) NOT NULL,
    address_id UUID NOT NULL REFERENCES address(address_id) UNIQUE,
    description TEXT NOT NULL,
    work_start TIME NOT NULL,
    work_end TIME NOT NULL CHECK(work_end > work_start),
    inn VARCHAR(12) NOT NULL,  
    ogrn VARCHAR(15) NOT NULL, 
    checking_account VARCHAR(20) NOT NULL, 
    rating NUMERIC(3,2) CHECK(rating between 0 and 5),
    status restaurant_status NOT NULL
);

CREATE TABLE IF NOT EXISTS courier (
    courier_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    fio VARCHAR(255) NOT NULL,
    phone_number VARCHAR(12) NOT NULL,
    status courier_status NOT NULL,
    hire_date DATE NOT NULL,
    dismissal_date DATE,
    coefficient NUMERIC(1, 1) NOT NULL CHECK(coefficient BETWEEN 0.1 AND 0.5) DEFAULT 0.1,

    CHECK (status <> 'уволен' or dismissal_date IS NOT NULL),
    CHECK (dismissal_date >= hire_date)   
);

CREATE TABLE IF NOT EXISTS courier_pay (
    year SMALLINT NOT NULL,
    month SMALLINT NOT NULL CHECK (month BETWEEN 1 AND 12),
    courier_id UUID NOT NULL REFERENCES courier(courier_id),
    amount NUMERIC(10, 2) NOT NULL CHECK(amount >= 0),
    coefficient_used NUMERIC(1, 1) NOT NULL CHECK(coefficient_used BETWEEN 0.1 AND 0.5),

    PRIMARY KEY(year, month, courier_id)        
);

CREATE TABLE IF NOT EXISTS orders (
    order_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    courier_id UUID NOT NULL REFERENCES courier(courier_id),
    client_id UUID NOT NULL REFERENCES client(client_id),
    address_id UUID NOT NULL REFERENCES address(address_id),
    restaurant_id UUID NOT NULL REFERENCES restaurant(restaurant_id),
    order_timestamp TIMESTAMP NOT NULL,
    delivery_timestamp TIMESTAMP CHECK(delivery_timestamp >= order_timestamp),
    order_amount NUMERIC(12,2) NOT NULL,
    commission NUMERIC(12,2) GENERATED ALWAYS AS (ROUND(order_amount * 0.10, 2)) STORED,
    total_amount NUMERIC(12,2) GENERATED ALWAYS AS (ROUND(order_amount * 1.10, 2)) STORED CHECK(total_amount >= 1000),
    status order_status NOT NULL,
    pay_status order_pay_status NOT NULL,
    description TEXT NOT NULL,

    CHECK (status <> 'доставлен' or delivery_timestamp is not null),
    FOREIGN KEY (client_id, address_id)
        REFERENCES client_address(client_id, address_id)
);

CREATE TABLE IF NOT EXISTS payment (
    payment_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(order_id),
    payment_type payment_type NOT NULL,
    status payment_status NOT NULL,
    transaction_id VARCHAR(255) NOT NULL UNIQUE,
    transaction_timestamp TIMESTAMP NOT NULL,
    amount numeric(12, 2) NOT NULL CHECK(amount >= 1000)
);

CREATE TABLE IF NOT EXISTS product_category (
    product_category_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    product_category_name VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS product (
    product_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    product_name VARCHAR(255) NOT NULL,
    product_category_id UUID NOT NULL REFERENCES product_category(product_category_id),
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    restaurant_id UUID NOT NULL REFERENCES restaurant(restaurant_id),
    photo_url TEXT,
    rating NUMERIC(3, 2) CHECK(rating BETWEEN 0 AND 5),
    status dish_status NOT NULL,
    description TEXT NOT NULL 
);

CREATE TABLE IF NOT EXISTS order_structure (
    order_id UUID NOT NULL REFERENCES orders(order_id),
    product_id UUID NOT NULL REFERENCES product(product_id),
    quantity NUMERIC NOT NULL CHECK (quantity > 0),

    PRIMARY KEY(order_id, product_id)
);

CREATE TABLE IF NOT EXISTS review (
    review_id UUID PRIMARY KEY default exts.uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES client(client_id),
    review_timestamp TIMESTAMP NOT NULL,
    entity_id UUID NOT NULL,
    entity_type entity_type NOT NULL,
    order_id UUID NOT NULL REFERENCES orders(order_id),
    description TEXT NOT NULL,
    photo_url TEXT,
    rating NUMERIC(3,2) NOT NULL CHECK(rating BETWEEN 1 AND 5),

    UNIQUE(order_id, entity_id, entity_type)
);