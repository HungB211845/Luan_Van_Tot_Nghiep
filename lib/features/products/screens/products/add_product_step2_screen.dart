import 'package:flutter/material.dart';
import '../../models/product.dart';
import 'add_product_step3_screen.dart';

class AddProductStep2Screen extends StatefulWidget {
  final String productName;
  final String companyId;

  const AddProductStep2Screen({
    super.key,
    required this.productName,
    required this.companyId,
  });

  @override
  State<AddProductStep2Screen> createState() => _AddProductStep2ScreenState();
}

class _AddProductStep2ScreenState extends State<AddProductStep2Screen> {
  ProductCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thêm Sản Phẩm Mới',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // "Lưu" button - Always present escape hatch
          TextButton(
            onPressed: _canSaveMinimal() ? _saveMinimal : null,
            child: Text(
              'Lưu',
              style: TextStyle(
                color: _canSaveMinimal() ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step indicator
            Row(
              children: [
                _buildStepIndicator(1, true),
                _buildStepLine(true),
                _buildStepIndicator(2, true),
                _buildStepLine(false),
                _buildStepIndicator(3, false),
              ],
            ),

            const SizedBox(height: 32),

            // Product name context
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.productName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Question
            const Text(
              'Đây là loại sản phẩm gì?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Chọn loại để hiển thị các thuộc tính phù hợp',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 40),

            // Category options - Large cards
            Expanded(
              child: Column(
                children: [
                  _buildCategoryCard(
                    ProductCategory.FERTILIZER,
                    'Phân Bón',
                    'NPK, khối lượng, đơn vị...',
                    Icons.eco,
                    Colors.green,
                  ),

                  const SizedBox(height: 16),

                  _buildCategoryCard(
                    ProductCategory.PESTICIDE,
                    'Thuốc BVTV',
                    'Hoạt chất, nồng độ, thể tích...',
                    Icons.bug_report,
                    Colors.orange,
                  ),

                  const SizedBox(height: 16),

                  _buildCategoryCard(
                    ProductCategory.SEED,
                    'Lúa Giống',
                    'Giống, nguồn gốc, tỷ lệ nảy mầm...',
                    Icons.grass,
                    Colors.brown,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedCategory != null ? _continue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedCategory != null
                      ? Colors.green
                      : Colors.grey[300],
                  foregroundColor: _selectedCategory != null
                      ? Colors.white
                      : Colors.grey[500],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _selectedCategory != null ? 2 : 0,
                ),
                child: const Text(
                  'Tiếp tục',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? Colors.green : Colors.grey[300],
      ),
    );
  }

  Widget _buildCategoryCard(
    ProductCategory category,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    bool isSelected = _selectedCategory == category;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(isSelected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  bool _canSaveMinimal() {
    return true; // Can always save with minimal info from step 1
  }

  void _continue() {
    if (_selectedCategory != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddProductStep3Screen(
            productName: widget.productName,
            companyId: widget.companyId,
            category: _selectedCategory!,
          ),
        ),
      );
    }
  }

  void _saveMinimal() {
    // Save with category or without if not selected yet
    Navigator.popUntil(context, (route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã lưu sản phẩm với thông tin cơ bản'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
