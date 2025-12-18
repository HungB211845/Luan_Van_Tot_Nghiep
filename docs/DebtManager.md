Đặc Tả Kỹ Thuật: Module Quản Lý Công Nợ (Debt Management)

> **Template Version**: 1.0  
> **Last Updated**: January 2025  
> **Implementation Status**: 88% Complete  
> **Multi-Tenant Ready**: ✅  
> **Responsive Design**: 🔶

# 1. Tổng Quan

### a. Business Purpose
Module Quản lý Công Nợ (Debt Management) xử lý việc bán chịu, thanh toán công nợ và điều chỉnh nợ trong hệ thống AgriPOS. Module này đảm bảo financial accuracy và provides comprehensive debt tracking cho business operations.

### b. Key Features
- **Credit Sale Integration**: Seamless credit sales từ [POS System](./POS_specs.md)
- **Payment Processing**: Multi-method payments với overpayment prevention
- **FIFO Distribution**: Automatic payment allocation cho oldest debts first
- **Debt Adjustments**: Manual adjustments với comprehensive audit trail
- **Customer Integration**: Complete integration với [Customer Management](./Customer_specs.md)
- **Analytics**: Debt aging, collection efficiency, customer insights

### c. Architecture Compliance
- **3-Layer Pattern**: UI → Provider → Service với RPC-backed operations
- **Multi-Tenant**: Store isolation với RLS policies và BaseService
- **Atomic Operations**: Database-level transaction integrity

---

**Related Documentation**: 
- [POS System Specs](./POS_specs.md) - Credit sale workflow và debt creation
- [Customer Management Specs](./Customer_specs.md) - Customer selection và debt tracking
- [Architecture Overview](./architecture.md) - Multi-tenant security patterns

**Implementation Files**:
- Models: `lib/features/debt/models/`
- Services: `lib/features/debt/services/debt_service.dart`  
- Providers: `lib/features/debt/providers/debt_provider.dart`
- Screens: `lib/features/debt/screens/` (planned)
- RPC Functions: `supabase/migrations/20250930000000_debt_management_system.sql`

---

# 2. Implementation Status & Codebase Hiện Tại

### ✅ **ĐÃ IMPLEMENTED (VERIFIED)**

**Models**: `lib/features/debt/models/`
- ✅ `debt.dart` - Core debt entity với status tracking
- ✅ `debt_status.dart` - Enum: pending, partial, paid, overdue, cancelled
- ✅ `debt_payment.dart` - Payment transaction records
- ✅ `debt_adjustment.dart` - Manual adjustments với audit trail

**Provider**: `lib/features/debt/providers/debt_provider.dart`
- ✅ Complete state management với error handling
- ✅ Integration với POS workflow
- ✅ Master-detail view support cho customer selection

**Service**: `lib/features/debt/services/debt_service.dart`  
- ✅ Extends BaseService cho store isolation
- ✅ RPC integration với verified function signatures
- ✅ Comprehensive error handling

**Database**: `supabase/migrations/20250930000000_debt_management_system.sql`
- ✅ Complete schema với constraints và indexes
- ✅ RLS policies cho multi-tenant security
- ✅ Verified RPC functions với exact signatures

---

# 3. Database Schema & RPC Functions (VERIFIED)

### a. Tables Structure
```sql
-- debts table
CREATE TABLE debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  transaction_id UUID REFERENCES transactions(id),
  original_amount DECIMAL(15,2) NOT NULL CHECK (original_amount >= 0),
  paid_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  remaining_amount DECIMAL(15,2) NOT NULL CHECK (remaining_amount >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'partial', 'paid', 'overdue', 'cancelled')),
  due_date DATE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- debt_payments table  
-- debt_adjustments table
-- (Full schema available trong migration file)
```

### b. RPC Functions (VERIFIED SIGNATURES)

**✅ `create_credit_sale(p_store_id, p_customer_id, p_transaction_id, p_amount, p_due_date, p_notes)`**
- Creates debt from POS transaction atomically
- Validates store access và user permissions  
- Returns debt_id UUID

**✅ `process_customer_payment(p_store_id, p_customer_id, p_payment_amount, p_payment_method, p_notes)`**
- **CRITICAL FEATURE**: Overpayment prevention với validation
- FIFO payment distribution (oldest debts first)
- Atomic operation với proper rollback
- Returns JSONB với payment summary

**✅ `create_manual_debt(p_store_id, p_customer_id, p_amount, p_notes)`** 
- Manual debt creation outside POS workflow
- Store isolation và validation enforced

# 4. Service & Provider Architecture (3-Layer Implementation)

### a. DebtService (VERIFIED IMPLEMENTATION)
**File**: `lib/features/debt/services/debt_service.dart`

**Key Features:**
```dart
class DebtService extends BaseService {
  // Credit sale creation với POS integration
  Future<String> createDebtFromTransaction({
    required pos.Transaction transaction,
    String? customerId,
    DateTime? dueDate, 
    String? notes,
  }) // Calls create_credit_sale RPC
  
  // Manual debt creation
  Future<String> createManualDebt({
    required String customerId,
    required double amount,
    String? notes,
  }) // Calls create_manual_debt RPC
  
  // Customer debt operations với store filtering
  Future<List<Debt>> getCustomerDebts(String customerId)
  Future<List<DebtPayment>> getCustomerPayments(String customerId) 
  Future<Map<String, dynamic>> getDebtSummary(String customerId)
}
```

### b. DebtProvider (STATE MANAGEMENT)
**File**: `lib/features/debt/providers/debt_provider.dart`

**State Structure:**
```dart
class DebtProvider extends ChangeNotifier {
  List<Debt> _debts = [];
  List<DebtPayment> _payments = [];
  List<DebtAdjustment> _adjustments = [];
  Map<String, dynamic>? _debtSummary;
  
  bool _isLoading = false;
  String _errorMessage = '';
  String _paymentError = ''; // SPECIFIC for payment validation errors
  
  // Master-Detail support
  String? _selectedCustomerId;
}
```

**Key Methods:**
- `createDebtFromTransaction()` - Integration với POS checkout
- `loadCustomerDebts()` - Load debts cho specific customer
- `addPayment()` - Process payment với overpayment handling
- `selectCustomerForDetail()` - Master-detail navigation

### c. UI Integration Points

**POS Integration:**
```dart
// In POS checkout flow - credit sale
if (paymentMethod == PaymentMethod.CREDIT) {
  final debtId = await context.read<DebtProvider>().createDebtFromTransaction(
    transaction: completedTransaction,
    customerId: selectedCustomerId,
    dueDate: calculateDueDate(),
  );
}
```

**Payment Processing với Error Handling:**
```dart
// UI handles overpayment errors from RPC
await debtProvider.addPayment(customerId, paymentAmount);
if (debtProvider.paymentError.isNotEmpty) {
  _showErrorDialog(debtProvider.paymentError); // Display RPC validation error
}
```

---

# 5. User Workflows & Screen Integration

### a. Credit Sale Workflow (POS Integration)
1. **POS Checkout**: User selects "Credit Sale" payment method
2. **Customer Selection**: Choose existing customer or create new
3. **Transaction Processing**: Complete sale với `TransactionService.createTransaction()`
4. **Debt Creation**: Auto-call `DebtProvider.createDebtFromTransaction()`
5. **Confirmation**: Display transaction success với debt information

### b. Payment Processing Workflow
1. **Customer Selection**: Choose customer từ debt list
2. **Amount Input**: Enter payment amount
3. **Validation**: System validates against total outstanding debt
4. **Error Handling**: Display overpayment error if amount exceeds debt
5. **Payment Distribution**: FIFO allocation across outstanding debts
6. **Receipt**: Generate payment receipt với debt balance updates

### c. Debt Management Screens (IMPLEMENTED & PLANNED)
**IMPLEMENTED:**
- ✅ `DebtListScreen`: Overview của all debts với filtering và responsive design
- ✅ `CustomerDebtDetailScreen`: Individual customer debt details với master-detail view
- ✅ `AddPaymentScreen`: Payment processing interface với validation
- ✅ `AdjustDebtScreen`: Manual debt adjustments với reason tracking
- ✅ `DebtSchedulingScreen`: **NEW** - Payment reminder scheduling và management

**DEBT SCHEDULING FEATURE (NEWLY ADDED):**
- ✅ Complete debt status management với visual indicators
- ✅ Payment reminder creation với date picker và validation  
- ✅ Client-side storage using SharedPreferences
- ✅ Smart filtering (active, overdue, due soon reminders)
- ✅ Reminder lifecycle management (add, complete, delete)
- ✅ Integration từ Customer Debt Detail screen
- 🔶 **PLANNED**: Server-side backend implementation với notification system

---

# 6. Business Rules & Validation (UPDATED & ENFORCED)

### a. Overpayment Prevention (CORE FEATURE)
- **Rule**: Hệ thống không chấp nhận payment amount > total outstanding debt
- **Implementation**: RPC `process_customer_payment` validates và throws exception
- **User Experience**: Clear error message "Số tiền trả (X) vượt quá tổng nợ (Y). Vui lòng nhập lại."
- **Business Logic**: Reflects real-world practice - cashier gives change in cash, không ghi vào system

### b. FIFO Payment Distribution  
- **Rule**: Payments applied to oldest debts first
- **Implementation**: RPC orders debts by `created_at ASC`
- **Atomicity**: All payment allocations trong single transaction

### c. Store Isolation & Multi-Tenant Security
- **Rule**: All debt operations scoped to user's store
- **Implementation**: RLS policies + BaseService automatic filtering
- **Validation**: RPC functions validate user store access

### d. Debt Status Management
- **Automatic Status Updates**: Based on payment amounts
  - `pending`: remaining_amount = original_amount
  - `partial`: 0 < remaining_amount < original_amount  
  - `paid`: remaining_amount = 0
  - `overdue`: due_date < current_date AND remaining_amount > 0

### e. Audit Trail Requirements
- **Payment Records**: All payments logged với user, timestamp, method
- **Adjustments**: Manual adjustments require reason và approval
- **Transaction Linking**: Debts linked to original POS transactions

---

# 7. Integration Points

### a. POS System Integration
- **Credit Sale Flow**: Seamless credit option trong checkout
- **Customer Management**: Customer selection/creation từ POS
- **Transaction History**: Debt linked to original transaction

### b. Customer Management Integration  
- **Customer Profiles**: Debt summary trong customer details
- **Credit Limits**: Optional credit limit enforcement (planned)
- **Transaction History**: Combined cash + credit transaction view

### c. Reporting Integration
- **Dashboard**: Outstanding debt summary
- **Customer Analytics**: Payment patterns, overdue trends
- **Financial Reports**: Aging reports, collection efficiency

---

# 8. Performance & Security Considerations

### a. Database Performance
- **Indexes**: Optimized cho customer_id, store_id, status queries
- **RPC Efficiency**: Bulk operations để reduce round trips
- **Pagination**: Large debt lists với proper pagination

### b. Security Implementation
- **RLS Policies**: Row-level security cho all debt tables
- **User Validation**: RPC functions verify store access
- **Permission Checks**: Role-based debt management permissions

### c. Error Handling & Recovery
- **Atomic Operations**: All debt operations trong database transactions
- **Rollback Support**: Failed operations properly rolled back  
- **Validation Errors**: Clear user messaging cho business rule violations

---

**Implementation Status**: 92% Complete
**Database Schema**: ✅ Production ready với verified RPC functions
**Service Layer**: ✅ Complete với store isolation
**Provider Layer**: ✅ Full state management với error handling  
**UI Screens**: ✅ Complete implementation với debt scheduling feature
**POS Integration**: ✅ Credit sale workflow functional
**Business Rules**: ✅ Overpayment prevention và FIFO enforced
**Debt Scheduling**: ✅ Client-side implementation complete, server-side planned

---

# 9. Debt Scheduling & Reminders Feature (NEW - CLIENT-SIDE IMPLEMENTATION)

### a. Current Implementation Status
**✅ FULLY IMPLEMENTED - CLIENT-SIDE VERSION**

**Models**: `lib/features/debt/models/debt_reminder.dart`
- Complete `DebtReminder` model với status tracking
- Client-side validation logic
- JSON serialization cho SharedPreferences storage

**Service**: `lib/features/debt/services/debt_reminder_service.dart`
- ✅ Complete CRUD operations using SharedPreferences
- ✅ Status filtering (overdue, today, completed)
- ✅ Data persistence across app sessions
- ✅ Search và filtering capabilities

**UI Implementation**: `lib/features/debt/screens/debt_scheduling_screen.dart`
- ✅ Complete responsive scheduling interface
- ✅ Visual status indicators với color-coded debt states
- ✅ Segmented control cho reminder filtering (active/overdue/due soon)
- ✅ Add/Edit/Delete reminder functionality với modal forms
- ✅ Date picker integration với validation

**Integration**: `lib/features/debt/screens/customer_debt_detail_screen.dart`
- ✅ Schedule button trong AppBar
- ✅ Context-aware debt selection (only outstanding debts)
- ✅ Seamless navigation to scheduling screen

### b. Key Features Implemented
1. **Debt Status Management**: Visual indicators cho active/overdue/due soon
2. **Payment Reminders**: Custom reminders với date picker
3. **Reminder Lifecycle**: Add/Complete/Delete functionality
4. **Smart Filtering**: Segmented control cho reminder categories
5. **Persistent Storage**: SharedPreferences - no backend dependency
6. **Responsive Design**: Uses ResponsiveScaffold cho consistency

### c. User Experience Flow
1. **Access**: Customer Debt Detail → Schedule Icon → Select Debt
2. **Overview**: View current debt status với visual indicators
3. **Management**: Add reminders với custom dates và notes
4. **Tracking**: Filter và manage reminders by status
5. **Actions**: Mark complete or delete as needed

### d. Future Backend Enhancement Plan
**📋 COMPREHENSIVE BACKEND IMPLEMENTATION ROADMAP**

Detailed backend implementation plan available trong:
- **`/docs/debt_scheduling_backend_plan.md`** - Complete technical specification
- **`/docs/diagram/debt_sequence.md`** - Updated sequence diagrams với scheduling workflows

**Key Backend Features Planned:**
- 🎯 Server-side database tables (`debt_reminders`, `reminder_notifications`, `reminder_templates`)
- 🎯 RPC functions cho CRUD operations với multi-tenant security
- 🎯 Notification system integration (Email, SMS, Push notifications)
- 🎯 Advanced analytics và reporting capabilities
- 🎯 Template system cho reminder messages
- 🎯 Customer behavior analysis và recommendation engine