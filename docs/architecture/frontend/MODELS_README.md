# Data Models

This directory contains all data models used throughout the CloudToLocalLLM application.

## Admin Center Models

Models for the Admin Center feature (user management, subscriptions, payments):

### subscription_model.dart
**Purpose:** Represents user subscription information including tier, status, and billing periods

**Key Features:**
- Subscription tier management (free, premium, enterprise)
- Status tracking (active, canceled, past_due, trialing, incomplete)
- Billing period information (current period start/end)
- Trial period support
- Stripe integration (subscription ID, customer ID)
- Cancellation tracking
- Days remaining calculation
- JSON serialization with snake_case and camelCase support

**Enums:**
- `SubscriptionTier`: free, premium, enterprise
- `SubscriptionStatus`: active, canceled, past_due, trialing, incomplete

**Usage:**
```dart
// Parse from API response
final subscription = SubscriptionModel.fromJson(jsonData);

// Check subscription status
if (subscription.isActive) {
  print('Days remaining: ${subscription.daysRemaining}');
}

// Update subscription
final updated = subscription.copyWith(
  tier: SubscriptionTier.premium,
  status: SubscriptionStatus.active,
);
```

### payment_transaction_model.dart
**Purpose:** Represents payment transactions with Stripe integration

**Key Features:**
- Transaction status tracking
- Payment method details (type, last 4 digits)
- Stripe PaymentIntent and Charge IDs
- Failure tracking (code, message)
- Receipt URL
- Refund information

### refund_model.dart
**Purpose:** Represents refund records for payment transactions

**Key Features:**
- Refund reason tracking
- Status monitoring
- Admin user tracking
- Stripe refund ID

### admin_role_model.dart
**Purpose:** Represents administrator role assignments

**Key Features:**
- Role types (super_admin, support_admin, finance_admin)
- Permission management
- Grant/revoke tracking
- Active status

### admin_audit_log_model.dart
**Purpose:** Represents audit trail entries for administrative actions

**Key Features:**
- Action tracking
- Resource identification
- Admin user tracking
- IP address and user agent logging
- Detailed action context

## Core Application Models

### user_model.dart
**Purpose:** Represents user account information

**Key Features:**
- Auth0 integration
- Profile information
- Suspension tracking
- Account status

### session_model.dart
**Purpose:** Represents user session information

**Key Features:**
- Session token management
- Expiration tracking
- Activity monitoring
- IP address and user agent

## Chat & LLM Models

### chat_model.dart
**Purpose:** Represents chat configuration and settings

### conversation.dart
**Purpose:** Represents a conversation thread

### message.dart
**Purpose:** Represents individual chat messages

### streaming_message.dart
**Purpose:** Represents streaming message chunks

### llm_model.dart
**Purpose:** Represents LLM model information

### prompt_template_model.dart
**Purpose:** Represents prompt templates

## Configuration Models

### platform_config.dart
**Purpose:** Platform-specific configuration

### provider_configuration.dart
**Purpose:** LLM provider configuration

### tunnel_config.dart
**Purpose:** SSH tunnel configuration

### tunnel_state.dart
**Purpose:** Tunnel connection state

## Error Models

### llm_communication_error.dart
**Purpose:** LLM communication error details

### ollama_connection_error.dart
**Purpose:** Ollama-specific connection errors

## Validation Models

### validation_result.dart
**Purpose:** Generic validation results

### validation_test.dart
**Purpose:** Individual validation test results

### tunnel_validation_result.dart
**Purpose:** Tunnel-specific validation results

## Installation Models

### installation_step.dart
**Purpose:** Installation wizard step information

### download_option.dart
**Purpose:** Download configuration options

### container_creation_result.dart
**Purpose:** Container creation results

### user_setup_status.dart
**Purpose:** User setup progress tracking

## Model Conventions

### JSON Serialization
- All models support `fromJson()` factory constructor
- All models support `toJson()` method
- Support both snake_case (API) and camelCase (frontend) field names
- Null-safe parsing with fallback values

### Immutability
- All models are immutable (final fields)
- Use `copyWith()` method for updates
- Const constructors where possible

### Equality
- Override `==` operator for value equality
- Override `hashCode` for proper hash-based collections
- Use `id` field for equality when available

### String Representation
- Override `toString()` for debugging
- Include key identifying fields

### Enums
- Use enums for fixed value sets
- Include `value` field for serialization
- Include `displayName` getter for UI
- Include `fromString()` static method for parsing

## Best Practices

1. **Always validate input**: Use null-safe parsing with fallback values
2. **Support multiple formats**: Handle both snake_case and camelCase
3. **Include helper methods**: Add convenience getters and methods
4. **Document thoroughly**: Include doc comments for all public APIs
5. **Test serialization**: Ensure round-trip JSON serialization works
6. **Use enums**: Prefer enums over string constants for fixed values
7. **Keep models simple**: Models should only contain data, no business logic

## Related Documentation

- [Admin Center Design](../../.kiro/specs/admin-center/design.md)
- [Admin Center Requirements](../../.kiro/specs/admin-center/requirements.md)
- [Admin API Documentation](../../docs/API/ADMIN_API.md)
- [Backend Services](../../services/api-backend/README.md)


## Related Services

These models are used by the following services:

### PaymentGatewayService ✅ IMPLEMENTED
- **Location**: `lib/services/payment_gateway_service.dart`
- **Purpose**: Payment processing and transaction management
- **Models Used**:
  - `PaymentTransactionModel` - Transaction data
  - `SubscriptionModel` - Subscription information
  - `RefundModel` - Refund records
- **Features**:
  - Real-time transaction management
  - Subscription lifecycle operations
  - Refund processing with admin auth
  - Payment method management

### Future Services 📋 PLANNED

#### SubscriptionManagementService
- Subscription lifecycle management
- Tier upgrades/downgrades
- Cancellation handling
- **Models**: `SubscriptionModel`, `PaymentTransactionModel`

#### UserManagementService
- User administration
- Role assignment
- Account suspension
- **Models**: `AdminRoleModel`, `AdminAuditLogModel`

#### AuditLogService
- Audit trail viewing
- Action filtering
- Export functionality
- **Models**: `AdminAuditLogModel`

#### DashboardService
- Dashboard metrics
- Analytics aggregation
- Real-time updates
- **Models**: All models for aggregated data

## Service Integration

Models are designed to work seamlessly with services:

```dart
// Service fetches data from API
final service = locator<PaymentGatewayService>();
await service.fetchTransactions();

// Models are automatically parsed from JSON
final transactions = service.transactions; // List<PaymentTransactionModel>

// Models provide type-safe access
for (final transaction in transactions) {
  print('Amount: ${transaction.amount}');
  print('Status: ${transaction.status.displayName}');
}
```

For more information about services, see [Services Documentation](../services/README.md).
