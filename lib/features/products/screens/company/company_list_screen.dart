import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/route_names.dart';
import '../../../../shared/utils/responsive.dart';
import '../../models/company.dart';
import '../../providers/company_provider.dart';
import 'company_detail_screen.dart';

class CompanyListScreen extends StatefulWidget {
  final bool? isSelectionMode;

  const CompanyListScreen({Key? key, this.isSelectionMode})
      : super(key: key);

  @override
  _CompanyListScreenState createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use a local variable to avoid holding a reference to the provider.
      final provider = context.read<CompanyProvider>();
      provider.loadCompanies();
      // Clear any previously selected company when entering the screen.
      provider.selectCompany(null);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _getGroupedCompanyList(List<Company> companies) {
    if (companies.isEmpty) return [];
    List<CompanyInfo> companyInfoList = companies.map((company) {
      String tag = company.name.isNotEmpty ? company.name.substring(0, 1).toUpperCase() : '#';
      return CompanyInfo(company: company, tag: tag);
    }).toList();
    companyInfoList.sort((a, b) => a.company.name.compareTo(b.company.name));
    List<dynamic> groupedList = [];
    String? lastTag;
    for (var info in companyInfoList) {
      if (info.tag != lastTag) {
        lastTag = info.tag;
        groupedList.add(lastTag!);
      }
      groupedList.add(info);
    }
    return groupedList;
  }

  @override
  Widget build(BuildContext context) {    return context.adaptiveWidget(
      mobile: _buildMobileLayout(),
      tablet: (widget.isSelectionMode ?? false) ? _buildMobileLayout() : _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text((widget.isSelectionMode ?? false) ? 'Chọn Nhà Cung Cấp' : 'Nhà Cung Cấp'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _buildListContent(isMasterDetail: false),
      floatingActionButton: (widget.isSelectionMode ?? false)
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.pushNamed(context, RouteNames.addCompany);
                // Refresh the list after returning from the add/edit screen.
                if (mounted) {
                  context
                      .read<CompanyProvider>()
                      .loadCompanies(forceReload: true);
                }
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Nhà Cung Cấp'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.pushNamed(context, RouteNames.addCompany);
              if (mounted) {
                context
                    .read<CompanyProvider>()
                    .loadCompanies(forceReload: true);
              }
            },
            tooltip: 'Thêm nhà cung cấp',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: _buildListContent(isMasterDetail: true),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 6,
            child: Consumer<CompanyProvider>(
              builder: (context, provider, child) {
                if (provider.selectedCompany == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_center_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Chọn một nhà cung cấp để xem chi tiết', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                // Use a key to ensure the detail screen rebuilds when the company changes.
                return CompanyDetailScreen(
                  key: ValueKey(provider.selectedCompany!.id),
                  company: provider.selectedCompany!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Column(
        children: [
          _buildDesktopToolbar(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _buildListContent(isMasterDetail: true),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  flex: 6,
                  child: Consumer<CompanyProvider>(
                    builder: (context, provider, child) {
                      if (provider.selectedCompany == null) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_center_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Chọn một nhà cung cấp để xem chi tiết', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                        );
                      }
                      return CompanyDetailScreen(
                        key: ValueKey(provider.selectedCompany!.id),
                        company: provider.selectedCompany!,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopToolbar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          SizedBox(width: context.sectionPadding),
          const Text(
            'Quản Lý Nhà Cung Cấp',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(context, RouteNames.addCompany);
              if (mounted) {
                context
                    .read<CompanyProvider>()
                    .loadCompanies(forceReload: true);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Thêm nhà cung cấp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          SizedBox(width: context.sectionPadding),
        ],
      ),
    );
  }

  Widget _buildListContent({required bool isMasterDetail}) {
    return RefreshIndicator(
      onRefresh: () =>
          context.read<CompanyProvider>().loadCompanies(forceReload: true),
      child: Column(
      children: [
        Padding(
          padding: EdgeInsets.all(context.sectionPadding),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, SĐT, người liên hệ...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        context.read<CompanyProvider>().setSearchQuery('');
                      },
                    )
                  : null,
            ),
            onChanged: (query) => context.read<CompanyProvider>().setSearchQuery(query),
          ),
        ),
        Expanded(
          child: Consumer<CompanyProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.companies.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.hasError) {
                return Center(child: Text('Lỗi: ${provider.errorMessage}'));
              }
              final companies = provider.filteredCompanies;
              final groupedList = _getGroupedCompanyList(companies);
              if (groupedList.isEmpty) {
                return const Center(child: Text('Không tìm thấy nhà cung cấp nào'));
              }
              return ListView.builder(
                itemCount: groupedList.length,
                itemBuilder: (context, index) {
                  final item = groupedList[index];
                  if (item is String) {
                    return _buildSuspensionWidget(item);
                  } else if (item is CompanyInfo) {
                    return _buildCompanyListItem(item.company, isMasterDetail);
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ],
    ));
  }

  Widget _buildCompanyListItem(Company company, bool isMasterDetail) {
    final provider = context.read<CompanyProvider>();
    final bool isSelected = isMasterDetail && provider.selectedCompany?.id == company.id;

    return ListTile(
      tileColor: isSelected ? Colors.green.withOpacity(0.1) : null,
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.2),
        child: Text(
          company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: company.contactPerson != null && company.contactPerson!.isNotEmpty 
          ? Text(company.contactPerson!)
          : const Text('Không có thông tin liên hệ'),
      onTap: () async {
        provider.selectCompany(company);
        if (!isMasterDetail) {
          if ((widget.isSelectionMode ?? false)) {
            Navigator.pop(context, company);
          } else {
            // Use pushNamed for consistency and await the result.
            await Navigator.pushNamed(
              context,
              RouteNames.companyDetail,
              arguments: company,
            );
            // After returning, refresh the list to reflect any changes.
            if (mounted) {
              context.read<CompanyProvider>().loadCompanies(forceReload: true);
            }
          }
        }
      },
    );
  }

  Widget _buildSuspensionWidget(String tag) {
    return Container(
      height: 24,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16.0),
      color: Colors.grey[200],
      alignment: Alignment.centerLeft,
      child: Text(tag, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }
}

// Wrapper class to hold tag information
class CompanyInfo {
  final Company company;
  final String tag;

  CompanyInfo({required this.company, required this.tag});
}