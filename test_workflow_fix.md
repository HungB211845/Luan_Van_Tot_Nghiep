# 🧪 TEST WORKFLOW FOR PRODUCT-PO-BATCH FIX

## 🔧 Root Cause Analysis Results

Chúng ta đã identified và fix 4 issues chính:

### ❌ **Issues Fixed:**

1. **Product Creation → Missing Units Issue**
   - **Problem**: Sản phẩm mới không tự động tạo units → PO creation không thể chọn đơn vị
   - **Fix**: Auto-create default units trong `ProductProvider.addProduct()`

2. **Unit Selection UI Issue** 
   - **Problem**: Dropdown đơn vị không hiển thị warning khi product chưa có units
   - **Fix**: Enhanced UI feedback trong `CreatePOScreen._buildUnitDropdown()`

3. **Stock Reset After Hard Refresh Issue**
   - **Problem**: Stock cache bị reset về 0 sau refresh dù database có stock thật  
   - **Fix**: Preserve stock cache during refresh trong `ProductProvider.refresh()`

4. **PO Receiving → Stock Sync Issue**
   - **Problem**: Stock không được refresh properly sau khi receive PO
   - **Fix**: Force refresh stock cache sau PO receiving

---

## 🧪 **Testing Instructions**

### **Test Case 1: New Product → PO Creation**
```
1. Tạo sản phẩm mới (category: Phân Bón)
2. Vào Product Detail → Create PO  
3. ✅ EXPECT: Dropdown đơn vị hiển thị ["kg", "Bao"]
4. ✅ EXPECT: Có thể chọn "Bao" thành công
5. Tạo PO với đơn vị "Bao"
6. ✅ EXPECT: PO tạo thành công với unit conversion đúng
```

### **Test Case 2: PO → Batch Creation → Stock Sync**  
```
1. Tạo PO với sản phẩm phân bón (10 Bao @ 660K/Bao)
2. Send PO → Confirm → Receive
3. ✅ EXPECT: Batch được tạo với 500kg (10 × 50kg)  
4. ✅ EXPECT: Product stock = 500kg
5. Hard refresh app
6. ✅ EXPECT: Stock vẫn hiển thị 500kg (không reset về 0)
```

### **Test Case 3: POS Sales After Batch Creation**
```
1. Sau khi tạo batch (từ Test Case 2)
2. Vào POS → Search sản phẩm phân bón
3. ✅ EXPECT: Hiển thị "10 Bao" available  
4. Add to cart: 2 Bao
5. ✅ EXPECT: Checkout thành công
6. ✅ EXPECT: Stock giảm xuống "8 Bao" (400kg)
```

### **Test Case 4: Multi-Unit Price Consistency**
```
1. Tạo sản phẩm với giá 660K (price for default unit "Bao")
2. ✅ EXPECT: kg unit có giá 13.2K (660K ÷ 50kg)
3. Tạo PO với cost 600K/Bao
4. Receive PO  
5. ✅ EXPECT: Selling price sync đúng across units
6. POS: Bán 1 Bao → giá 660K, bán 50kg → giá 660K
```

---

## 🚨 **Critical Verification Points**

### **Data Consistency Checks:**
- [ ] Product units auto-created on product creation
- [ ] Unit prices calculated correctly (base vs default unit)
- [ ] Stock displayed correctly in all screens (Product, POS, Reports)  
- [ ] Unit conversions work in both directions (kg ↔ Bao)

### **UI/UX Checks:**
- [ ] No more empty unit dropdowns in PO creation
- [ ] Clear error messages when units missing
- [ ] Stock never shows 0 when there's actual inventory
- [ ] Price display consistent across units

### **Integration Checks:**
- [ ] PO → Batch → Stock → POS flow works end-to-end  
- [ ] Hard refresh doesn't break stock display
- [ ] Multiple concurrent PO receiving works properly
- [ ] Cache invalidation doesn't cause data loss

---

## 🏆 **Expected Outcomes**

After implementing these fixes:

✅ **User can create product → PO → batch smoothly**  
✅ **Unit dropdown always shows available options**
✅ **Stock displays correctly after any operation**  
✅ **POS sales work immediately after batch creation**
✅ **No more "0 stock" ghost issues**

---

## 🔍 **Root Cause Summary**

The core issue was a **data synchronization cascade failure**:

1. Product creation didn't create units → PO creation failed
2. Cache invalidation was too aggressive → stock data lost  
3. Unit price sync wasn't atomic → pricing inconsistencies
4. Stock refresh timing issues → POS couldn't sell inventory

These are classic **client-side state management issues** that required coordinated fixes across multiple providers and services.