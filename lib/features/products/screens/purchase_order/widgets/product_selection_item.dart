import 'package:flutter/material.dart';import 'package:flutter/material.dart';import 'package:flutter/material.dart';import 'package:flutter/material.dart';

import '../../../models/product.dart';

import '../../../models/product.dart';

class ProductSelectionItem extends StatelessWidget {

  final Product product;import '../../../models/product.dart';import '../../../models/product.dart';

  final int currentStock;

  final double? lastPrice;class ProductSelectionItem extends StatelessWidget {

  final bool isInCart;

  final int cartQuantity;  final Product product;

  final VoidCallback onTap;

  final int currentStock;

  const ProductSelectionItem({

    Key? key,  final double? lastPrice;class ProductSelectionItem extends StatelessWidget {class ProductSelectionItem extends StatelessWidget {

    required this.product,

    required this.currentStock,  final bool isInCart;

    this.lastPrice,

    required this.isInCart,  final int cartQuantity;  final Product product;  final Product product;

    required this.cartQuantity,

    required this.onTap,  final VoidCallback onTap;

  }) : super(key: key);

  final int currentStock;  final int currentStock;

  @override

  Widget build(BuildContext context) {  const ProductSelectionItem({

    final categoryColor = _getCategoryColor();

    final isLowStock = currentStock <= 10;    Key? key,  final double? lastPrice;  final double? lastPrice;

    

    return InkWell(    required this.product,

      onTap: onTap,

      borderRadius: BorderRadius.circular(12),    required this.currentStock,  final bool isInCart;  final bool isInCart;

      child: Container(

        margin: const EdgeInsets.only(bottom: 12),    this.lastPrice,

        decoration: BoxDecoration(

          color: Colors.white,    required this.isInCart,  final int cartQuantity;  final int cartQuantity;

          borderRadius: BorderRadius.circular(12),

          border: Border.all(    required this.cartQuantity,

            color: isInCart ? Colors.green[200]! : Colors.grey[200]!,

            width: isInCart ? 2 : 1,    required this.onTap,  final VoidCallback onTap;  final VoidCallback onTap;

          ),

          boxShadow: [  }) : super(key: key);

            BoxShadow(

              color: Colors.black.withOpacity(0.04),

              blurRadius: 4,

              offset: const Offset(0, 2),  @override

            ),

          ],  Widget build(BuildContext context) {  const ProductSelectionItem({  const ProductSelectionItem({

        ),

        child: Padding(    final categoryColor = _getCategoryColor();

          padding: const EdgeInsets.all(16),

          child: Column(    final isLowStock = currentStock <= 10;    Key? key,    Key? key,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [    

              Row(

                crossAxisAlignment: CrossAxisAlignment.start,    return InkWell(    required this.product,    required this.product,

                children: [

                  Container(      onTap: onTap,

                    width: 40,

                    height: 40,      borderRadius: BorderRadius.circular(12),    required this.currentStock,    required this.currentStock,

                    decoration: BoxDecoration(

                      color: categoryColor.withOpacity(0.1),      child: Container(

                      borderRadius: BorderRadius.circular(8),

                    ),        margin: const EdgeInsets.only(bottom: 12),    this.lastPrice,    this.lastPrice,

                    child: Icon(

                      _getCategoryIcon(),        decoration: BoxDecoration(

                      color: categoryColor,

                      size: 20,          color: Colors.white,    required this.isInCart,    required this.isInCart,

                    ),

                  ),          borderRadius: BorderRadius.circular(12),

                  

                  const SizedBox(width: 12),          border: Border.all(    required this.cartQuantity,    required this.cartQuantity,

                  

                  Expanded(            color: isInCart ? Colors.green[200]! : Colors.grey[200]!,

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,            width: isInCart ? 2 : 1,    required this.onTap,    required this.onTap,

                      children: [

                        Text(          ),

                          product.name,

                          style: const TextStyle(          boxShadow: [  }) : super(key: key);  }) : super(key: key);

                            fontSize: 16,

                            fontWeight: FontWeight.w600,            BoxShadow(

                            color: Colors.black87,

                          ),              color: Colors.black.withOpacity(0.04),

                          maxLines: 2,

                          overflow: TextOverflow.ellipsis,              blurRadius: 4,

                        ),

                        const SizedBox(height: 4),              offset: const Offset(0, 2),  @overrideclass _ProductSelectionItemState extends State<ProductSelectionItem> {

                        if (product.sku != null) ...[

                          Text(            ),

                            product.sku!,

                            style: TextStyle(          ],  Widget build(BuildContext context) {  final TextEditingController _quantityController = TextEditingController();

                              fontSize: 14,

                              color: Colors.grey[600],        ),

                            ),

                          ),        child: Padding(    final categoryColor = _getCategoryColor();  final FocusNode _quantityFocusNode = FocusNode();

                          const SizedBox(height: 4),

                        ],          padding: const EdgeInsets.all(16),

                        Container(

                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),          child: Column(    final isLowStock = currentStock <= 10;  String _selectedUnit = 'kg';

                          decoration: BoxDecoration(

                            color: categoryColor.withOpacity(0.1),            crossAxisAlignment: CrossAxisAlignment.start,

                            borderRadius: BorderRadius.circular(4),

                          ),            children: [      

                          child: Text(

                            _getCategoryLabel(),              // Product header - Browse Mode

                            style: TextStyle(

                              fontSize: 12,              Row(    return InkWell(  @override

                              color: categoryColor,

                              fontWeight: FontWeight.w500,                crossAxisAlignment: CrossAxisAlignment.start,

                            ),

                          ),                children: [      onTap: onTap,  void initState() {

                        ),

                      ],                  // Category icon

                    ),

                  ),                  Container(      borderRadius: BorderRadius.circular(12),    super.initState();

                  

                  if (isInCart)                    width: 40,

                    Container(

                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),                    height: 40,      child: Container(    if (widget.isInCart && widget.cartQuantity > 0) {

                      decoration: BoxDecoration(

                        color: Colors.green,                    decoration: BoxDecoration(

                        borderRadius: BorderRadius.circular(12),

                      ),                      color: categoryColor.withOpacity(0.1),        margin: const EdgeInsets.only(bottom: 12),      _quantityController.text = widget.cartQuantity.toString();

                      child: Text(

                        '$cartQuantity',                      borderRadius: BorderRadius.circular(8),

                        style: const TextStyle(

                          color: Colors.white,                    ),        decoration: BoxDecoration(    } else {

                          fontSize: 12,

                          fontWeight: FontWeight.w600,                    child: Icon(

                        ),

                      ),                      _getCategoryIcon(),          color: Colors.white,      _quantityController.text = '1';

                    ),

                ],                      color: categoryColor,

              ),

                                    size: 20,          borderRadius: BorderRadius.circular(12),    }

              const SizedBox(height: 16),

                                  ),

              Row(

                children: [                  ),          border: Border.all(    _selectedUnit = _getDefaultUnit();

                  Expanded(

                    child: Column(                  

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [                  const SizedBox(width: 12),            color: isInCart ? Colors.green[200]! : Colors.grey[200]!,  }

                        Text(

                          '💰 Giá nhập gần nhất',                  

                          style: TextStyle(

                            fontSize: 12,                  // Product info - Clean and focused            width: isInCart ? 2 : 1,

                            color: Colors.grey[600],

                          ),                  Expanded(

                        ),

                        const SizedBox(height: 2),                    child: Column(          ),  @override

                        Text(

                          lastPrice != null                       crossAxisAlignment: CrossAxisAlignment.start,

                              ? _formatCurrency(lastPrice!)

                              : 'Chưa có giá',                      children: [          boxShadow: [  void dispose() {

                          style: const TextStyle(

                            fontSize: 14,                        Text(

                            fontWeight: FontWeight.w600,

                            color: Colors.black87,                          product.name,            BoxShadow(    _quantityController.dispose();

                          ),

                        ),                          style: const TextStyle(

                      ],

                    ),                            fontSize: 16,              color: Colors.black.withOpacity(0.04),    _quantityFocusNode.dispose();

                  ),

                                              fontWeight: FontWeight.w600,

                  Expanded(

                    child: Column(                            color: Colors.black87,              blurRadius: 4,    super.dispose();

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [                          ),

                        Text(

                          '📦 Tồn kho',                          maxLines: 2,              offset: const Offset(0, 2),  }

                          style: TextStyle(

                            fontSize: 12,                          overflow: TextOverflow.ellipsis,

                            color: Colors.grey[600],

                          ),                        ),            ),

                        ),

                        const SizedBox(height: 2),                        const SizedBox(height: 4),

                        Row(

                          children: [                        if (product.sku != null) ...[          ],  String _getDefaultUnit() {

                            Text(

                              '$currentStock',                          Text(

                              style: TextStyle(

                                fontSize: 14,                            product.sku!,        ),    switch (widget.product.category) {

                                fontWeight: FontWeight.w600,

                                color: isLowStock ? Colors.red[600] : Colors.black87,                            style: TextStyle(

                              ),

                            ),                              fontSize: 14,        child: Padding(      case ProductCategory.FERTILIZER:

                            if (isLowStock) ...[

                              const SizedBox(width: 4),                              color: Colors.grey[600],

                              Icon(

                                Icons.warning_outlined,                            ),          padding: const EdgeInsets.all(16),        return 'kg';

                                size: 16,

                                color: Colors.red[600],                          ),

                              ),

                            ],                          const SizedBox(height: 4),          child: Column(      case ProductCategory.PESTICIDE:

                          ],

                        ),                        ],

                        if (isLowStock)

                          Text(                        Container(            crossAxisAlignment: CrossAxisAlignment.start,        return 'chai';

                            'Sắp hết hàng',

                            style: TextStyle(                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                              fontSize: 11,

                              color: Colors.red[600],                          decoration: BoxDecoration(            children: [      case ProductCategory.SEED:

                            ),

                          ),                            color: categoryColor.withOpacity(0.1),

                      ],

                    ),                            borderRadius: BorderRadius.circular(4),              // Product header - Browse Mode        return 'kg';

                  ),

                ],                          ),

              ),

                                        child: Text(              Row(    }

              const SizedBox(height: 12),

              Container(                            _getCategoryLabel(),

                width: double.infinity,

                padding: const EdgeInsets.symmetric(vertical: 8),                            style: TextStyle(                crossAxisAlignment: CrossAxisAlignment.start,  }

                decoration: BoxDecoration(

                  color: Colors.grey[50],                              fontSize: 12,

                  borderRadius: BorderRadius.circular(6),

                  border: Border.all(color: Colors.grey[200]!),                              color: categoryColor,                children: [

                ),

                child: Text(                              fontWeight: FontWeight.w500,

                  isInCart ? '✅ Đã chọn - Chạm để chỉnh sửa' : '👆 Chạm để thêm vào giỏ',

                  textAlign: TextAlign.center,                            ),                  // Category icon  List<String> _getUnitOptions() {

                  style: TextStyle(

                    fontSize: 13,                          ),

                    color: isInCart ? Colors.green[700] : Colors.grey[600],

                    fontWeight: isInCart ? FontWeight.w600 : FontWeight.normal,                        ),                  Container(    switch (widget.product.category) {

                  ),

                ),                      ],

              ),

            ],                    ),                    width: 40,      case ProductCategory.FERTILIZER:

          ),

        ),                  ),

      ),

    );                                      height: 40,        return ['kg', 'tấn', 'bao'];

  }

                  // Cart indicator - Simple

  Color _getCategoryColor() {

    switch (product.category) {                  if (isInCart)                    decoration: BoxDecoration(      case ProductCategory.PESTICIDE:

      case ProductCategory.FERTILIZER:

        return Colors.green;                    Container(

      case ProductCategory.PESTICIDE:

        return Colors.orange;                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),                      color: categoryColor.withOpacity(0.1),        return ['ml', 'lít', 'chai', 'gói', 'lọ'];

      case ProductCategory.SEED:

        return Colors.brown;                      decoration: BoxDecoration(

    }

  }                        color: Colors.green,                      borderRadius: BorderRadius.circular(8),      case ProductCategory.SEED:



  IconData _getCategoryIcon() {                        borderRadius: BorderRadius.circular(12),

    switch (product.category) {

      case ProductCategory.FERTILIZER:                      ),                    ),        return ['kg', 'bao'];

        return Icons.eco;

      case ProductCategory.PESTICIDE:                      child: Text(

        return Icons.bug_report;

      case ProductCategory.SEED:                        '$cartQuantity',                    child: Icon(    }

        return Icons.grass;

    }                        style: const TextStyle(

  }

                          color: Colors.white,                      _getCategoryIcon(),  }

  String _getCategoryLabel() {

    switch (product.category) {                          fontSize: 12,

      case ProductCategory.FERTILIZER:

        return 'Phân bón';                          fontWeight: FontWeight.w600,                      color: categoryColor,

      case ProductCategory.PESTICIDE:

        return 'Thuốc BVTV';                        ),

      case ProductCategory.SEED:

        return 'Lúa giống';                      ),                      size: 20,  void _onQuantityChanged(String value) {

    }

  }                    ),



  String _formatCurrency(double amount) {                ],                    ),    final quantity = int.tryParse(value);

    if (amount == amount.toInt()) {

      return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';              ),

    } else {

      String formatted = amount.toStringAsFixed(1);                                ),    if (quantity != null && quantity > 0) {

      formatted = formatted.replaceAll('.', ',');

      List<String> parts = formatted.split(',');              const SizedBox(height: 16),

      parts[0] = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

      return '${parts.join(',')}₫';                                      // Auto-add to cart when quantity is entered

    }

  }              // Essential info only - For decision making

}
              Row(                  const SizedBox(width: 12),      widget.onAddToCart(widget.product, quantity, _selectedUnit);

                children: [

                  // Last price reference                      } else if (value.isEmpty || quantity == 0) {

                  Expanded(

                    child: Column(                  // Product info - Clean and focused      // Remove from cart if quantity is 0 or empty

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [                  Expanded(      // This will be handled by the parent screen

                        Text(

                          '💰 Giá nhập gần nhất',                    child: Column(    }

                          style: TextStyle(

                            fontSize: 12,                      crossAxisAlignment: CrossAxisAlignment.start,  }

                            color: Colors.grey[600],

                          ),                      children: [

                        ),

                        const SizedBox(height: 2),                        Text(  void _onUnitChanged(String? value) {

                        Text(

                          lastPrice != null                           product.name,    if (value != null) {

                              ? _formatCurrency(lastPrice!)

                              : 'Chưa có giá',                          style: const TextStyle(      setState(() {

                          style: const TextStyle(

                            fontSize: 14,                            fontSize: 16,        _selectedUnit = value;

                            fontWeight: FontWeight.w600,

                            color: Colors.black87,                            fontWeight: FontWeight.w600,      });

                          ),

                        ),                            color: Colors.black87,      

                      ],

                    ),                          ),      // Re-add to cart with new unit if quantity exists

                  ),

                                            maxLines: 2,      final quantity = int.tryParse(_quantityController.text);

                  // Current stock

                  Expanded(                          overflow: TextOverflow.ellipsis,      if (quantity != null && quantity > 0) {

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,                        ),        widget.onAddToCart(widget.product, quantity, _selectedUnit);

                      children: [

                        Text(                        const SizedBox(height: 4),      }

                          '📦 Tồn kho',

                          style: TextStyle(                        if (product.sku != null) ...[    }

                            fontSize: 12,

                            color: Colors.grey[600],                          Text(  }

                          ),

                        ),                            product.sku!,

                        const SizedBox(height: 2),

                        Row(                            style: TextStyle(  Color _getCategoryColor() {

                          children: [

                            Text(                              fontSize: 14,    switch (widget.product.category) {

                              '$currentStock',

                              style: TextStyle(                              color: Colors.grey[600],      case ProductCategory.FERTILIZER:

                                fontSize: 14,

                                fontWeight: FontWeight.w600,                            ),        return Colors.green;

                                color: isLowStock ? Colors.red[600] : Colors.black87,

                              ),                          ),      case ProductCategory.PESTICIDE:

                            ),

                            if (isLowStock) ...[                          const SizedBox(height: 4),        return Colors.orange;

                              const SizedBox(width: 4),

                              Icon(                        ],      case ProductCategory.SEED:

                                Icons.warning_outlined,

                                size: 16,                        Container(        return Colors.brown;

                                color: Colors.red[600],

                              ),                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),    }

                            ],

                          ],                          decoration: BoxDecoration(  }

                        ),

                        if (isLowStock)                            color: categoryColor.withOpacity(0.1),

                          Text(

                            'Sắp hết hàng',                            borderRadius: BorderRadius.circular(4),  IconData _getCategoryIcon() {

                            style: TextStyle(

                              fontSize: 11,                          ),    switch (widget.product.category) {

                              color: Colors.red[600],

                            ),                          child: Text(      case ProductCategory.FERTILIZER:

                          ),

                      ],                            _getCategoryLabel(),        return Icons.eco;

                    ),

                  ),                            style: TextStyle(      case ProductCategory.PESTICIDE:

                ],

              ),                              fontSize: 12,        return Icons.bug_report;

              

              // Tap hint                              color: categoryColor,      case ProductCategory.SEED:

              const SizedBox(height: 12),

              Container(                              fontWeight: FontWeight.w500,        return Icons.grass;

                width: double.infinity,

                padding: const EdgeInsets.symmetric(vertical: 8),                            ),    }

                decoration: BoxDecoration(

                  color: Colors.grey[50],                          ),  }

                  borderRadius: BorderRadius.circular(6),

                  border: Border.all(color: Colors.grey[200]!),                        ),

                ),

                child: Text(                      ],  String _getCategoryLabel() {

                  isInCart ? '✅ Đã chọn - Chạm để chỉnh sửa' : '👆 Chạm để thêm vào giỏ',

                  textAlign: TextAlign.center,                    ),    switch (widget.product.category) {

                  style: TextStyle(

                    fontSize: 13,                  ),      case ProductCategory.FERTILIZER:

                    color: isInCart ? Colors.green[700] : Colors.grey[600],

                    fontWeight: isInCart ? FontWeight.w600 : FontWeight.normal,                          return 'Phân bón';

                  ),

                ),                  // Cart indicator - Simple      case ProductCategory.PESTICIDE:

              ),

            ],                  if (isInCart)        return 'Thuốc BVTV';

          ),

        ),                    Container(      case ProductCategory.SEED:

      ),

    );                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),        return 'Lúa giống';

  }

                      decoration: BoxDecoration(    }

  Color _getCategoryColor() {

    switch (product.category) {                        color: Colors.green,  }

      case ProductCategory.FERTILIZER:

        return Colors.green;                        borderRadius: BorderRadius.circular(12),

      case ProductCategory.PESTICIDE:

        return Colors.orange;                      ),  @override

      case ProductCategory.SEED:

        return Colors.brown;                      child: Text(  Widget build(BuildContext context) {

    }

  }                        '$cartQuantity',    final categoryColor = _getCategoryColor();



  IconData _getCategoryIcon() {                        style: const TextStyle(    final isLowStock = widget.currentStock <= 10;

    switch (product.category) {

      case ProductCategory.FERTILIZER:                          color: Colors.white,    

        return Icons.eco;

      case ProductCategory.PESTICIDE:                          fontSize: 12,    return Container(

        return Icons.bug_report;

      case ProductCategory.SEED:                          fontWeight: FontWeight.w600,      margin: const EdgeInsets.only(bottom: 12),

        return Icons.grass;

    }                        ),      decoration: BoxDecoration(

  }

                      ),        color: Colors.white,

  String _getCategoryLabel() {

    switch (product.category) {                    ),        borderRadius: BorderRadius.circular(12),

      case ProductCategory.FERTILIZER:

        return 'Phân bón';                ],        border: Border.all(

      case ProductCategory.PESTICIDE:

        return 'Thuốc BVTV';              ),          color: widget.isInCart ? Colors.green[200]! : Colors.grey[200]!,

      case ProductCategory.SEED:

        return 'Lúa giống';                        width: widget.isInCart ? 2 : 1,

    }

  }              const SizedBox(height: 16),        ),



  String _formatCurrency(double amount) {                      boxShadow: [

    if (amount == amount.toInt()) {

      return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';              // Essential info only - For decision making          BoxShadow(

    } else {

      String formatted = amount.toStringAsFixed(1);              Row(            color: Colors.black.withOpacity(0.04),

      formatted = formatted.replaceAll('.', ',');

      List<String> parts = formatted.split(',');                children: [            blurRadius: 4,

      parts[0] = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

      return '${parts.join(',')}₫';                  // Last price reference            offset: const Offset(0, 2),

    }

  }                  Expanded(          ),

}
                    child: Column(        ],

                      crossAxisAlignment: CrossAxisAlignment.start,      ),

                      children: [      child: Padding(

                        Text(        padding: const EdgeInsets.all(16),

                          '💰 Giá nhập gần nhất',        child: Column(

                          style: TextStyle(          crossAxisAlignment: CrossAxisAlignment.start,

                            fontSize: 12,          children: [

                            color: Colors.grey[600],            // Product header

                          ),            Row(

                        ),              crossAxisAlignment: CrossAxisAlignment.start,

                        const SizedBox(height: 2),              children: [

                        Text(                // Category icon

                          lastPrice != null                 Container(

                              ? _formatCurrency(lastPrice!)                  width: 40,

                              : 'Chưa có giá',                  height: 40,

                          style: const TextStyle(                  decoration: BoxDecoration(

                            fontSize: 14,                    color: categoryColor.withOpacity(0.1),

                            fontWeight: FontWeight.w600,                    borderRadius: BorderRadius.circular(8),

                            color: Colors.black87,                  ),

                          ),                  child: Icon(

                        ),                    _getCategoryIcon(),

                      ],                    color: categoryColor,

                    ),                    size: 20,

                  ),                  ),

                                  ),

                  // Current stock                

                  Expanded(                const SizedBox(width: 12),

                    child: Column(                

                      crossAxisAlignment: CrossAxisAlignment.start,                // Product info

                      children: [                Expanded(

                        Text(                  child: Column(

                          '📦 Tồn kho',                    crossAxisAlignment: CrossAxisAlignment.start,

                          style: TextStyle(                    children: [

                            fontSize: 12,                      Text(

                            color: Colors.grey[600],                        widget.product.name,

                          ),                        style: const TextStyle(

                        ),                          fontSize: 16,

                        const SizedBox(height: 2),                          fontWeight: FontWeight.w600,

                        Row(                          color: Colors.black87,

                          children: [                        ),

                            Text(                        maxLines: 2,

                              '$currentStock',                        overflow: TextOverflow.ellipsis,

                              style: TextStyle(                      ),

                                fontSize: 14,                      const SizedBox(height: 4),

                                fontWeight: FontWeight.w600,                      Text(

                                color: isLowStock ? Colors.red[600] : Colors.black87,                        widget.product.sku ?? 'Chưa có SKU',

                              ),                        style: TextStyle(

                            ),                          fontSize: 14,

                            if (isLowStock) ...[                          color: Colors.grey[600],

                              const SizedBox(width: 4),                        ),

                              Icon(                      ),

                                Icons.warning_outlined,                      const SizedBox(height: 4),

                                size: 16,                      Container(

                                color: Colors.red[600],                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                              ),                        decoration: BoxDecoration(

                            ],                          color: categoryColor.withOpacity(0.1),

                          ],                          borderRadius: BorderRadius.circular(4),

                        ),                        ),

                        if (isLowStock)                        child: Text(

                          Text(                          _getCategoryLabel(),

                            'Sắp hết hàng',                          style: TextStyle(

                            style: TextStyle(                            fontSize: 12,

                              fontSize: 11,                            color: categoryColor,

                              color: Colors.red[600],                            fontWeight: FontWeight.w500,

                            ),                          ),

                          ),                        ),

                      ],                      ),

                    ),                    ],

                  ),                  ),

                ],                ),

              ),                

                              // Remove cart indicator - users will input quantity manually

              // Tap hint              ],

              const SizedBox(height: 12),            ),

              Container(            

                width: double.infinity,            const SizedBox(height: 16),

                padding: const EdgeInsets.symmetric(vertical: 8),            

                decoration: BoxDecoration(            // Product stats

                  color: Colors.grey[50],            Row(

                  borderRadius: BorderRadius.circular(6),              children: [

                  border: Border.all(color: Colors.grey[200]!),                // Last price

                ),                Expanded(

                child: Text(                  child: Column(

                  isInCart ? '✅ Đã chọn - Chạm để chỉnh sửa' : '👆 Chạm để thêm vào giỏ',                    crossAxisAlignment: CrossAxisAlignment.start,

                  textAlign: TextAlign.center,                    children: [

                  style: TextStyle(                      Text(

                    fontSize: 13,                        '💰 Giá gần nhất',

                    color: isInCart ? Colors.green[700] : Colors.grey[600],                        style: TextStyle(

                    fontWeight: isInCart ? FontWeight.w600 : FontWeight.normal,                          fontSize: 12,

                  ),                          color: Colors.grey[600],

                ),                        ),

              ),                      ),

            ],                      const SizedBox(height: 2),

          ),                      Text(

        ),                        widget.lastPrice != null 

      ),                            ? '${_formatCurrency(widget.lastPrice!)}/${_selectedUnit}'

    );                            : 'Chưa có giá',

  }                        style: const TextStyle(

                          fontSize: 14,

  Color _getCategoryColor() {                          fontWeight: FontWeight.w600,

    switch (product.category) {                          color: Colors.black87,

      case ProductCategory.FERTILIZER:                        ),

        return Colors.green;                      ),

      case ProductCategory.PESTICIDE:                    ],

        return Colors.orange;                  ),

      case ProductCategory.SEED:                ),

        return Colors.brown;                

    }                // Current stock

  }                Expanded(

                  child: Column(

  IconData _getCategoryIcon() {                    crossAxisAlignment: CrossAxisAlignment.start,

    switch (product.category) {                    children: [

      case ProductCategory.FERTILIZER:                      Text(

        return Icons.eco;                        '📦 Tồn kho',

      case ProductCategory.PESTICIDE:                        style: TextStyle(

        return Icons.bug_report;                          fontSize: 12,

      case ProductCategory.SEED:                          color: Colors.grey[600],

        return Icons.grass;                        ),

    }                      ),

  }                      const SizedBox(height: 2),

                      Row(

  String _getCategoryLabel() {                        children: [

    switch (product.category) {                          Text(

      case ProductCategory.FERTILIZER:                            '${widget.currentStock} ${_selectedUnit}',

        return 'Phân bón';                            style: TextStyle(

      case ProductCategory.PESTICIDE:                              fontSize: 14,

        return 'Thuốc BVTV';                              fontWeight: FontWeight.w600,

      case ProductCategory.SEED:                              color: isLowStock ? Colors.red[600] : Colors.black87,

        return 'Lúa giống';                            ),

    }                          ),

  }                          if (isLowStock) ...[

                            const SizedBox(width: 4),

  String _formatCurrency(double amount) {                            Icon(

    if (amount == amount.toInt()) {                              Icons.warning_outlined,

      return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';                              size: 16,

    } else {                              color: Colors.red[600],

      String formatted = amount.toStringAsFixed(1);                            ),

      formatted = formatted.replaceAll('.', ',');                          ],

      List<String> parts = formatted.split(',');                        ],

      parts[0] = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');                      ),

      return '${parts.join(',')}₫';                      if (isLowStock)

    }                        Text(

  }                          'Sắp hết hàng',

}                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
                            // Clean quantity and unit inputs
            Row(
              children: [
                // Quantity input with auto-add and numeric keypad
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _quantityController,
                    focusNode: _quantityFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: false,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      FilteringTextInputFormatter.deny(RegExp(r'^0+')), // Prevent leading zeros
                    ],
                    decoration: InputDecoration(
                      labelText: 'Số lượng',
                      hintText: '1',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: widget.isInCart ? Colors.green : Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: widget.isInCart ? Colors.green : Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: widget.isInCart 
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : null,
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    onTap: () {
                      // Select all text when tapped for easy replacement
                      _quantityController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _quantityController.text.length,
                      );
                    },
                    onChanged: _onQuantityChanged,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Unit selector
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: 'Đơn vị',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _getUnitOptions().map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text(unit, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: _onUnitChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    // Format with thousand separators and decimal places
    if (amount == amount.toInt()) {
      // No decimal places needed
      return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
    } else {
      // Show decimal places
      String formatted = amount.toStringAsFixed(1);
      // Replace . with , for decimal separator (Vietnamese format)
      formatted = formatted.replaceAll('.', ',');
      // Add thousand separators
      List<String> parts = formatted.split(',');
      parts[0] = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
      return '${parts.join(',')}₫';
    }
  }
}