import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/utils/responsive.dart';

class StoreCodeScreen extends StatefulWidget {
  const StoreCodeScreen({super.key});

  @override
  State<StoreCodeScreen> createState() => _StoreCodeScreenState();
}

class _StoreCodeScreenState extends State<StoreCodeScreen> {
  final _storeCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _storeCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authProvider = context.read<AuthProvider>();
    final storeCode = _storeCodeController.text.trim();

    final store = await authProvider.validateAndSetStore(storeCode);

    if (store != null && mounted) {
      // On success, navigate to the actual login screen
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
    } 
    // Error is handled by the provider and will be shown on the UI if any
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ResponsiveAuthScaffold(
      title: 'Mã cửa hàng',
      child: _buildStoreCodeForm(auth),
    );
  }

  Widget _buildStoreCodeForm(AuthProvider auth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sectionPadding),
      child: Container(
        constraints: BoxConstraints(maxWidth: context.maxFormWidth),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: context.formAlignment,
            children: [
              // RESPONSIVE SPACING
              SizedBox(height: context.adaptiveValue(
                mobile: 40.0,
                tablet: 60.0,
                desktop: 80.0,
              )),
              
              // Logo
              Icon(
                Icons.store_mall_directory,
                color: Colors.green,
                size: context.adaptiveValue(
                  mobile: 60.0,
                  tablet: 70.0,
                  desktop: 80.0,
                ),
              ),
              SizedBox(height: context.cardSpacing * 3),
              
              // Title
              Text(
                'Chào mừng đến với AgriPOS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.adaptiveValue(
                    mobile: 20.0,
                    tablet: 24.0,
                    desktop: 28.0,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.cardSpacing),
              
              // Subtitle
              Text(
                'Vui lòng nhập mã cửa hàng của bạn để tiếp tục',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.adaptiveValue(
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,
                  ),
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: context.cardSpacing * 5),
              
              // Store code input
              TextFormField(
                controller: _storeCodeController,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.adaptiveValue(
                    mobile: 18.0,
                    tablet: 20.0,
                    desktop: 22.0,
                  ),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
                decoration: const InputDecoration(
                  labelText: 'Mã cửa hàng',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Mã cửa hàng không được để trống';
                  }
                  return null;
                },
              ),
              SizedBox(height: context.cardSpacing * 3),
              
              // Error message
              if (auth.state.errorMessage != null)
                Padding(
                  padding: EdgeInsets.only(bottom: context.cardSpacing * 2),
                  child: Text(
                    auth.state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              
              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.state.isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: auth.state.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Text(
                          'Tiếp tục',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              
              // RESPONSIVE BOTTOM SPACING
              SizedBox(height: context.adaptiveValue(
                mobile: 40.0,
                tablet: 60.0,
                desktop: 80.0,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
