import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/products/models/product.dart';
import '../../../features/pos/models/transaction.dart';
import '../../../features/customers/models/customer.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../features/pos/providers/transaction_provider.dart';
import '../../../features/customers/providers/customer_provider.dart';
import '../../../shared/utils/formatter.dart';
import '../../../shared/utils/datetime_helpers.dart';
import '../../../core/routing/route_names.dart';

/// Global Search Screen - Unified search across all app content
/// Features: Hero animation, real-time search, multi-category results
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Product> _productResults = [];
  List<Transaction> _transactionResults = [];
  List<Customer> _customerResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 SEARCH: Global Search Screen initialized');

    // Auto-focus search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      debugPrint('🔍 SEARCH: Search field focused');
    });

    // Listen to search input with debouncing
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    debugPrint('🔍 SEARCH: Query changed to: "$query"');

    if (query.isEmpty) {
      debugPrint('🔍 SEARCH: Query empty, clearing results');
      setState(() {
        _productResults.clear();
        _transactionResults.clear();
        _customerResults.clear();
      });
      return;
    }

    // Simple debouncing - search after 300ms delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchController.text.trim() == query) {
        debugPrint('🔍 SEARCH: Performing search for: "$query"');
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      debugPrint('🔍 SEARCH: Query too short: "$query" (${query.length} chars)');
      return; // Minimum 2 characters
    }

    debugPrint('🔍 SEARCH: Starting search for: "$query"');
    setState(() => _isLoading = true);

    try {
      // Search in parallel for better performance
      await Future.wait([
        _searchProducts(query),
        _searchTransactions(query),
        _searchCustomers(query),
      ]);
      debugPrint('🔍 SEARCH: Search completed successfully');
    } catch (e) {
      // Handle search errors gracefully
      debugPrint('🚨 SEARCH ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchProducts(String query) async {
    try {
      debugPrint('🔍 SEARCH: Searching products for: "$query"');
      final productProvider = context.read<ProductProvider>();
      await productProvider.searchProducts(query);

      if (mounted) {
        final results = productProvider.products.take(5).toList();
        debugPrint('🔍 SEARCH: Found ${results.length} products');
        setState(() {
          _productResults = results;
        });
      }
    } catch (e) {
      debugPrint('🚨 SEARCH ERROR: Product search failed: $e');
    }
  }

  Future<void> _searchTransactions(String query) async {
    try {
      debugPrint('🔍 SEARCH: Searching transactions for: "$query"');
      final transactionProvider = context.read<TransactionProvider>();
      // Search transactions by ID or customer name
      final allTransactions = transactionProvider.transactions;
      debugPrint('🔍 SEARCH: Total transactions available: ${allTransactions.length}');

      final results = allTransactions.where((tx) {
        final txId = tx.id.toLowerCase();
        final customerName = (tx.customerName ?? '').toLowerCase();
        final searchQuery = query.toLowerCase();

        return txId.contains(searchQuery) ||
               customerName.contains(searchQuery);
      }).take(5).toList();

      debugPrint('🔍 SEARCH: Found ${results.length} transactions');
      if (mounted) {
        setState(() => _transactionResults = results);
      }
    } catch (e) {
      debugPrint('🚨 SEARCH ERROR: Transaction search failed: $e');
    }
  }

  Future<void> _searchCustomers(String query) async {
    try {
      debugPrint('🔍 SEARCH: Searching customers for: "$query"');
      final customerProvider = context.read<CustomerProvider>();
      // Search customers by name or phone
      final allCustomers = customerProvider.customers;
      debugPrint('🔍 SEARCH: Total customers available: ${allCustomers.length}');

      final results = allCustomers.where((customer) {
        final name = customer.name.toLowerCase();
        final phone = (customer.phone ?? '').toLowerCase();
        final searchQuery = query.toLowerCase();

        return name.contains(searchQuery) ||
               phone.contains(searchQuery);
      }).take(5).toList();

      debugPrint('🔍 SEARCH: Found ${results.length} customers');
      if (mounted) {
        setState(() => _customerResults = results);
      }
    } catch (e) {
      debugPrint('🚨 SEARCH ERROR: Customer search failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header with Hero Animation
            _buildSearchHeader(),

            // Search Results
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.of(context).pop(),
          ),

          const SizedBox(width: 8),

          // Search field with Hero animation
          Expanded(
            child: Hero(
              tag: 'global_search',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm, giao dịch...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                CupertinoIcons.clear,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _focusNode.requestFocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.trim().isEmpty) {
      return _buildEmptyState();
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final hasResults = _productResults.isNotEmpty ||
                      _transactionResults.isNotEmpty ||
                      _customerResults.isNotEmpty;

    if (!hasResults) {
      return _buildNoResultsState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Product Results
        if (_productResults.isNotEmpty) ...[
          _buildSectionHeader('Sản phẩm', _productResults.length),
          const SizedBox(height: 8),
          ..._productResults.map(_buildProductResult),
          const SizedBox(height: 24),
        ],

        // Transaction Results
        if (_transactionResults.isNotEmpty) ...[
          _buildSectionHeader('Giao dịch', _transactionResults.length),
          const SizedBox(height: 8),
          ..._transactionResults.map(_buildTransactionResult),
          const SizedBox(height: 24),
        ],

        // Customer Results
        if (_customerResults.isNotEmpty) ...[
          _buildSectionHeader('Khách hàng', _customerResults.length),
          const SizedBox(height: 8),
          ..._customerResults.map(_buildCustomerResult),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Tìm kiếm toàn bộ ứng dụng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Sản phẩm, giao dịch, khách hàng và nhiều hơn nữa',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy kết quả',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thử tìm kiếm với từ khóa khác',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          '$count kết quả',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProductResult(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            CupertinoIcons.cube_box,
            color: Colors.green,
            size: 24,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Tồn kho: ${product.availableStock ?? 0} • ${AppFormatter.formatCurrency(product.currentPrice ?? 0)}',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          color: Colors.grey,
          size: 20,
        ),
        onTap: () {
          // Navigate to product detail
          Navigator.of(context).pushNamed(
            RouteNames.productDetail,
            arguments: product,
          );
        },
      ),
    );
  }

  Widget _buildTransactionResult(Transaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            CupertinoIcons.doc_text,
            color: Colors.blue,
            size: 24,
          ),
        ),
        title: Text(
          'Giao dịch #${transaction.id.substring(0, 8)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${transaction.customerName ?? 'Khách lẻ'} • ${AppFormatter.formatDateTime(transaction.createdAt)}',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppFormatter.formatCurrency(transaction.totalAmount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to transaction detail
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildCustomerResult(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            CupertinoIcons.person,
            color: Colors.orange,
            size: 24,
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          customer.phone ?? 'Chưa có số điện thoại',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          color: Colors.grey,
          size: 20,
        ),
        onTap: () {
          // TODO: Navigate to customer detail
          Navigator.of(context).pop();
        },
      ),
    );
  }
}