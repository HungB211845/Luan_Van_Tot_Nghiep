---
config:
  layout: elk
---

erDiagram
public_stores {
uuid id PK
text store_code
text store_name
text owner_name
text phone
text email
text address
text business_license
text tax_code
text subscription_type
timestamptz subscription_expires_at
boolean is_active
timestamptz created_at
timestamptz updated_at
uuid created_by
}
auth_users {
uuid id PK
}
public_test_connection {
integer id PK
text test_value
}
public_auth_audit_log {
uuid id PK
uuid user_id FK
uuid store_id FK
text event_type
inet ip_address
text user_agent
jsonb device_info
jsonb metadata
timestamptz created_at
}
public_banned_substances {
uuid id PK
text active_ingredient_name
date banned_date
text legal_document
text reason
boolean is_active
timestamptz created_at
}
public_companies {
uuid id PK
text name
text phone
text address
text contact_person
text note
timestamptz created_at
timestamptz updated_at
uuid store_id FK
boolean is_active
}
public_customers {
uuid id PK
text name
text phone
text address
numeric debt_limit
numeric interest_rate
text note
timestamptz created_at
timestamptz updated_at
uuid store_id FK
}
public_debts {
uuid id PK
uuid store_id FK
uuid customer_id FK
uuid transaction_id FK
numeric original_amount
numeric paid_amount
numeric remaining_amount
text status
date due_date
text notes
timestamptz created_at
timestamptz updated_at
}
public_debt_adjustments {
uuid id PK
uuid store_id FK
uuid debt_id FK
uuid customer_id FK
numeric adjustment_amount
text adjustment_type
text reason
numeric previous_amount
numeric new_amount
uuid created_by FK
timestamptz created_at
}
public_debt_payments {
uuid id PK
uuid store_id FK
uuid debt_id FK
uuid customer_id FK
numeric amount
text payment_method
text notes
timestamptz payment_date
uuid created_by FK
timestamptz created_at
}
public_employee_invitations {
uuid id PK
uuid store_id FK
text email
text full_name
uuid invited_by_user_id FK
text role
text phone
text status
text invitation_token
timestamptz expires_at
timestamptz accepted_at
timestamptz created_at
timestamptz updated_at
}
public_enhanced_user_sessions {
uuid id PK
uuid user_id FK
text device_id
text device_name
text device_type
text jwt_format_version
text refresh_token_hash
timestamptz created_at
timestamptz last_accessed_at
timestamptz expires_at
boolean is_active
}
public_inventory_adjustments {
uuid id PK
uuid batch_id FK
numeric quantity_change
text reason
varchar adjustment_type
timestamptz created_at
uuid user_id_who_adjusted
uuid store_id
text notes
}
public_password_reset_tokens {
uuid id PK
text email
text token
text token_type
timestamptz expires_at
boolean is_used
timestamptz used_at
timestamptz created_at
}
public_performance_logs {
uuid id PK
text query_type
bigint execution_time_ms
uuid store_id
uuid user_id
jsonb query_params
timestamptz created_at
}
public_price_change_reasons {
smallint id PK
text reason_code
text description
timestamptz created_at
}
public_price_history {
uuid id PK
uuid product_id FK
numeric new_price
numeric old_price
timestamptz changed_at
uuid user_id_who_changed
uuid store_id
text reason
timestamptz created_at
uuid changed_by
smallint reason_id FK
}
public_products {
uuid id PK
text sku
text name
text category
uuid company_id FK
jsonb attributes
boolean is_active
boolean is_banned
text image_url
text description
timestamptz created_at
timestamptz updated_at
text npk_ratio
text active_ingredient
text seed_strain
tsvector search_vector
uuid store_id FK
integer min_stock_level
numeric current_selling_price
text base_unit
}
public_product_units {
uuid id PK
uuid product_id FK
text unit_name
numeric conversion_factor
numeric unit_price
boolean is_default_selling_unit
boolean is_active
uuid store_id FK
timestamptz created_at
timestamptz updated_at
}
public_product_batches {
uuid id PK
uuid product_id FK
text batch_number
integer quantity
numeric cost_price
date received_date
date expiry_date
text supplier_batch_id
text notes
boolean is_available
timestamptz created_at
timestamptz updated_at
uuid purchase_order_id FK
uuid supplier_id FK
uuid store_id FK
integer sales_count
boolean is_deleted
}
public_product_prices {
uuid id PK
uuid product_id
numeric selling_price
numeric cost
timestamptz effective_date
boolean is_active
text reason
timestamptz created_at
}
public_purchase_orders {
uuid id PK
uuid supplier_id FK
text po_number
date order_date
date expected_delivery_date
date delivery_date
text status
numeric subtotal
numeric tax_amount
numeric total_amount
numeric discount_amount
text payment_terms
text notes
text created_by
timestamptz created_at
timestamptz updated_at
uuid store_id FK
}
public_purchase_order_items {
uuid id PK
uuid purchase_order_id FK
uuid product_id FK
integer quantity
numeric unit_cost
numeric total_cost
integer received_quantity
text notes
timestamptz created_at
text unit
uuid store_id FK
numeric selling_price
}
public_seasonal_prices {
uuid id PK
uuid product_id FK
numeric selling_price
text season_name
date start_date
date end_date
boolean is_active
numeric markup_percentage
text notes
timestamptz created_at
uuid store_id FK
}
public_store_business_info {
uuid id PK
uuid store_id FK
varchar tax_code
varchar business_name
varchar tax_authority
text business_address
varchar phone_number
varchar email
varchar bank_account
varchar bank_name
varchar legal_representative
timestamptz validated_at
varchar validation_source
timestamptz created_at
timestamptz updated_at
varchar invoice_symbol
varchar invoice_template_code
varchar bank_branch
numeric default_vat_rate
varchar website
varchar logo_url
}
public_transactions {
uuid id PK
uuid customer_id FK
numeric total_amount
timestamptz transaction_date
boolean is_debt
text payment_method
text notes
text invoice_number
text created_by
timestamptz created_at
uuid store_id FK
numeric surcharge_amount
}
public_transaction_items {
uuid id PK
uuid transaction_id FK
uuid product_id FK
uuid batch_id FK
integer quantity
numeric price_at_sale
numeric sub_total
numeric discount_amount
timestamptz created_at
uuid store_id FK
uuid unit_id FK
text unit_name
numeric unit_conversion_factor
numeric base_unit_quantity
}
public_user_profiles {
uuid id PK
uuid store_id FK
text full_name
text phone
text avatar_url
text role
jsonb permissions
text google_id
text facebook_id
text zalo_id
boolean is_active
timestamptz last_login_at
timestamptz created_at
timestamptz updated_at
boolean biometric_enabled
jsonb quick_access_config
}
public_user_sessions {
uuid id PK
uuid user_id FK
text device_id
text device_name
text device_type
text fcm_token
boolean is_biometric_enabled
timestamptz last_accessed_at
timestamptz expires_at
timestamptz created_at
}
public_v_default_unit {
uuid id
numeric conversion_factor
}
public_v_store_id {
uuid store_id
}
public_stores ||--o{ public_companies : store_id
public_stores ||--o{ public_customers : store_id
public_stores ||--o{ public_debts : store_id
public_stores ||--o{ public_product_units : store_id
public_stores ||--o{ public_product_batches : store_id
public_stores ||--o{ public_purchase_orders : store_id
public_stores ||--o{ public_purchase_order_items : store_id
public_stores ||--o{ public_seasonal_prices : store_id
public_stores ||--o{ public_transactions : store_id
public_stores ||--o{ public_transaction_items : store_id
public_stores ||--o{ public_user_profiles : store_id
auth_users ||--o{ public_auth_audit_log : user_id
public_stores ||--o{ public_auth_audit_log : store_id
public_customers ||--o{ public_transactions : customer_id
public_transactions ||--o{ public_debts : transaction_id
public_customers ||--o{ public_debts : customer_id
public_debts ||--o{ public_debt_adjustments : debt_id
public_customers ||--o{ public_debt_adjustments : customer_id
public_stores ||--o{ public_debt_adjustments : store_id
auth_users ||--o{ public_debt_adjustments : created_by
public_debts ||--o{ public_debt_payments : debt_id
public_customers ||--o{ public_debt_payments : customer_id
public_stores ||--o{ public_debt_payments : store_id
auth_users ||--o{ public_debt_payments : created_by
public_stores ||--o{ public_employee_invitations : store_id
auth_users ||--o{ public_employee_invitations : invited_by_user_id
auth_users ||--o{ public_enhanced_user_sessions : user_id
public_products ||--o{ public_price_history : product_id
auth_users ||--o{ public_price_history : changed_by
public_price_change_reasons ||--o{ public_price_history : reason_id
public_companies ||--o{ public_products : company_id
public_stores ||--o{ public_products : store_id
public_products ||--o{ public_product_units : product_id
public_companies ||--o{ public_purchase_orders : supplier_id
public_purchase_orders ||--o{ public_purchase_order_items : purchase_order_id
public_products ||--o{ public_purchase_order_items : product_id
public_products ||--o{ public_product_batches : product_id
public_purchase_orders ||--o{ public_product_batches : purchase_order_id
public_companies ||--o{ public_product_batches : supplier_id
public_products ||--o{ public_seasonal_prices : product_id
public_stores ||--|| public_store_business_info : store_id
public_transactions ||--o{ public_transaction_items : transaction_id
public_products ||--o{ public_transaction_items : product_id
public_product_batches ||--o{ public_transaction_items : batch_id
public_product_units ||--o{ public_transaction_items : unit_id
auth_users ||--o{ public_user_profiles : id
auth_users ||--o{ public_user_sessions : user_id
