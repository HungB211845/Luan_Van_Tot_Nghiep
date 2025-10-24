import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/responsive.dart';
import '../../../../shared/utils/input_formatters.dart';
import '../../models/company.dart';
import '../../models/product.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../products/product_detail_screen.dart';
import 'company_transaction_history_screen.dart';
import 'bulk_product_add_screen.dart';
import '../../utils/unit_display_formatter.dart';

class CompanyDetailScreen extends StatefulWidget {
  final Company company;

  const CompanyDetailScreen({Key? key, required this.company}) : super(key: key);

  static const String routeName = '/company-detail';

  @override
  _CompanyDetailScreenState createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _showContactInfo = true;
  bool _isFabVisible = true;

  static const _fabAnimationDuration = Duration(milliseconds: 220);

  double get _fabYOffset => _isFabVisible ? 0 : 1.4;

  _StockDisplayData _fallbackStockDisplayData(Product product, int baseStock) {
    final baseUnitName = _normalizeBaseUnit(product.effectiveBaseUnit);
    final formatted = _formatQuantityDisplay(baseStock.toDouble());
    final display = baseUnitName.isEmpty ? formatted : '$formatted $baseUnitName';
    final full = '$baseStock${baseUnitName.isEmpty ? '' : ' $baseUnitName'}';
    return _StockDisplayData(display: display, full: full);
  }

  String _formatQuantityDisplay(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    if (parts.length != 2) {
      return fixed;
    }
    final integerPart = int.tryParse(parts.first) ?? value.truncate();
    final formattedInteger = AppFormatter.formatNumber(integerPart);
    final decimalPart = parts.last;
    return '$formattedInteger.$decimalPart';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Listen to scroll to hide/show contact info
    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset < 50;
      if (shouldShow != _showContactInfo) {
        setState(() {
          _showContactInfo = shouldShow;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanyProducts(widget.company.id);
    });
  }

  Future<_StockDisplayData> _getStockDisplayData(
    Product product,
    int baseStock,
    ProductProvider provider,
  ) async {
    try {
      final units = await provider.getProductUnits(product.id);

      if (units.isEmpty) {
        return _fallbackStockDisplayData(product, baseStock);
      }

      final baseUnitName = UnitDisplayFormatter.resolveBaseUnitName(
        units: units,
        fallback: product.effectiveBaseUnit,
      );

      final preferred = UnitDisplayFormatter.preferredQuantity(
        baseQuantity: baseStock.toDouble(),
        units: units,
        baseUnitName: baseUnitName,
      );

      if (preferred == null) {
        return _fallbackStockDisplayData(product, baseStock);
      }

      final truncated = _formatQuantityDisplay(preferred.primaryQuantity);
      final label = UnitDisplayFormatter.simpleUnitName(preferred.unit);
      final preciseQuantity = preferred.primaryQuantity.toString();
      final fallbackBase = _normalizeBaseUnit(product.effectiveBaseUnit);
      final baseDisplay = AppFormatter.formatNumber(baseStock);

      final full = fallbackBase.isEmpty
          ? '$preciseQuantity $label'
          : '$preciseQuantity $label • $baseDisplay $fallbackBase';

      return _StockDisplayData(
        display: '$truncated $label',
        full: full,
      );
    } catch (_) {
      return _fallbackStockDisplayData(product, baseStock);
    }
  }

  String _normalizeBaseUnit(String baseUnitName) {
    if (baseUnitName.isEmpty || baseUnitName.toLowerCase() == 'đơn vị') {
      return '';
    }
    return baseUnitName.toLowerCase();
  }

  @override
  void didUpdateWidget(CompanyDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.company.id != oldWidget.company.id) {
      // Company has changed in the master-detail view, load the new products.
      context.read<CompanyProvider>().loadCompanyProducts(widget.company.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {}); // Rebuild to apply filter
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification.direction == ScrollDirection.reverse && _isFabVisible) {
      setState(() => _isFabVisible = false);
    } else if (notification.direction == ScrollDirection.forward && !_isFabVisible) {
      setState(() => _isFabVisible = true);
    } else if (notification.direction == ScrollDirection.idle &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent &&
        !_isFabVisible) {
      setState(() => _isFabVisible = true);
    }
    return false;
  }

  Future<void> _makePhoneCall(Company company) async {
    final phone = company.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có số điện thoại'), backgroundColor: Colors.red),
      );
      return;
    }

    final telUri = Uri(scheme: 'tel', path: phone);
    final telPromptUri = Uri(scheme: 'telprompt', path: phone);

    Future<bool> attemptLaunch(Uri uri, LaunchMode mode, String label) async {
      try {
        final result = await launchUrl(uri, mode: mode);
        debugPrint('📞 launch attempt [$label] => $result');
        return result;
      } catch (err) {
        debugPrint('❌ launch attempt [$label] threw $err');
        return false;
      }
    }

    try {
      debugPrint('📞 Attempting to launch phone call for $phone');
      final canLaunchTel = await canLaunchUrl(telUri);
      debugPrint('📞 canLaunchUrl tel result: $canLaunchTel');
    } catch (err) {
      debugPrint('❌ canLaunchUrl threw $err');
    }

    final attempts = <Map<String, dynamic>>[
      {
        'uri': telUri,
        'mode': LaunchMode.platformDefault,
        'label': 'tel/platformDefault',
      },
      if (Platform.isIOS)
        {
          'uri': telPromptUri,
          'mode': LaunchMode.platformDefault,
          'label': 'telprompt/platformDefault',
        },
      {
        'uri': telUri,
        'mode': LaunchMode.externalApplication,
        'label': 'tel/externalApplication',
      },
      if (Platform.isIOS)
        {
          'uri': telPromptUri,
          'mode': LaunchMode.externalApplication,
          'label': 'telprompt/externalApplication',
        },
    ];

    for (final attempt in attempts) {
      final launched = await attemptLaunch(
        attempt['uri'] as Uri,
        attempt['mode'] as LaunchMode,
        attempt['label'] as String,
      );
      if (launched) {
        return;
      }
    }

    if (!mounted) return;
    final message = Platform.isIOS
        ? 'Simulator không hỗ trợ gọi điện. Hãy kiểm tra trên thiết bị thật.'
        : 'Không thể mở ứng dụng điện thoại.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _deleteCompany(Company company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Mày có chắc muốn xóa nhà cung cấp "${company.name}" không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Xóa'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final provider = context.read<CompanyProvider>();
      final success = await provider.deleteCompany(company.id);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(); // Quay về danh sách
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa nhà cung cấp'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: ${provider.errorMessage}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _editCompany(Company company) {
    Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.editCompany, arguments: company);
  }

  void _viewTransactionHistory(Company company) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => CompanyTransactionHistoryScreen(company: company),
      ),
    );
  }

  void _addBulkProducts(Company company) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (context) => BulkProductAddScreen(company: company),
      ),
    );

    // If the screen was popped with a `true` result, reload the data.
    if (result == true && mounted) {
      context.read<CompanyProvider>().loadCompanyProducts(company.id);
    }
  }

  List<Product> _getFilteredProducts(List<Product> products) {
    ProductCategory? category;
    switch (_tabController.index) {
      case 0:
        return products; // Tất cả
      case 1:
        category = ProductCategory.PESTICIDE;
        break;
      case 2:
        category = ProductCategory.FERTILIZER;
        break;
      case 3:
        category = ProductCategory.SEED;
        break;
    }
    return products.where((p) => p.category == category).toList();
  }

  Future<void> _showEditPriceDialog(Product product) async {
    final priceController = TextEditingController(
      text: AppFormatter.formatNumber(product.currentSellingPrice),
    );
    final formKey = GlobalKey<FormState>();
    final productProvider = context.read<ProductProvider>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: Colors.white,
          title: Text('Chỉnh sửa giá bán', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Giá bán mới',
                prefixText: 'đ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập giá';
                }
                return null;
              },
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    child: const Text('Hủy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    child: const Text('Lưu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final newPrice = double.tryParse(priceController.text.replaceAll('.', '')) ?? 0.0;
                        
                        final success = await productProvider.updateProductPrice(
                          product.id,
                          newPrice,
                        );

                        if (!mounted) return;

                        // Force refresh of the product list in CompanyProvider
                        if (success) {
                          await context.read<CompanyProvider>().loadCompanyProducts(widget.company.id);
                        }

                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Cập nhật giá thành công!'
                                : 'Lỗi: ${productProvider.errorMessage}'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    // Get the company ID from the initial widget.company
    final companyId = widget.company.id;

    // WATCH the CompanyProvider to get the latest list of companies
    final companyProvider = context.watch<CompanyProvider>();

    // Find the specific company from the provider's current list
    // Fallback to widget.company if not found (e.g., during initial load or if deleted)
    final liveCompany = companyProvider.companies.firstWhere(
      (c) => c.id == companyId,
      orElse: () => widget.company,
    );

    return ResponsiveScaffold(
      title: liveCompany.name,
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'Lịch sử Giao dịch',
          onPressed: () => _viewTransactionHistory(liveCompany),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Sửa',
          onPressed: () => _editCompany(liveCompany),
        ),
      ],
        body: Column(
          children: [
            // Tab bar
            Container(
              color: Colors.green,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Tất Cả'),
                  Tab(text: 'Thuốc BVTV'),
                  Tab(text: 'Phân Bón'),
                  Tab(text: 'Lúa Giống'),
                ],
              ),
            ),
            
            // Contact info card (collapsible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showContactInfo ? null : 0,
              curve: Curves.easeInOut,
              child: _showContactInfo ? _buildContactInfoCard(liveCompany) : const SizedBox.shrink(),
            ),

            // Product list
            Expanded(
              child: Consumer<CompanyProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allProducts = provider.companyProducts;
                  final filteredProducts = _getFilteredProducts(allProducts);

                  if (filteredProducts.isEmpty) {
                    return _buildEmptyWidget();
                  }

                  return NotificationListener<UserScrollNotification>(
                    onNotification: _handleUserScroll,
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await provider.loadCompanyProducts(liveCompany.id);
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(context.sectionPadding),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _buildProductCard(context, product, provider);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: AnimatedSlide(
          duration: _fabAnimationDuration,
          curve: Curves.easeOut,
          offset: Offset(0, _fabYOffset),
          child: AnimatedOpacity(
            duration: _fabAnimationDuration,
            opacity: _isFabVisible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_isFabVisible,
              child: FloatingActionButton(
                onPressed: () => _addBulkProducts(liveCompany),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                tooltip: 'Thêm nhiều sản phẩm cùng lúc',
                child: const Icon(CupertinoIcons.plus),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildContactInfoCard(Company company) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (company.contactPerson != null && company.contactPerson!.isNotEmpty)
              _buildContactRow(Icons.person, company.contactPerson!),
            if (company.phone != null && company.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: company.phone!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã sao chép: ${company.phone!}'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          company.phone!, 
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () => _makePhoneCall(company),
                    tooltip: 'Gọi điện',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.grey),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: company.phone!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép: ${company.phone!}'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    tooltip: 'Copy số điện thoại',
                  ),
                ],
              ),
            ],
            if (company.address != null && company.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildContactRow(Icons.location_on, company.address!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 16),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    CompanyProvider provider,
  ) {
    // Use the data directly from the product object passed in.
    // The list is refreshed by CompanyProvider, so this data is fresh.
    final stock = product.availableStock ?? 0;
    final currentPrice = product.currentSellingPrice;
    final productProvider = context.read<ProductProvider>();

    final isLowStock = stock <= 10;
    final isBanned = product.isBanned;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final categoryColor = _getCategoryColor(product.category);
    final priceColor = currentPrice > 0 ? Colors.green[700]! : Colors.grey[600]!;
    final currencyText = currentPrice > 0
        ? AppFormatter.formatCurrencyWithSymbol(currentPrice)
        : 'Chưa có giá';
    final fallbackStockData = _fallbackStockDisplayData(product, stock);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Select product and navigate to detail (full-screen without bottom nav)
          context.read<ProductProvider>().selectProduct(product);
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => const ProductDetailScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(product.category),
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ) ??
                                    const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isBanned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CẤM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (product.sku != null &&
                            product.sku!.trim().isNotEmpty)
                          Text(
                            'SKU: ${product.sku}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        Text(
                          product.categoryDisplayName,
                          style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ) ??
                              TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Edit price button
                  IconButton(
                    onPressed: () => _showEditPriceDialog(product),
                    icon: Icon(
                      Icons.attach_money,
                      color: Colors.green[700],
                    ),
                    tooltip: 'Chỉnh sửa giá bán',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Price and stock row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currencyText,
                        style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: priceColor,
                            ) ??
                            TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: priceColor,
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: FutureBuilder<_StockDisplayData>(
                      future: _getStockDisplayData(product, stock, productProvider),
                      builder: (context, snapshot) {
                        final data = snapshot.data ?? fallbackStockData;
                        final isLow = isLowStock;
                        final color = isLow ? Colors.orange[700]! : Colors.blue[600]!;
                        final icon = isLow
                            ? CupertinoIcons.exclamationmark_triangle_fill
                            : CupertinoIcons.cube_box_fill;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger
                              ..removeCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text('SL chính xác: ${data.full}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: color, size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'SL: ${data.display}',
                                  style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ) ??
                                      TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có sản phẩm nào',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyMessage(),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_tabController.index) {
      case 1:
        return 'Không có thuốc BVTV nào từ nhà cung cấp này';
      case 2:
        return 'Không có phân bón nào từ nhà cung cấp này';
      case 3:
        return 'Không có lúa giống nào từ nhà cung cấp này';
      default:
        return 'Không có sản phẩm nào từ nhà cung cấp này';
    }
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
  }

  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Colors.green;
      case ProductCategory.PESTICIDE:
        return Colors.orange;
      case ProductCategory.SEED:
        return Colors.brown;
    }
  }
}

class _StockDisplayData {
  final String display;
  final String full;

  const _StockDisplayData({
    required this.display,
    required this.full,
  });
}
