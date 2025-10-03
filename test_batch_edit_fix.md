# Test Plan: Batch Edit Button Fix

## 🐛 ISSUE FIXED:
**Problem**: In Product Detail Screen, when tapping batch edit button (via swipe actions), user needs to tap 3 times before EditBatchScreen opens.

## 🔍 ROOT CAUSE:
1. **Async `canEditBatch()` call**: Takes time to check database for sales_count
2. **Multiple tap events**: User taps multiple times during loading
3. **No loading state**: No visual feedback that action is processing
4. **Race conditions**: Multiple simultaneous navigation attempts

## ✅ FIX IMPLEMENTED:

### **1. StatefulWidget Conversion**
- **Changed**: `InventoryBatchesWidget` from StatelessWidget → StatefulWidget
- **Added**: `_loadingBatches` Set to track loading states per batch
- **Purpose**: Enable loading state management

### **2. Debounced Edit Actions**
```dart
// FIXED: Prevent multiple simultaneous edit attempts
if (_loadingBatches.contains(batch.id)) {
  return; // Exit early if already processing
}

setState(() {
  _loadingBatches.add(batch.id); // Mark as loading
});
```

### **3. Visual Loading Feedback**
```dart
// FIXED: Show loading state in slidable actions
SlidableAction(
  onPressed: isLoading ? null : (context) => _editBatch(context, batch),
  backgroundColor: isLoading ? Colors.grey : Colors.blue,
  icon: isLoading ? Icons.hourglass_empty : Icons.edit,
  label: isLoading ? 'Đang tải' : 'Sửa',
)
```

### **4. Proper Cleanup**
```dart
// FIXED: Always cleanup loading state
} finally {
  if (mounted) {
    setState(() {
      _loadingBatches.remove(batch.id); // Remove loading state
    });
  }
}
```

## 🧪 TESTING STEPS:

### **Setup Test Environment:**
1. **Navigate**: Product Detail Screen for product with multiple batches
2. **Ensure**: Product has at least 2-3 batches with different states
3. **Test Data**: Some batches with sales_count=0 (editable), some with sales_count>0 (not editable)

### **Test Scenario 1: Single Tap Edit (Editable Batch)**
1. **Action**: Swipe left on an editable batch (sales_count=0)
2. **Action**: Tap "Sửa" button ONCE
3. **Expected**: 
   - Button shows "Đang tải" immediately ✅
   - Button becomes grey and disabled ✅
   - EditBatchScreen opens after ~1-2 seconds ✅
   - No multiple navigation attempts ✅

### **Test Scenario 2: Single Tap Edit (Non-Editable Batch)**
1. **Action**: Swipe left on non-editable batch (sales_count>0)
2. **Action**: Tap "Sửa" button ONCE
3. **Expected**:
   - Button shows "Đang tải" immediately ✅
   - "Cannot Edit" dialog appears ✅
   - Button returns to normal state ✅
   - No EditBatchScreen navigation ✅

### **Test Scenario 3: Rapid Multiple Taps (Stress Test)**
1. **Action**: Swipe left on editable batch
2. **Action**: Rapidly tap "Sửa" button 5+ times quickly
3. **Expected**:
   - Only first tap processed ✅
   - Subsequent taps ignored ✅
   - EditBatchScreen opens only once ✅
   - No multiple navigation stack issues ✅

### **Test Scenario 4: Delete Button (Similar Fix)**
1. **Action**: Swipe left on batch
2. **Action**: Tap "Xóa" button once
3. **Expected**:
   - Loading state shows immediately ✅
   - Delete confirmation appears ✅
   - No multiple dialog attempts ✅

### **Test Scenario 5: Multiple Batch Operations**
1. **Action**: Swipe and edit Batch A (keep it loading)
2. **Action**: Swipe and edit Batch B simultaneously
3. **Expected**:
   - Both batches can be processed independently ✅
   - Loading states are per-batch, not global ✅
   - No interference between operations ✅

## 🎯 SUCCESS CRITERIA:

### **Before Fix:**
- ❌ Need to tap edit button 3 times
- ❌ No feedback during loading
- ❌ Multiple navigation attempts
- ❌ Poor user experience

### **After Fix:**
- ✅ Single tap opens EditBatchScreen
- ✅ Immediate visual feedback (loading state)
- ✅ Debounced - ignores extra taps
- ✅ Smooth, responsive user experience

## 🔧 TECHNICAL DETAILS:

### **Loading State Management:**
```dart
Set<String> _loadingBatches = <String>{}; // Track loading by batch ID
bool isLoading = _loadingBatches.contains(batch.id); // Check loading state
```

### **Action Debouncing:**
```dart
if (_loadingBatches.contains(batch.id)) {
  return; // Prevent duplicate operations
}
```

### **Visual Feedback:**
- **Color**: Blue → Grey when loading
- **Icon**: Edit → Hourglass when loading  
- **Label**: "Sửa" → "Đang tải" when loading
- **Interaction**: Enabled → Disabled when loading

## 📊 PERFORMANCE IMPACT:
- **Memory**: Minimal - just Set<String> for batch IDs
- **CPU**: Negligible - simple state checks
- **UX**: Significant improvement - single tap response
- **Stability**: Better - prevents race conditions

## 🚨 EDGE CASES COVERED:
1. **Widget disposed during loading**: Proper `mounted` checks
2. **Multiple batches loading**: Independent loading states
3. **Network errors during canEdit check**: Proper error handling + cleanup
4. **Rapid navigation**: Debounced to prevent stack issues

---
**Expected Result: Single tap on batch edit button immediately opens EditBatchScreen with proper loading feedback!** 🎯