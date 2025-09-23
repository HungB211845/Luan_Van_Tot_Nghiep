Đặc Tả Kỹ Thuật: Module Quản Lý Công Nợ (DebtManager)

# 1. Tổng Quan & Mục Tiêu

Module này chịu trách nhiệm theo dõi, quản lý, và xử lý toàn bộ các khoản nợ phát sinh từ chức năng "Ghi nợ" của Module Bán Hàng (POS). Mục tiêu là cung cấp cho chủ cửa hàng một công cụ rõ ràng để biết
ai đang nợ, nợ bao nhiêu, khi nào đến hạn, và thực hiện các nghiệp vụ thu nợ.

# 2. Luồng Hoạt Động Của Người Dùng (User Flow)

## Tạo Nợ (Creation):

Tại màn hình CartScreen, người dùng chọn khách hàng, sau đó chọn phương thức thanh toán là "Ghi nợ" và xác nhận.
Hệ thống tạo một Transaction mới thông qua `TransactionService.createTransaction`. Nếu phương thức thanh toán là "Ghi nợ", `TransactionService` sẽ tự động gọi `DebtService.createDebtFromTransaction` để tạo ra một bản ghi Debt tương ứng, liên kết với Transaction đó và Customer đã chọn.

## Xem Nợ (Viewing):

Cách 1 (Theo Khách Hàng): Người dùng vào CustomerListScreen, chọn một khách hàng để xem chi tiết. Trong màn hình CustomerDetailScreen, sẽ có một tab mới là "Công Nợ", liệt kê tất cả các khoản nợ của riêng khách hàng đó.

Cách 2 (Tổng Quan): Sẽ có một mục "Quản lý Công nợ" ở menu chính, dẫn đến màn hình DebtListScreen để xem toàn bộ các khoản nợ chưa thanh toán của tất cả khách hàng.

## Xử Lý Nợ (Action):

Từ màn hình DebtDetailScreen, người dùng có thể thực hiện các hành động: "Ghi nhận Thanh toán" (mở ra một form nhỏ để nhập số tiền đã trả), "Gia Hạn", "Xóa Nợ".

3. Thiết Kế Data Model (Cho Supabase)

Mày cần tạo 2 bảng mới trong Supabase.

Bảng debts:

id (uuid, primary key)

created_at (timestamptz, default: now())

customer_id (uuid, foreign key đến customers.id)

transaction_id (uuid, foreign key đến transactions.id, unique)

initial_amount (numeric, not null) - Số tiền nợ ban đầu

amount_paid (numeric, default: 0) - Số tiền đã trả

remaining_amount (numeric, not null) - Số tiền còn lại

due_date (date, not null) - Ngày đến hạn trả

interest_rate (numeric, default: 0) - Lãi suất/tháng, ví dụ: 1.5

status (text, not null, default: 'UNPAID') - Trạng thái: UNPAID, PARTIALLY_PAID, PAID, OVERDUE. **Cần tạo ENUM type cho cột `status` trong Supabase để đảm bảo tính nhất quán dữ liệu.**

Bảng debt_payments:

id (uuid, primary key)

created_at (timestamptz, default: now())

debt_id (uuid, foreign key đến debts.id)

payment_date (date, not null) - Ngày khách trả tiền

amount (numeric, not null) - Số tiền trả lần này

notes (text) - Ghi chú

**Bổ sung:**
**RPC Function `calculate_overdue_interest` (trên Supabase):**
Viết và triển khai hàm này trong Supabase tên là `calculate_overdue_interest`.
- Hàm này sẽ nhận vào một `debt_id`.
- Bên trong, nó sẽ tự động tìm khoản nợ, kiểm tra xem nó có quá hạn không, và nếu có, nó sẽ dùng công thức trên để tính ra số tiền lãi hiện tại và trả về.
- Màn hình `DebtDetailScreen` sẽ gọi hàm này để hiển thị số tiền lãi cho người dùng xem.
- **Lưu ý:** Khi tính lãi, cần xem xét các trường hợp đặc biệt: khoản nợ đã được thanh toán hết (`status = PAID`), khoản nợ chưa đến hạn. Công thức tính lãi cần được định nghĩa rõ ràng (ví dụ: lãi suất/tháng, tính theo ngày hay theo tháng, có tính lãi kép không). Hàm này nên trả về một JSON object chứa cả số tiền lãi và có thể là số ngày quá hạn để UI dễ dàng hiển thị.

4. Thiết Kế Tầng Logic (Service & Provider)

Mày sẽ tạo một cặp DebtService và DebtProvider mới.

Trong DebtService.dart:

```dart
enum PaymentStrategy { FIFO, OVERDUE_FIRST }

class PaymentResult {
  final bool success;
  final String message;
  final double remainingPayment; // Số tiền còn lại sau khi đã phân bổ
  final List<String> updatedDebtIds; // Danh sách các debtId đã được cập nhật

  PaymentResult({
    required this.success,
    required this.message,
    this.remainingPayment = 0.0,
    this.updatedDebtIds = const [],
  });
}

// Bổ sung: Model cho Payment Preview
class DebtAllocation {
  final String debtId;
  final double amountApplied;
  final double remainingDebtAfter;
  final String statusAfter;

  DebtAllocation({
    required this.debtId,
    required this.amountApplied,
    required this.remainingDebtAfter,
    required this.statusAfter,
  });
}

class PaymentPreview {
  final List<DebtAllocation> allocations;
  final double totalProcessed;
  final double remainingCredit; // Số tiền khách trả thừa sau khi đã phân bổ hết nợ
  final double totalDebtAfter; // Tổng nợ còn lại của khách hàng sau khi phân bổ

  PaymentPreview({
    required this.allocations,
    required this.totalProcessed,
    required this.remainingCredit,
    required this.totalDebtAfter,
  });
}


Future<Debt> createDebtFromTransaction(Transaction tx, Customer customer);
Future<List<Debt>> getDebtsByCustomerId(String customerId);
Future<PaymentResult> recordCustomerPayment({
  required String customerId,
  required double totalAmount,
  PaymentStrategy strategy = PaymentStrategy.FIFO,
  String? notes,
});
// Bổ sung: Hàm để lấy các khoản nợ chưa thanh toán, có thể sắp xếp
Future<List<Debt>> getUnpaidDebts(String customerId, {PaymentStrategy sortBy = PaymentStrategy.FIFO});
// Bổ sung: Hàm để gọi RPC calculate_overdue_interest
Future<Map<String, dynamic>> calculateOverdueInterest(String debtId);

// Bổ sung: Hàm previewCustomerPayment
Future<PaymentPreview> previewCustomerPayment({
  required String customerId,
  required double totalAmount,
  PaymentStrategy strategy = PaymentStrategy.FIFO,
});
```

Implementation mới cho `recordCustomerPayment` (trong `DebtService.dart`):

```dart
Future<PaymentResult> recordCustomerPayment({
  required String customerId,
  required double totalAmount,
  PaymentStrategy strategy = PaymentStrategy.FIFO,
  String? notes,
}) async {
  // Gọi Supabase RPC để xử lý logic phân bổ thanh toán và cập nhật database
  final response = await _supabase.rpc('process_customer_payment', {
    'p_customer_id': customerId,
    'p_payment_amount': totalAmount,
    'p_strategy': strategy.name,
    'p_notes': notes,
  });

  if (response.error != null) {
    return PaymentResult(success: false, message: response.error!.message);
  }

  // Giả định Supabase RPC trả về một JSON chứa thông tin PaymentResult
  // Ví dụ: {'success': true, 'message': 'Payment processed', 'remaining_payment': 0.0, 'updated_debt_ids': ['debt1', 'debt2']}
  final resultData = response.data as Map<String, dynamic>;
  return PaymentResult(
    success: resultData['success'] ?? false,
    message: resultData['message'] ?? 'Unknown error',
    remainingPayment: (resultData['remaining_payment'] as num?)?.toDouble() ?? 0.0,
    updatedDebtIds: List<String>.from(resultData['updated_debt_ids'] ?? []),
  );
}
```

Database Stored Procedure (trên Supabase):

```sql
CREATE OR REPLACE FUNCTION process_customer_payment(
  p_customer_id UUID,
  p_payment_amount NUMERIC,
  p_strategy TEXT DEFAULT 'FIFO',
  p_notes TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
  debt_record RECORD;
  current_payment_amount NUMERIC := p_payment_amount;
  payment_applied_to_debt NUMERIC;
  v_updated_debt_ids UUID[] := ARRAY[]::UUID[];
  v_message TEXT := 'Payment processed successfully.';
  v_success BOOLEAN := TRUE;
BEGIN
  -- Bắt đầu một transaction để đảm bảo tính nguyên tử của các thao tác
  
  BEGIN
    FOR debt_record IN
      SELECT * FROM debts
      WHERE customer_id = p_customer_id AND status != 'PAID'
      ORDER BY
        CASE p_strategy
          WHEN 'FIFO' THEN created_at
          WHEN 'OVERDUE_FIRST' THEN due_date
          ELSE created_at
        END ASC, created_at ASC -- Thêm created_at ASC để đảm bảo thứ tự ổn định
    LOOP
      IF current_payment_amount <= 0 THEN
        EXIT; -- Không còn tiền để thanh toán
      END IF;

      -- Tính toán số tiền sẽ được áp dụng cho khoản nợ hiện tại
      payment_applied_to_debt := LEAST(current_payment_amount, debt_record.remaining_amount);

      -- Cập nhật khoản nợ gốc
      UPDATE debts
      SET
        amount_paid = debt_record.amount_paid + payment_applied_to_debt,
        remaining_amount = debt_record.remaining_amount - payment_applied_to_debt,
        status = CASE
          WHEN (debt_record.remaining_amount - payment_applied_to_debt) <= 0.001 THEN 'PAID' -- Sử dụng ngưỡng nhỏ để tránh lỗi dấu phẩy động
          ELSE 'PARTIALLY_PAID'
        END
      WHERE id = debt_record.id;

      -- Ghi lại lịch sử thanh toán
      INSERT INTO debt_payments (debt_id, payment_date, amount, notes)
      VALUES (debt_record.id, NOW(), payment_applied_to_debt, p_notes);

      -- Trừ số tiền đã áp dụng khỏi tổng số tiền thanh toán
      current_payment_amount := current_payment_amount - payment_applied_to_debt;

      -- Thêm debt_id vào danh sách các khoản nợ đã được cập nhật
      v_updated_debt_ids := array_append(v_updated_debt_ids, debt_record.id);

    END LOOP;

    -- Nếu vẫn còn tiền sau khi đã thanh toán hết các khoản nợ
    IF current_payment_amount > 0 THEN
      v_message := 'Payment processed. Remaining amount ' || current_payment_amount || ' could not be applied as all debts are paid.';
    END IF;

    -- Trả về kết quả thành công
    RETURN json_build_object(
      'success', v_success,
      'message', v_message,
      'remaining_payment', current_payment_amount,
      'updated_debt_ids', v_updated_debt_ids
    );

  EXCEPTION
    WHEN OTHERS THEN
      -- Xử lý lỗi và rollback transaction
      v_success := FALSE;
      v_message := SQLERRM;
      RETURN json_build_object(
        'success', v_success,
        'message', v_message,
        'remaining_payment', p_payment_amount, -- Toàn bộ số tiền không được áp dụng
        'updated_debt_ids', ARRAY[]::UUID[]
      );
  END;
END;
$$ LANGUAGE plpgsql;
```

Trong DebtProvider.dart:

State: List<Debt> customerDebts, Debt? selectedDebt, bool isLoading...

Methods: loadDebts(String customerId), addPayment(String customerId, double amount, PaymentStrategy strategy, String? notes)... Các hàm này sẽ gọi đến DebtService tương ứng và gọi notifyListeners().
**Bổ sung:** `DebtProvider` cần có các hàm để `loadDebts` (tải danh sách nợ của một khách hàng), `addPayment` (gọi `DebtService.recordCustomerPayment`), và `refreshDebtStatus` (để cập nhật trạng thái nợ sau khi thanh toán hoặc khi có thay đổi). Đảm bảo `notifyListeners()` được gọi sau mỗi lần cập nhật state để UI được refresh.

5. Thiết Kế Giao Diện (UI Screens)

Thay đổi ở CustomerDetailScreen.dart:

Thêm một Tab mới tên là "Công Nợ".

Nội dung tab này sẽ là một ListView.builder hiển thị danh sách customerDebts từ DebtProvider. Mỗi item sẽ là một Card tóm tắt thông tin khoản nợ (số tiền còn lại, ngày đến hạn, trạng thái).
**Bổ sung:** Tab "Công Nợ" cần hiển thị tổng công nợ của khách hàng đó (có thể lấy từ một view/function trên Supabase hoặc tính toán từ danh sách nợ). Cần có một cách để refresh danh sách nợ trong tab này khi có thay đổi (ví dụ: sau khi ghi nhận thanh toán).

Màn hình mới: DebtDetailScreen.dart

Được mở ra khi bấm vào một item nợ.

Hiển thị chi tiết: Nợ gốc, đã trả, còn lại, ngày đến hạn, số ngày quá hạn, tiền lãi (tính tự động).

Hiển thị lịch sử trả nợ: Một ListView khác hiển thị các bản ghi từ bảng debt_payments.

Các nút hành động: "Ghi Nhận Thanh Toán" (mở ra màn hình AddPaymentScreen), "Gia Hạn", "Xóa Nợ".
**Bổ sung:** Màn hình này cần hiển thị thông tin chi tiết của khoản nợ, bao gồm cả số tiền lãi quá hạn (bằng cách gọi RPC `calculate_overdue_interest` thông qua `DebtService` và `DebtProvider`). Các nút hành động ("Ghi nhận Thanh toán", "Gia Hạn", "Xóa Nợ") cần gọi đúng các hàm trong `DebtProvider`.

Màn hình mới: AddPaymentScreen.dart

Một form đơn giản với các ô nhập: "Số tiền trả", "Ngày trả", "Ghi chú", và có thể chọn "Chiến lược phân bổ" (mặc định FIFO).

Nút "Lưu" sẽ gọi `debtProvider.addPayment(customerId, amount, strategy, notes)`.
**Bổ sung:** Form này cần cho phép người dùng nhập `notes` (ghi chú) cho khoản thanh toán. Cần có một cách để chọn `PaymentStrategy` (FIFO, OVERDUE_FIRST) nếu muốn người dùng có thể tùy chỉnh. Mặc định là FIFO.
**Bổ sung: Enhanced UI Flow cho AddPaymentScreen:**
1.  **Input amount:** Người dùng nhập số tiền muốn trả.
2.  **Show PREVIEW allocation:** Gọi `DebtService.previewCustomerPayment` để hiển thị cách số tiền sẽ được phân bổ cho các khoản nợ, bao gồm số tiền còn lại sau khi trả và tổng nợ còn lại.
3.  **User confirm:** Người dùng xác nhận việc phân bổ.
4.  **Process payment:** Gọi `DebtService.recordCustomerPayment` để xử lý thanh toán.
5.  **Show RESULT:** Hiển thị kết quả chi tiết của quá trình thanh toán.


# Các quy tắc nghiệp vụ cốt lõi mà module DebtManager phải tuân thủ. Đây là linh hồn của module, code chỉ là phần thể xác.

Đầu tiên, một khoản nợ không tự nhiên sinh ra. Nó phải được khai sinh từ một giao dịch bán hàng có phương thức thanh toán là "Ghi nợ". Mỗi khoản nợ phải được gắn chặt với một khách hàng và một giao dịch duy nhất, với số tiền nợ ban đầu chính là tổng giá trị của giao dịch đó. Trạng thái khởi điểm của nó luôn là "Chưa trả" (UNPAID).
**Bổ sung:** Khi gọi `DebtService.createDebtFromTransaction`, đảm bảo truyền đầy đủ thông tin cần thiết từ `Transaction` và `Customer` để tạo một bản ghi `Debt` hoàn chỉnh (bao gồm `initial_amount`, `due_date`, `interest_rate`). `due_date` và `interest_rate` có thể lấy từ cấu hình mặc định hoặc từ thông tin khách hàng.

Tiếp theo, quy tắc quan trọng nhất là logic khi thu nợ. Khi mày ghi nhận một khoản thanh toán, hệ thống phải thực hiện hai việc đồng thời như một hành động nguyên tử: tạo một bản ghi mới trong bảng lịch sử trả nợ (debt_payments) và cập nhật lại khoản nợ gốc trong bảng debts. Cụ thể, số tiền đã trả (amount_paid) phải được cộng thêm và số tiền còn lại (remaining_amount) phải được trừ đi. Trạng thái của khoản nợ cũng phải được tự động cập nhật dựa trên số tiền còn lại: nếu vẫn còn nợ thì là "Đã trả một phần" (PARTIALLY_PAID), nếu đã trả hết thì là "Đã thanh toán" (PAID).

**Ví dụ cụ thể về phân bổ thanh toán:**

Giả sử Ông Tư có 2 khoản nợ:
-   **Nợ 1:** 100k, tạo ngày 22/09/2025, đến hạn 22/10/2025, `remaining_amount = 100k`, `status = UNPAID`.
-   **Nợ 2:** 200k, tạo ngày 23/09/2025, đến hạn 23/10/2025, `remaining_amount = 200k`, `status = UNPAID`.

Khi Ông Tư trả 150k vào ngày 24/09/2025, với chiến lược `FIFO` (First In, First Out - nợ nào phát sinh trước trả trước):

1.  Hệ thống sẽ ưu tiên thanh toán **Nợ 1** trước.
    -   `Nợ 1` cần 100k. Số tiền trả còn lại: `150k - 100k = 50k`.
    -   `Nợ 1` được cập nhật: `amount_paid = 100k`, `remaining_amount = 0`, `status = PAID`.
    -   Một bản ghi `debt_payments` được tạo cho `Nợ 1` với `amount = 100k`.
2.  Số tiền còn lại (50k) sẽ được áp dụng cho **Nợ 2**.
    -   `Nợ 2` cần 200k. Số tiền trả còn lại: `50k - 50k = 0k`.
    -   `Nợ 2` được cập nhật: `amount_paid = 50k`, `remaining_amount = 150k`, `status = PARTIALLY_PAID`.
    -   Một bản ghi `debt_payments` được tạo cho `Nợ 2` với `amount = 50k`.

Kết quả: `Nợ 1` đã được thanh toán hết, `Nợ 2` được thanh toán một phần, và tổng số tiền 150k đã được phân bổ hoàn toàn.

Một quy tắc nghiệp vụ quan trọng khác là xử lý nợ quá hạn. Nếu ngày hiện tại đã vượt qua ngày hẹn trả (due_date) mà khoản nợ vẫn chưa được thanh toán hết, trạng thái của nó phải tự động chuyển thành "Quá hạn" (OVERDUE). Đi kèm với đó là logic tính lãi tự động. Màn hình chi tiết công nợ phải hiển thị được số tiền lãi phát sinh dựa trên lãi suất đã định và số ngày quá hạn.

Cuối cùng là các quy tắc về toàn vẹn dữ liệu. Hệ thống phải đảm bảo một khoản nợ không thể tồn tại nếu không có khách hàng, và một khoản thanh toán không thể tồn tại nếu không có khoản nợ tương ứng. Mọi phép tính về số tiền còn lại phải luôn chính xác.

Tất cả các quy tắc này phải được thực thi một cách nghiêm ngặt ở tầng Service (DebtService) để đảm bảo dù giao diện có thay đổi thế nào, logic nghiệp vụ cốt lõi vẫn luôn nhất quán và đúng đắn.

**Bổ sung: Due Date Auto-Calculation:**
```dart
class DebtConfiguration {
  static const Map<String, int> defaultDueDays = {
    'VIP': 60,
    'REGULAR': 30,
    'NEW': 15,
  };
  
  static DateTime calculateDueDate(String customerId, String customerType) {
    // Logic cụ thể: Lấy số ngày nợ mặc định dựa trên customerType
    final days = defaultDueDays[customerType] ?? defaultDueDays['REGULAR']!;
    return DateTime.now().add(Duration(days: days));
  }
}
```
Logic này sẽ được sử dụng trong `DebtService.createDebtFromTransaction` để tính toán `due_date` cho khoản nợ mới.

**Bổ sung: Interest Rate Management:**
-   Lãi suất mặc định cho từng loại khách hàng sẽ được quản lý thông qua `DebtPolicy` (xem phần RECOMMENDATIONS).
-   **Công thức tính lãi:** Lãi suất sẽ được tính theo lãi đơn (simple interest) hàng tháng. Ví dụ: 1.5% mỗi tháng.
    -   `final dailyInterestRate = monthlyRate / 30;`
    -   `final interestAmount = principalAmount * dailyInterestRate * daysLate;`
    -   Công thức này sẽ được triển khai trong RPC `calculate_overdue_interest` trên Supabase.

**Bổ sung: OVERDUE Status Transition (Automated):**
-   Trạng thái "Quá hạn" (OVERDUE) sẽ được tự động cập nhật thông qua một `scheduled job` hoặc `database trigger` trên Supabase.
```sql
-- Ví dụ về Scheduled job hoặc Trigger (được chạy định kỳ)
UPDATE debts
SET status = 'OVERDUE'
WHERE due_date < CURRENT_DATE
  AND status IN ('UNPAID', 'PARTIALLY_PAID');
```
Logic này đảm bảo trạng thái nợ luôn được cập nhật chính xác mà không cần can thiệp thủ công.

**Bổ sung: Business Rules (Tăng cường Validation & Edge Cases):**
-   **Validation:**
    -   **Maximum debt per customer:** Kiểm tra tổng số nợ của khách hàng không vượt quá hạn mức cho phép.
    -   **Credit limit checking:** Kiểm tra hạn mức tín dụng của khách hàng trước khi cho phép giao dịch ghi nợ.
    -   **Blacklist customer handling:** Xử lý khách hàng trong danh sách đen (không cho phép ghi nợ).
-   **Edge Cases:**
    -   **Customer delete nhưng còn debt:** Cần có quy trình xử lý khi khách hàng bị xóa nhưng vẫn còn nợ (ví dụ: chuyển nợ sang một tài khoản nợ xấu chung, hoặc yêu cầu thanh toán hết trước khi xóa).
    -   **Debt forgiveness workflow:** Quy trình xóa nợ (ví dụ: khi khách hàng không có khả năng trả, hoặc có chính sách hỗ trợ).
    -   **Bulk payment processing:** Xử lý khi một khoản thanh toán lớn được áp dụng cho nhiều khoản nợ (đã được đề cập trong `recordCustomerPayment`).

**RECOMMENDATIONS:**
1.  **Thêm DebtPolicy Configuration:**
    ```dart
    class DebtPolicy {
      final double maxDebtPerCustomer;
      final int maxUnpaidDebts;
      final Map<String, double> interestRateByType; // Lãi suất theo loại khách hàng
      final Map<String, int> dueDaysByType; // Số ngày nợ theo loại khách hàng
    }
    ```
    `DebtPolicy` sẽ là một cấu hình tập trung cho các quy tắc nghiệp vụ liên quan đến nợ.

2.  **Enhanced UI Flow cho AddPaymentScreen:**
    1.  **Input amount:** Người dùng nhập số tiền muốn trả.
    2.  **Show PREVIEW allocation:** Gọi `DebtService.previewCustomerPayment` để hiển thị cách số tiền sẽ được phân bổ cho các khoản nợ, bao gồm số tiền còn lại sau khi trả và tổng nợ còn lại.
    3.  **User confirm:** Người dùng xác nhận việc phân bổ.
    4.  **Process payment:** Gọi `DebtService.recordCustomerPayment` để xử lý thanh toán.
    5.  **Show RESULT:** Hiển thị kết quả chi tiết của quá trình thanh toán.

3.  **Debt Analytics Dashboard:**
    ```dart
    class DebtSummary {
      final double totalOutstanding; // Tổng nợ chưa thanh toán
      final int overdueCount; // Số lượng khoản nợ quá hạn
      final double averageDaysLate; // Số ngày quá hạn trung bình
      final Map<String, double> debtByCustomerType; // Nợ theo loại khách hàng
    }
    ```
    Cần xây dựng các RPC/Views trên Supabase để cung cấp dữ liệu cho dashboard này.

4.  **Notification Integration:**
    -   Liên kết với một hệ thống `ReminderSystem` để tự động tạo và gửi thông báo (SMS, email) dựa trên trạng thái nợ (ví dụ: nhắc nhở sắp đến hạn, thông báo quá hạn).
