import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quick_access_provider.dart';
import '../models/quick_access_item.dart';

class EditQuickAccessScreen extends StatelessWidget {
  const EditQuickAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Hủy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
          ),
        ),
        title: const Text(
          'Tùy chỉnh Truy cập nhanh',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Consumer<QuickAccessProvider>(
            builder: (context, provider, child) {
              return TextButton(
                onPressed: provider.hasChanges
                    ? () async {
                        try {
                          await provider.saveConfiguration();
                          if (context.mounted) {
                            Navigator.pop(context, true); // Return true to indicate saved
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi khi lưu: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    : null,
                child: Text(
                  'Xong',
                  style: TextStyle(
                    color: provider.hasChanges ? Colors.white : Colors.white54,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<QuickAccessProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              const SizedBox(height: 16),

              // Section 1: Visible Items (Reorderable)
              _buildSectionHeader('HIỂN THỊ TRÊN TRANG CHỦ'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.visibleItems.length,
                  onReorder: provider.reorderItems,
                  itemBuilder: (context, index) {
                    final item = provider.visibleItems[index];
                    return _buildVisibleItem(
                      context,
                      item,
                      index,
                      provider,
                      isLast: index == provider.visibleItems.length - 1,
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Section 2: Hidden Items (Add-able)
              if (provider.hiddenItems.isNotEmpty) ...[
                _buildSectionHeader('THÊM CÁC MỤC KHÁC'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.hiddenItems.length,
                    itemBuilder: (context, index) {
                      final item = provider.hiddenItems[index];
                      return _buildHiddenItem(
                        context,
                        item,
                        provider,
                        isLast: index == provider.hiddenItems.length - 1,
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVisibleItem(
    BuildContext context,
    QuickAccessItem item,
    int index,
    QuickAccessProvider provider, {
    required bool isLast,
  }) {
    return Container(
      key: ValueKey(item.id),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: Color(0xFFE5E5EA),
                  width: 0.5,
                ),
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.minus,
              color: Colors.white,
              size: 16,
            ),
          ),
          title: Row(
            children: [
              Icon(item.icon, color: item.color, size: 20),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          trailing: const Icon(
            CupertinoIcons.line_horizontal_3,
            color: Colors.grey,
            size: 20,
          ),
          onTap: () => provider.removeItem(item),
        ),
      ),
    );
  }

  Widget _buildHiddenItem(
    BuildContext context,
    QuickAccessItem item,
    QuickAccessProvider provider, {
    required bool isLast,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: Color(0xFFE5E5EA),
                  width: 0.5,
                ),
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.plus,
              color: Colors.white,
              size: 16,
            ),
          ),
          title: Row(
            children: [
              Icon(item.icon, color: item.color, size: 20),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          onTap: () => provider.addItem(item),
        ),
      ),
    );
  }
}
