import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Recent searches and suggestions
  List<String> _recentSearches = [];
  List<Product> _recentProducts = [];
  List<Customer> _recentCustomers = [];
  List<Transaction> _recentTransactions = [];

  @override
  void initState() {
    super.initState();

    // Auto-focus search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    // Listen to search input with debouncing
    _searchController.addListener(_onSearchChanged);

    // Load suggestions for empty state
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
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
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      return; // Minimum 2 characters
    }

    setState(() => _isLoading = true);

    // Save search to recent searches
    _saveRecentSearch(query);

    try {
      // Search in parallel for better performance
      await Future.wait([
        _searchProducts(query),
        _searchTransactions(query),
        _searchCustomers(query),
      ]);
    } catch (e) {
      // Handle search errors gracefully
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchProducts(String query) async {
    try {
      final productProvider = context.read<ProductProvider>();
      await productProvider.searchProducts(query);

      if (mounted) {
        final results = productProvider.products.take(5).toList();
        setState(() {
          _productResults = results;
        });
      }
    } catch (e) {
    }
  }

  Future<void> _searchTransactions(String query) async {
    try {
      final transactionProvider = context.read<TransactionProvider>();
      // Search transactions by ID or customer name
      final allTransactions = transactionProvider.transactions;

      final results = allTransactions.where((tx) {
        final txId = tx.id.toLowerCase();
        final customerName = (tx.customerName ?? '').toLowerCase();
        final searchQuery = query.toLowerCase();

        return txId.contains(searchQuery) ||
               customerName.contains(searchQuery);
      }).take(5).toList();

      if (mounted) {
        setState(() => _transactionResults = results);
      }
    } catch (e) {
    }
  }

  Future<void> _searchCustomers(String query) async {
    try {
      final customerProvider = context.read<CustomerProvider>();
      // Search customers by name or phone
      final allCustomers = customerProvider.customers;

      final results = allCustomers.where((customer) {
        final name = customer.name.toLowerCase();
        final phone = (customer.phone ?? '').toLowerCase();
        final searchQuery = query.toLowerCase();

        return name.contains(searchQuery) ||
               phone.contains(searchQuery);
      }).take(5).toList();

      if (mounted) {
        setState(() => _customerResults = results);
      }
    } catch (e) {
    }
  }

  /// Load suggestions for empty state
  Future<void> _loadSuggestions() async {
    try {
      // Load recent searches from local storage (simplified with hardcoded data for now)
      _recentSearches = ['anh 3', 'NPK', 'công nợ', 'hóa đơn tháng 9'];

      // Load recent/suggested items
      final productProvider = context.read<ProductProvider>();
      final customerProvider = context.read<CustomerProvider>();
      final transactionProvider = context.read<TransactionProvider>();

      // Get recent products (first 3)
      if (productProvider.products.isNotEmpty) {
        _recentProducts = productProvider.products.take(3).toList();
      }

      // Get recent customers (first 3)
      if (customerProvider.customers.isNotEmpty) {
        _recentCustomers = customerProvider.customers.take(3).toList();
      }

      // Get recent transactions (first 3)
      if (transactionProvider.transactions.isNotEmpty) {
        _recentTransactions = transactionProvider.transactions.take(3).toList();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
    }
  }

  /// Save search query to recent searches
  void _saveRecentSearch(String query) {
    if (query.trim().isEmpty) return;

    // Remove if already exists to avoid duplicates
    _recentSearches.remove(query);

    // Add to beginning of list
    _recentSearches.insert(0, query);

    // Keep only last 5 searches
    if (_recentSearches.length > 5) {
      _recentSearches = _recentSearches.take(5).toList();
    }

    // TODO: Save to SharedPreferences for persistence
  }

  /// Handle tap on recent search
  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  /// Clear all recent searches
  void _clearRecentSearches() {
    setState(() {
      _recentSearches.clear();
    });
    // TODO: Clear from SharedPreferences as well
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark, // Dark icons on green background
        statusBarBrightness: Brightness.light, // For Android compatibility
      ),
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: Colors.green,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
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

          const SizedBox(width: 12),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w400,
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recent Searches Section
        if (_recentSearches.isNotEmpty) ...[
          _buildRecentSearchesHeader(),
          const SizedBox(height: 12),
          ..._recentSearches.map(_buildRecentSearchItem),
          const SizedBox(height: 32),
        ],

        // Suggestions Section
        _buildSectionTitle('Gợi ý cho bạn'),
        const SizedBox(height: 12),

        // Recent Products
        if (_recentProducts.isNotEmpty) ...[
          _buildSubSectionTitle('Sản phẩm'),
          const SizedBox(height: 8),
          ..._recentProducts.map(_buildSuggestionProductItem),
          const SizedBox(height: 20),
        ],

        // Recent Customers
        if (_recentCustomers.isNotEmpty) ...[
          _buildSubSectionTitle('Khách hàng'),
          const SizedBox(height: 8),
          ..._recentCustomers.map(_buildSuggestionCustomerItem),
          const SizedBox(height: 20),
        ],

        // Recent Transactions
        if (_recentTransactions.isNotEmpty) ...[
          _buildSubSectionTitle('Giao dịch gần đây'),
          const SizedBox(height: 8),
          ..._recentTransactions.take(2).map(_buildSuggestionTransactionItem),
        ],
      ],
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
          // Navigate to transaction detail screen
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            RouteNames.transactionDetail,
            arguments: transaction,
          );
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
          // Navigate to customer detail screen
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            RouteNames.customerDetail,
            arguments: customer,
          );
        },
      ),
    );
  }

  // Helper methods for empty state UI components

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRecentSearchesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'TÌM KIẾM GẦN ĐÂY',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        GestureDetector(
          onTap: _clearRecentSearches,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.clear,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildRecentSearchItem(String query) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: const Icon(
          CupertinoIcons.clock,
          color: Colors.grey,
          size: 20,
        ),
        title: Text(
          query,
          style: const TextStyle(fontSize: 16),
        ),
        onTap: () => _onRecentSearchTap(query),
      ),
    );
  }

  Widget _buildSuggestionProductItem(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            CupertinoIcons.cube_box,
            color: Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          AppFormatter.formatCurrency(product.currentPrice ?? 0),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          color: Colors.grey,
          size: 16,
        ),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            RouteNames.productDetail,
            arguments: product,
          );
        },
      ),
    );
  }

  Widget _buildSuggestionCustomerItem(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            CupertinoIcons.person,
            color: Colors.orange,
            size: 20,
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          customer.phone ?? 'Chưa có SĐT',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          color: Colors.grey,
          size: 16,
        ),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            RouteNames.customerDetail,
            arguments: customer,
          );
        },
      ),
    );
  }

  Widget _buildSuggestionTransactionItem(Transaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            CupertinoIcons.doc_text,
            color: Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          'Giao dịch #${transaction.id.substring(0, 8)}',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          AppFormatter.formatCurrency(transaction.totalAmount),
          style: const TextStyle(
            color: Colors.green,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          color: Colors.grey,
          size: 16,
        ),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            RouteNames.transactionDetail,
            arguments: transaction,
          );
        },
      ),
    );
  }
}