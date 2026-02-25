-- Admin Center Development Seed Data
-- Version: 001
-- Description: Inserts test data for development and testing purposes
-- Requirements: 17, 11
-- WARNING: This script is for DEVELOPMENT ONLY. Do not run in production!

-- ============================================================================
-- TEST USERS
-- ============================================================================
-- Insert test users with different subscription tiers

-- Ensure test users exist (create if they don't)
INSERT INTO users (email, name, email_verified, created_at, updated_at)
VALUES 
  ('test.free@example.com', 'Free Tier User', true, NOW() - INTERVAL '90 days', NOW()),
  ('test.premium@example.com', 'Premium Tier User', true, NOW() - INTERVAL '60 days', NOW()),
  ('test.enterprise@example.com', 'Enterprise Tier User', true, NOW() - INTERVAL '120 days', NOW()),
  ('test.trial@example.com', 'Trial User', true, NOW() - INTERVAL '5 days', NOW()),
  ('test.canceled@example.com', 'Canceled User', true, NOW() - INTERVAL '180 days', NOW())
ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- TEST SUBSCRIPTIONS
-- ============================================================================
-- Insert test subscriptions for different tiers and statuses

-- Free tier subscription (active)
INSERT INTO subscriptions (
  user_id, 
  stripe_subscription_id, 
  stripe_customer_id, 
  tier, 
  status, 
  current_period_start, 
  current_period_end,
  created_at,
  updated_at
)
SELECT 
  id,
  'sub_test_free_' || substring(id::text, 1, 8),
  'cus_test_free_' || substring(id::text, 1, 8),
  'free',
  'active',
  NOW() - INTERVAL '15 days',
  NOW() + INTERVAL '15 days',
  NOW() - INTERVAL '90 days',
  NOW()
FROM users WHERE email = 'test.free@example.com'
ON CONFLICT (stripe_subscription_id) DO NOTHING;

-- Premium tier subscription (active)
INSERT INTO subscriptions (
  user_id, 
  stripe_subscription_id, 
  stripe_customer_id, 
  tier, 
  status, 
  current_period_start, 
  current_period_end,
  created_at,
  updated_at
)
SELECT 
  id,
  'sub_test_premium_' || substring(id::text, 1, 8),
  'cus_test_premium_' || substring(id::text, 1, 8),
  'premium',
  'active',
  NOW() - INTERVAL '10 days',
  NOW() + INTERVAL '20 days',
  NOW() - INTERVAL '60 days',
  NOW()
FROM users WHERE email = 'test.premium@example.com'
ON CONFLICT (stripe_subscription_id) DO NOTHING;

-- Enterprise tier subscription (active)
INSERT INTO subscriptions (
  user_id, 
  stripe_subscription_id, 
  stripe_customer_id, 
  tier, 
  status, 
  current_period_start, 
  current_period_end,
  created_at,
  updated_at
)
SELECT 
  id,
  'sub_test_enterprise_' || substring(id::text, 1, 8),
  'cus_test_enterprise_' || substring(id::text, 1, 8),
  'enterprise',
  'active',
  NOW() - INTERVAL '5 days',
  NOW() + INTERVAL '25 days',
  NOW() - INTERVAL '120 days',
  NOW()
FROM users WHERE email = 'test.enterprise@example.com'
ON CONFLICT (stripe_subscription_id) DO NOTHING;

-- Trial subscription (trialing)
INSERT INTO subscriptions (
  user_id, 
  stripe_subscription_id, 
  stripe_customer_id, 
  tier, 
  status,
  trial_start,
  trial_end,
  current_period_start, 
  current_period_end,
  created_at,
  updated_at
)
SELECT 
  id,
  'sub_test_trial_' || substring(id::text, 1, 8),
  'cus_test_trial_' || substring(id::text, 1, 8),
  'premium',
  'trialing',
  NOW() - INTERVAL '5 days',
  NOW() + INTERVAL '9 days',
  NOW() - INTERVAL '5 days',
  NOW() + INTERVAL '25 days',
  NOW() - INTERVAL '5 days',
  NOW()
FROM users WHERE email = 'test.trial@example.com'
ON CONFLICT (stripe_subscription_id) DO NOTHING;

-- Canceled subscription
INSERT INTO subscriptions (
  user_id, 
  stripe_subscription_id, 
  stripe_customer_id, 
  tier, 
  status,
  cancel_at_period_end,
  canceled_at,
  current_period_start, 
  current_period_end,
  created_at,
  updated_at
)
SELECT 
  id,
  'sub_test_canceled_' || substring(id::text, 1, 8),
  'cus_test_canceled_' || substring(id::text, 1, 8),
  'premium',
  'canceled',
  true,
  NOW() - INTERVAL '30 days',
  NOW() - INTERVAL '60 days',
  NOW() - INTERVAL '30 days',
  NOW() - INTERVAL '30 days',
  NOW() - INTERVAL '180 days'
FROM users WHERE email = 'test.canceled@example.com'
ON CONFLICT (stripe_subscription_id) DO NOTHING;

-- ============================================================================
-- TEST PAYMENT TRANSACTIONS
-- ============================================================================
-- Insert test payment transactions with various statuses

-- Successful payment for premium user
INSERT INTO payment_transactions (
  user_id,
  subscription_id,
  stripe_payment_intent_id,
  stripe_charge_id,
  amount,
  currency,
  status,
  payment_method_type,
  payment_method_last4,
  receipt_url,
  created_at,
  updated_at
)
SELECT 
  u.id,
  s.id,
  'pi_test_success_' || substring(u.id::text, 1, 8),
  'ch_test_success_' || substring(u.id::text, 1, 8),
  29.99,
  'USD',
  'succeeded',
  'card',
  '4242',
  'https://stripe.com/receipts/test_' || substring(u.id::text, 1, 8),
  NOW() - INTERVAL '10 days',
  NOW() - INTERVAL '10 days'
FROM users u
JOIN subscriptions s ON s.user_id = u.id
WHERE u.email = 'test.premium@example.com'
ON CONFLICT (stripe_payment_intent_id) DO NOTHING;

-- Successful payment for enterprise user
INSERT INTO payment_transactions (
  user_id,
  subscription_id,
  stripe_payment_intent_id,
  stripe_charge_id,
  amount,
  currency,
  status,
  payment_method_type,
  payment_method_last4,
  receipt_url,
  created_at,
  updated_at
)
SELECT 
  u.id,
  s.id,
  'pi_test_enterprise_' || substring(u.id::text, 1, 8),
  'ch_test_enterprise_' || substring(u.id::text, 1, 8),
  99.99,
  'USD',
  'succeeded',
  'card',
  '5555',
  'https://stripe.com/receipts/test_ent_' || substring(u.id::text, 1, 8),
  NOW() - INTERVAL '5 days',
  NOW() - INTERVAL '5 days'
FROM users u
JOIN subscriptions s ON s.user_id = u.id
WHERE u.email = 'test.enterprise@example.com'
ON CONFLICT (stripe_payment_intent_id) DO NOTHING;

-- Failed payment
INSERT INTO payment_transactions (
  user_id,
  subscription_id,
  stripe_payment_intent_id,
  amount,
  currency,
  status,
  payment_method_type,
  payment_method_last4,
  failure_code,
  failure_message,
  created_at,
  updated_at
)
SELECT 
  u.id,
  s.id,
  'pi_test_failed_' || substring(u.id::text, 1, 8),
  29.99,
  'USD',
  'failed',
  'card',
  '0002',
  'card_declined',
  'Your card was declined',
  NOW() - INTERVAL '3 days',
  NOW() - INTERVAL '3 days'
FROM users u
JOIN subscriptions s ON s.user_id = u.id
WHERE u.email = 'test.premium@example.com'
ON CONFLICT (stripe_payment_intent_id) DO NOTHING;

-- Pending payment
INSERT INTO payment_transactions (
  user_id,
  subscription_id,
  stripe_payment_intent_id,
  amount,
  currency,
  status,
  payment_method_type,
  payment_method_last4,
  created_at,
  updated_at
)
SELECT 
  u.id,
  s.id,
  'pi_test_pending_' || substring(u.id::text, 1, 8),
  29.99,
  'USD',
  'pending',
  'card',
  '4242',
  NOW() - INTERVAL '1 hour',
  NOW() - INTERVAL '1 hour'
FROM users u
JOIN subscriptions s ON s.user_id = u.id
WHERE u.email = 'test.premium@example.com'
ON CONFLICT (stripe_payment_intent_id) DO NOTHING;

-- Refunded payment (will be linked to refund below)
INSERT INTO payment_transactions (
  user_id,
  subscription_id,
  stripe_payment_intent_id,
  stripe_charge_id,
  amount,
  currency,
  status,
  payment_method_type,
  payment_method_last4,
  receipt_url,
  created_at,
  updated_at
)
SELECT 
  u.id,
  s.id,
  'pi_test_refunded_' || substring(u.id::text, 1, 8),
  'ch_test_refunded_' || substring(u.id::text, 1, 8),
  29.99,
  'USD',
  'refunded',
  'card',
  '4242',
  'https://stripe.com/receipts/test_refund_' || substring(u.id::text, 1, 8),
  NOW() - INTERVAL '45 days',
  NOW() - INTERVAL '30 days'
FROM users u
JOIN subscriptions s ON s.user_id = u.id
WHERE u.email = 'test.canceled@example.com'
ON CONFLICT (stripe_payment_intent_id) DO NOTHING;

-- ============================================================================
-- TEST PAYMENT METHODS
-- ============================================================================
-- Insert test payment methods for users

-- Payment method for premium user
INSERT INTO payment_methods (
  user_id,
  stripe_payment_method_id,
  type,
  card_brand,
  card_last4,
  card_exp_month,
  card_exp_year,
  billing_email,
  billing_name,
  is_default,
  status,
  created_at,
  updated_at
)
SELECT 
  id,
  'pm_test_premium_' || substring(id::text, 1, 8),
  'card',
  'visa',
  '4242',
  12,
  2025,
  email,
  name,
  true,
  'active',
  NOW() - INTERVAL '60 days',
  NOW()
FROM users WHERE email = 'test.premium@example.com'
ON CONFLICT (stripe_payment_method_id) DO NOTHING;

-- Payment method for enterprise user
INSERT INTO payment_methods (
  user_id,
  stripe_payment_method_id,
  type,
  card_brand,
  card_last4,
  card_exp_month,
  card_exp_year,
  billing_email,
  billing_name,
  is_default,
  status,
  created_at,
  updated_at
)
SELECT 
  id,
  'pm_test_enterprise_' || substring(id::text, 1, 8),
  'card',
  'mastercard',
  '5555',
  6,
  2026,
  email,
  name,
  true,
  'active',
  NOW() - INTERVAL '120 days',
  NOW()
FROM users WHERE email = 'test.enterprise@example.com'
ON CONFLICT (stripe_payment_method_id) DO NOTHING;

-- Expired payment method
INSERT INTO payment_methods (
  user_id,
  stripe_payment_method_id,
  type,
  card_brand,
  card_last4,
  card_exp_month,
  card_exp_year,
  billing_email,
  billing_name,
  is_default,
  status,
  created_at,
  updated_at
)
SELECT 
  id,
  'pm_test_expired_' || substring(id::text, 1, 8),
  'card',
  'visa',
  '1234',
  12,
  2023,
  email,
  name,
  false,
  'expired',
  NOW() - INTERVAL '180 days',
  NOW() - INTERVAL '60 days'
FROM users WHERE email = 'test.canceled@example.com'
ON CONFLICT (stripe_payment_method_id) DO NOTHING;

-- ============================================================================
-- TEST REFUNDS
-- ============================================================================
-- Insert test refund for the refunded transaction

INSERT INTO refunds (
  transaction_id,
  stripe_refund_id,
  amount,
  currency,
  reason,
  reason_details,
  status,
  admin_user_id,
  created_at,
  updated_at
)
SELECT 
  pt.id,
  're_test_refund_' || substring(pt.id::text, 1, 8),
  29.99,
  'USD',
  'customer_request',
  'Customer requested refund due to service not meeting expectations',
  'succeeded',
  admin_u.id,
  NOW() - INTERVAL '30 days',
  NOW() - INTERVAL '30 days'
FROM payment_transactions pt
JOIN users u ON pt.user_id = u.id
LEFT JOIN users admin_u ON admin_u.email = 'cmaltais@cloudtolocalllm.online'
WHERE u.email = 'test.canceled@example.com'
  AND pt.stripe_payment_intent_id LIKE 'pi_test_refunded_%'
ON CONFLICT (stripe_refund_id) DO NOTHING;

-- ============================================================================
-- ADMIN ROLES
-- ============================================================================
-- Insert admin role for cmaltais@cloudtolocalllm.online (Super Admin)
-- This is also done in the migration, but we ensure it here as well

INSERT INTO admin_roles (user_id, role, is_active, granted_at)
SELECT id, 'super_admin', true, NOW() - INTERVAL '180 days'
FROM users
WHERE email = 'cmaltais@cloudtolocalllm.online'
ON CONFLICT (user_id, role) DO UPDATE SET is_active = true;

-- Insert test support admin
INSERT INTO users (email, name, email_verified, created_at, updated_at)
VALUES 
  ('test.support@example.com', 'Support Admin', true, NOW() - INTERVAL '90 days', NOW())
ON CONFLICT (email) DO NOTHING;

INSERT INTO admin_roles (user_id, role, is_active, granted_by, granted_at)
SELECT 
  u.id, 
  'support_admin', 
  true,
  admin_u.id,
  NOW() - INTERVAL '90 days'
FROM users u
CROSS JOIN users admin_u
WHERE u.email = 'test.support@example.com'
  AND admin_u.email = 'cmaltais@cloudtolocalllm.online'
ON CONFLICT (user_id, role) DO UPDATE SET is_active = true;

-- Insert test finance admin
INSERT INTO users (email, name, email_verified, created_at, updated_at)
VALUES 
  ('test.finance@example.com', 'Finance Admin', true, NOW() - INTERVAL '60 days', NOW())
ON CONFLICT (email) DO NOTHING;

INSERT INTO admin_roles (user_id, role, is_active, granted_by, granted_at)
SELECT 
  u.id, 
  'finance_admin', 
  true,
  admin_u.id,
  NOW() - INTERVAL '60 days'
FROM users u
CROSS JOIN users admin_u
WHERE u.email = 'test.finance@example.com'
  AND admin_u.email = 'cmaltais@cloudtolocalllm.online'
ON CONFLICT (user_id, role) DO UPDATE SET is_active = true;

-- ============================================================================
-- TEST ADMIN AUDIT LOGS
-- ============================================================================
-- Insert sample audit log entries

-- Subscription upgrade log
INSERT INTO admin_audit_logs (
  admin_user_id,
  admin_role,
  action,
  resource_type,
  resource_id,
  affected_user_id,
  details,
  ip_address,
  user_agent,
  created_at
)
SELECT 
  admin_u.id,
  'super_admin',
  'subscription_upgraded',
  'subscription',
  s.id::text,
  u.id,
  jsonb_build_object(
    'previous_tier', 'free',
    'new_tier', 'premium',
    'reason', 'Customer support request'
  ),
  '192.168.1.100'::inet,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  NOW() - INTERVAL '60 days'
FROM users u
JOIN subscriptions s ON s.user_id = u.id
CROSS JOIN users admin_u
WHERE u.email = 'test.premium@example.com'
  AND admin_u.email = 'cmaltais@cloudtolocalllm.online';

-- Refund processed log
INSERT INTO admin_audit_logs (
  admin_user_id,
  admin_role,
  action,
  resource_type,
  resource_id,
  affected_user_id,
  details,
  ip_address,
  user_agent,
  created_at
)
SELECT 
  admin_u.id,
  'super_admin',
  'refund_processed',
  'transaction',
  pt.id::text,
  u.id,
  jsonb_build_object(
    'amount', 29.99,
    'currency', 'USD',
    'reason', 'customer_request',
    'reason_details', 'Customer requested refund due to service not meeting expectations'
  ),
  '192.168.1.100'::inet,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  NOW() - INTERVAL '30 days'
FROM users u
JOIN payment_transactions pt ON pt.user_id = u.id
CROSS JOIN users admin_u
WHERE u.email = 'test.canceled@example.com'
  AND pt.stripe_payment_intent_id LIKE 'pi_test_refunded_%'
  AND admin_u.email = 'cmaltais@cloudtolocalllm.online';

-- Admin role granted log
INSERT INTO admin_audit_logs (
  admin_user_id,
  admin_role,
  action,
  resource_type,
  resource_id,
  affected_user_id,
  details,
  ip_address,
  user_agent,
  created_at
)
SELECT 
  admin_u.id,
  'super_admin',
  'admin_role_granted',
  'admin_role',
  support_u.id::text,
  support_u.id,
  jsonb_build_object(
    'role', 'support_admin',
    'granted_by', admin_u.email
  ),
  '192.168.1.100'::inet,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  NOW() - INTERVAL '90 days'
FROM users support_u
CROSS JOIN users admin_u
WHERE support_u.email = 'test.support@example.com'
  AND admin_u.email = 'cmaltais@cloudtolocalllm.online';

-- ============================================================================
-- SEED DATA COMPLETE
-- ============================================================================
-- Development seed data inserted successfully
-- Test users: 5 (free, premium, enterprise, trial, canceled)
-- Test subscriptions: 5 (various tiers and statuses)
-- Test transactions: 5 (succeeded, failed, pending, refunded)
-- Test payment methods: 3 (active and expired)
-- Test refunds: 1
-- Admin roles: 3 (super admin, support admin, finance admin)
-- Audit logs: 3 sample entries

-- Summary query to verify data
SELECT 
  'Users' as entity, COUNT(*) as count FROM users WHERE email LIKE 'test.%@example.com'
UNION ALL
SELECT 'Subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'Transactions', COUNT(*) FROM payment_transactions
UNION ALL
SELECT 'Payment Methods', COUNT(*) FROM payment_methods
UNION ALL
SELECT 'Refunds', COUNT(*) FROM refunds
UNION ALL
SELECT 'Admin Roles', COUNT(*) FROM admin_roles
UNION ALL
SELECT 'Audit Logs', COUNT(*) FROM admin_audit_logs;