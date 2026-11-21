CREATE TRIGGER trg_order_structures_validate_restaurant
BEFORE INSERT OR UPDATE OF order_id, product_id ON order_structure
FOR EACH ROW
EXECUTE FUNCTION tf_order_structures_validate_restaurant();

CREATE TRIGGER trg_product_validate_restaurant
BEFORE UPDATE OF restaurant_id ON product
FOR EACH ROW
EXECUTE FUNCTION tf_product_validate_restaurant();

CREATE TRIGGER trg_order_validate_restaurant
BEFORE UPDATE OF restaurant_id ON orders
FOR EACH ROW
EXECUTE FUNCTION tf_order_validate_restaurant();

CREATE OR REPLACE TRIGGER trg_validate_payment_total_amount
BEFORE INSERT OR UPDATE OF amount, order_id ON payment
FOR EACH ROW
EXECUTE FUNCTION tf_payment_validate_amount();

CREATE OR REPLACE TRIGGER trg_orders_validate_amount
AFTER UPDATE OF order_amount ON orders
FOR EACH ROW
EXECUTE FUNCTION tf_orders_validate_amount();

CREATE OR REPLACE TRIGGER trg_payments_update_order_pay_status
AFTER INSERT OR UPDATE OF status, order_id OR DELETE ON payment
FOR EACH ROW
EXECUTE FUNCTION tf_payment_update_order_pay_status();

CREATE OR REPLACE TRIGGER trg_reviews_validate_entity
BEFORE INSERT OR UPDATE OF client_id, order_id, entity_id, entity_type ON review
FOR EACH ROW
EXECUTE FUNCTION tf_review_validate_entity();

CREATE OR REPLACE TRIGGER trg_rating_change
AFTER INSERT OR UPDATE OR DELETE ON review
FOR EACH ROW
EXECUTE FUNCTION rating_change();