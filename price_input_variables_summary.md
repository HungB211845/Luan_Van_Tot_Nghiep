# Price Input Variables in Product Detail Screen

## 🔍 FOUND VARIABLES:

### **Quick Add Batch Sheet (`quick_add_batch_sheet.dart`)**

#### **Giá Nhập (Cost Price) Controller:**
```dart
final _costPriceController = TextEditingController();
```

#### **Other Price Controllers:**
```dart
final _quantityController = TextEditingController();           // Số lượng
final _newSellingPriceController = TextEditingController();    // Giá bán mới (optional)
```

### **Product Detail Screen (`product_detail_screen.dart`)**

#### **Giá Bán (Selling Price) Controller:**
```dart
final TextEditingController _priceController = TextEditingController();
```

#### **Price History Variables:**
```dart
List<PriceHistoryItem> _priceHistory = [];     // Lịch sử giá bán
double _averageCostPrice = 0;                  // Giá vốn trung bình
double _originalPrice = 0;                     // Giá gốc khi edit
```

## 🎯 KEY FINDINGS:

### **Input Formatters Used:**
- **SimpleCurrencyInputFormatter**: Custom formatter trong quick_add_batch_sheet.dart
- **CurrencyInputFormatter**: From shared utils (input_formatters.dart)

### **Price Extraction Methods:**
```dart
// In quick add batch:
_extractSimpleNumber(value)  // Simple extraction method

// In input formatters:
InputFormatterHelper.extractNumber(text)  // Shared utility method
```

### **Form Fields Labels:**
- **Giá vốn**: "Giá vốn *" (Cost price - required)
- **Giá bán mới**: "Giá bán mới (tùy chọn)" (New selling price - optional)
- **Số lượng**: "Số lượng *" (Quantity - required)

### **Validation Logic:**
```dart
// Cost price validation
if (value == null || value.isEmpty) {
  return 'Vui lòng nhập giá vốn';
}
final price = _extractSimpleNumber(value);
if (price == null || price <= 0) {
  return 'Giá vốn phải lớn hơn 0';
}
```

## 🔧 USAGE IN QUICK ADD BATCH:

### **Data Extraction:**
```dart
final costPrice = _extractSimpleNumber(_costPriceController.text.trim()) ?? 0;
```

### **API Call:**
```dart
final success = await provider.quickAddBatch(
  productId: widget.product.id,
  quantity: quantity,
  costPrice: costPrice,        // ← This is the cost price value
  newSellingPrice: newSellingPrice,
);
```

### **Profit Calculation:**
```dart
final cost = _extractSimpleNumber(costText);     // From _costPriceController
final selling = _extractSimpleNumber(sellingText);
final profitPercentage = ((selling - cost) / cost) * 100;
```

## 📝 VARIABLE NAME ANSWER:

**Tên biến giá nhập trong Quick Add Batch là: `_costPriceController`**

**Được sử dụng để:**
- Input giá vốn/giá nhập cho lô hàng mới
- Tính toán lợi nhuận với giá bán
- Lưu vào database khi tạo batch mới
- Validation required field (bắt buộc nhập)