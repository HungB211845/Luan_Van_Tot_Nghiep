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
import '../../../core/routing/route_names.dart';

const String _recentSearchesKey = 'recent_searches';

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

  List<String> _recentSearches = [];
  List<Product> _recentProducts = [];
  List<Customer> _recentCustomers = [];
  List<Transaction> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _loadSuggestionsAndRecentSearches();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
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
        _isLoading = false;
      });
      return;
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _searchController.text.trim() == query) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) return;
    setState(() => _isLoading = true);
    await _saveRecentSearch(query);
    try {
      await Future.wait([
        _searchProducts(query),
        _searchTransactions(query),
        _searchCustomers(query),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchProducts(String query) async {
    final productProvider = context.read<ProductProvider>();
    await productProvider.searchProducts(query);
    if (mounted) {
      setState(() {
        _productResults = productProvider.products.take(5).toList();
      });
    }
  }

  Future<void> _searchTransactions(String query) async {
    final transactionProvider = context.read<TransactionProvider>();
    final allTransactions = transactionProvider.transactions;
    final searchQuery = query.toLowerCase();
    final results = allTransactions.where((tx) {
      final txId = tx.id.toLowerCase();
      final customerName = (tx.customerName ?? '').toLowerCase();
      return txId.contains(searchQuery) || customerName.contains(searchQuery);
    }).take(5).toList();
    if (mounted) {
      setState(() => _transactionResults = results);
    }
  }

  Future<void> _searchCustomers(String query) async {
    final customerProvider = context.read<CustomerProvider>();
    final allCustomers = customerProvider.customers;
    final searchQuery = query.toLowerCase();
    final results = allCustomers.where((customer) {
      final name = customer.name.toLowerCase();
      final phone = (customer.phone ?? '').toLowerCase();
      return name.contains(searchQuery) || phone.contains(searchQuery);
    }).take(5).toList();
    if (mounted) {
      setState(() => _customerResults = results);
    }
  }

  Future<void> _loadSuggestionsAndRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final productProvider = context.read<ProductProvider>();
    final customerProvider = context.read<CustomerProvider>();
    final transactionProvider = context.read<TransactionProvider>();

    setState(() {
      _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
      if (productProvider.products.isNotEmpty) {
        _recentProducts = productProvider.products.take(3).toList();
      }
      if (customerProvider.customers.isNotEmpty) {
        _recentCustomers = customerProvider.customers.take(3).toList();
      }
      if (transactionProvider.transactions.isNotEmpty) {
        _recentTransactions = transactionProvider.transactions.take(3).toList();
      }
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updatedSearches = [
      query,
      ..._recentSearches.where((s) => s != query)
    ];
    _recentSearches = updatedSearches.take(5).toList();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
    setState(() {});
  }

  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: query.length));
    _performSearch(query);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    setState(() {
      _recentSearches.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchHeader(),
              Expanded(child: _buildSearchResults()),
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
          Expanded(
            child: Hero(
              tag: 'global_search',
              child: Material(
                color: Colors.transparent,
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
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
      return const Center(child: CircularProgressIndicator());
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
        if (_productResults.isNotEmpty) ...[
          _buildSectionHeader('Sản phẩm', _productResults.length),
          const SizedBox(height: 8),
          ..._productResults.map(_buildProductResult),
          const SizedBox(height: 24),
        ],
        if (_transactionResults.isNotEmpty) ...[
          _buildSectionHeader('Giao dịch', _transactionResults.length),
          const SizedBox(height: 8),
          ..._transactionResults.map(_buildTransactionResult),
          const SizedBox(height: 24),
        ],
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
        if (_recentSearches.isNotEmpty) ...[
          _buildRecentSearchesHeader(),
          const SizedBox(height: 12),
          ..._recentSearches.map(_buildRecentSearchItem),
          const SizedBox(height: 32),
        ],
        _buildSectionTitle('Gợi ý cho bạn'),
        const SizedBox(height: 12),
        if (_recentProducts.isNotEmpty) ...[
          _buildSubSectionTitle('Sản phẩm'),
          const SizedBox(height: 8),
          ..._recentProducts.map(_buildSuggestionProductItem),
          const SizedBox(height: 20),
        ],
        if (_recentCustomers.isNotEmpty) ...[
          _buildSubSectionTitle('Khách hàng'),
          const SizedBox(height: 8),
          ..._recentCustomers.map(_buildSuggestionCustomerItem),
          const SizedBox(height: 20),
        ],
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
          'Tồn kho: ${product.availableStock ?? 0} • ${AppFormatter.formatCurrency(product.currentSellingPrice)}',
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
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            RouteNames.customerDetail,
            arguments: customer,
          );
        },
      ),
    );
  }

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
        Expanded(
          child: Text(
            'TÌM KIẾM GẦN ĐÂY',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _clearRecentSearches,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.clear,
              color: Colors.white,
              size: 12,
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
          AppFormatter.formatCurrency(product.currentSellingPrice),
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
