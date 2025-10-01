import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/company.dart';
import '../../providers/company_provider.dart';
import 'add_edit_company_screen.dart';

/// Full-screen company picker with search and A-Z index
/// Apple-style navigation pattern for selecting from large lists
class CompanyPickerScreen extends StatefulWidget {
  final String? selectedCompanyId;

  const CompanyPickerScreen({
    Key? key,
    this.selectedCompanyId,
  }) : super(key: key);

  @override
  State<CompanyPickerScreen> createState() => _CompanyPickerScreenState();
}

class _CompanyPickerScreenState extends State<CompanyPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Company> _getFilteredCompanies(List<Company> companies) {
    if (_searchQuery.isEmpty) return companies;

    final query = _searchQuery.toLowerCase();
    return companies.where((company) {
      return company.name.toLowerCase().contains(query) ||
             (company.phone?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Chọn Nhà Cung Cấp',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Thêm nhà cung cấp mới',
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddEditCompanyScreen(),
                ),
              );
              // Auto-select and return the newly created company
              if (result != null && result is String && mounted) {
                await context.read<CompanyProvider>().loadCompanies();
                Navigator.of(context).pop(result);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc số điện thoại...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Company list
          Expanded(
            child: Consumer<CompanyProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.companies.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredCompanies = _getFilteredCompanies(provider.companies);

                if (filteredCompanies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Không tìm thấy nhà cung cấp'
                              : 'Chưa có nhà cung cấp nào',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bấm nút "+" ở góc trên để thêm mới',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredCompanies.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 72,
                    color: Colors.grey[200],
                  ),
                  itemBuilder: (context, index) {
                    final company = filteredCompanies[index];
                    final isSelected = company.id == widget.selectedCompanyId;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.business,
                          color: isSelected ? Colors.green : Colors.grey[600],
                          size: 24,
                        ),
                      ),
                      title: Text(
                        company.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.green : Colors.black87,
                        ),
                      ),
                      subtitle: company.phone != null
                          ? Text(
                              company.phone!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            )
                          : null,
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            )
                          : const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                              size: 24,
                            ),
                      onTap: () {
                        Navigator.of(context).pop(company.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
