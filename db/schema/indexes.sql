CREATE UNIQUE INDEX idx_payment_success_status ON payment (order_id) 
WHERE status = 'успех';