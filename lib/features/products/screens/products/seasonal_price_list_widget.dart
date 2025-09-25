import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/seasonal_price.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/utils/formatter.dart';
import 'add_seasonal_price_screen.dart';
import 'edit_seasonal_price_screen.dart';

class SeasonalPriceList extends StatefulWidget {
  const SeasonalPriceList({Key? key}) : super(key: key);

  @override
  State<SeasonalPriceList> createState() => _SeasonalPriceListState();
}

class _SeasonalPriceListState extends State<SeasonalPriceList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductProvider>();
      if (provider.selectedProduct != null) {
        provider.loadSeasonalPrices(provider.selectedProduct!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.seasonalPrices.isEmpty) {
          return const Center(
            child: Text('Chưa có mức giá nào được thiết lập.'),
          );
        }

        return ListView.builder(
          itemCount: provider.seasonalPrices.length,
          itemBuilder: (context, index) {
            final price = provider.seasonalPrices[index];
            return _buildPriceCard(price, provider);
          },
        );
      },
    );
  }

  Widget _buildPriceCard(SeasonalPrice price, ProductProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(price.seasonName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giá bán: ${AppFormatter.formatCurrency(price.sellingPrice)}'),
            Text('Từ ${AppFormatter.formatDate(price.startDate)} đến ${AppFormatter.formatDate(price.endDate)}'),
          ],
        ),
        trailing: Switch(
          value: price.isActive,
          onChanged: (bool value) {
            final updatedPrice = price.copyWith(isActive: value);
            provider.updateSeasonalPrice(updatedPrice);
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditSeasonalPriceScreen(price: price)),
          );
        },
      ),
    );
  }
}
