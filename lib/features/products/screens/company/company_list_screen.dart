import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../models/company.dart';
import '../../providers/company_provider.dart';

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({Key? key}) : super(key: key);

  static const String routeName = RouteNames.companies;

  @override
  _CompanyListScreenState createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Load companies when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Debounce search để tránh lag khi user đang gõ
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<CompanyProvider>().setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CompanyProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.companies.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.hasError) {
            return Center(
              child: Text('Đã xảy ra lỗi: ${provider.errorMessage}'),
            );
          }

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // AppBar với title only
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    title: const Text('Nhà Cung Cấp'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Thêm nhà cung cấp',
                        onPressed: () {
                          Navigator.of(context).pushNamed(RouteNames.addCompany);
                        },
                      ),
                    ],
                  ),

                  // Search bar (separate sliver)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên, SĐT, người liên hệ...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: provider.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    provider.setSearchQuery('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // Filter chips (separate sliver)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _buildFilterChip(
                            context,
                            'Có SĐT',
                            CompanyFilterType.hasPhone,
                            Icons.phone,
                            provider,
                          ),
                          _buildFilterChip(
                            context,
                            'Có địa chỉ',
                            CompanyFilterType.hasAddress,
                            Icons.location_on,
                            provider,
                          ),
                          _buildFilterChip(
                            context,
                            'Có sản phẩm',
                            CompanyFilterType.hasProducts,
                            Icons.inventory_2_outlined,
                            provider,
                          ),
                          _buildFilterChip(
                            context,
                            'Có đơn hàng',
                            CompanyFilterType.hasOrders,
                            Icons.receipt_long,
                            provider,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // Grouped company list với section headers
                  _buildGroupedCompanyList(provider),
                ],
              ),

              // Alphabet index bar (bên phải)
              if (provider.availableSections.isNotEmpty)
                Positioned(
                  right: 2,
                  top: MediaQuery.of(context).padding.top + 200,
                  bottom: 100,
                  child: _buildAlphabetIndex(provider.availableSections),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.receipt_long),
        label: const Text('Tạo Đơn Nhập Hàng'),
        onPressed: () {
          Navigator.of(context).pushNamed(RouteNames.createPurchaseOrder);
        },
      ),
    );
  }

  // Build filter chip
  Widget _buildFilterChip(
    BuildContext context,
    String label,
    CompanyFilterType filterType,
    IconData icon,
    CompanyProvider provider,
  ) {
    final isActive = provider.activeFilters.contains(filterType);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isActive,
        onSelected: (_) => provider.toggleFilter(filterType),
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  // Build grouped list với section headers
  Widget _buildGroupedCompanyList(CompanyProvider provider) {
    final groupedCompanies = provider.groupedCompanies;

    if (groupedCompanies.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('Không tìm thấy nhà cung cấp nào')),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Calculate which section and item
          int currentIndex = 0;
          for (var section in provider.availableSections) {
            final companies = groupedCompanies[section]!;

            // Section header
            if (currentIndex == index) {
              return _buildSectionHeader(section);
            }
            currentIndex++;

            // Company items
            for (var company in companies) {
              if (currentIndex == index) {
                return _buildCompanyTile(company);
              }
              currentIndex++;
            }
          }
          return null;
        },
        childCount: _calculateTotalItems(groupedCompanies, provider.availableSections),
      ),
    );
  }

  int _calculateTotalItems(
    Map<String, List<Company>> groupedCompanies,
    List<String> sections,
  ) {
    int total = 0;
    for (var section in sections) {
      total += 1; // Section header
      total += groupedCompanies[section]!.length; // Company items
    }
    return total;
  }

  // Section header (A, B, C, ...)
  Widget _buildSectionHeader(String section) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Text(
        section,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Company tile
  Widget _buildCompanyTile(Company company) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.primaries[
          company.name.hashCode % Colors.primaries.length
        ],
        child: Text(
          company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        company.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        company.phone ?? 'Không có SĐT',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteNames.companyDetail,
          arguments: company,
        );
      },
    );
  }

  // Alphabet index bar (A-Z)
  Widget _buildAlphabetIndex(List<String> sections) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.grey[300]?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: sections.map((section) {
          return GestureDetector(
            onTap: () => _scrollToSection(section),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                section,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Scroll to section khi tap vào index (iOS-style smooth scroll)
  void _scrollToSection(String section) {
    final provider = context.read<CompanyProvider>();
    final sections = provider.availableSections;
    final sectionIndex = sections.indexOf(section);

    if (sectionIndex == -1) return;

    // Calculate exact scroll offset
    // AppBar height (56) + Search bar (80) + Filter chips (58) + spacing (8)
    double estimatedOffset = 0;

    // Add heights of all sections before target section
    for (int i = 0; i < sectionIndex; i++) {
      estimatedOffset += 40; // Section header height
      estimatedOffset += provider.groupedCompanies[sections[i]]!.length * 72; // ListTile height
    }

    // Clamp to valid range
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = estimatedOffset.clamp(0.0, maxScroll);

    // iOS-style smooth scroll với easeOut curve
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }
}
