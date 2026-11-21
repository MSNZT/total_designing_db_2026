CREATE OR REPLACE PROCEDURE erase_test_data()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM review;
    DELETE FROM payment;
    DELETE FROM order_structure;
    DELETE FROM courier_pay;
    DELETE FROM orders;
    DELETE FROM product;
    DELETE FROM product_category;
    DELETE FROM restaurant;
    DELETE FROM client_address;
    DELETE FROM courier;
    DELETE FROM client;
    DELETE FROM address;
END;
$$;