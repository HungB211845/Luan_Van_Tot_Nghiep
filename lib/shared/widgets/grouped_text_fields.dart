
import 'package:flutter/material.dart';

/// A widget that groups two text fields together in a single visual block,
/// similar to the style seen in many Apple HIG-compliant applications.
///
/// It consists of a container with a subtle background color and a thin
/// divider between the two fields, giving them a unified appearance.
class GroupedTextFields extends StatelessWidget {
  final TextEditingController topController;
  final TextEditingController bottomController;
  final String topHintText;
  final String bottomHintText;
  final TextInputType topKeyboardType;
  final TextInputType bottomKeyboardType;
  final bool isBottomObscured;
  final Widget? bottomSuffixIcon;
  final FocusNode? topFocusNode;
  final FocusNode? bottomFocusNode;
  final ValueChanged<String>? onTopFieldSubmitted;
  final ValueChanged<String>? onBottomFieldSubmitted;
  final FormFieldValidator<String>? topValidator;
  final FormFieldValidator<String>? bottomValidator;


  const GroupedTextFields({
    super.key,
    required this.topController,
    required this.bottomController,
    this.topHintText = 'Email',
    this.bottomHintText = 'Mật khẩu',
    this.topKeyboardType = TextInputType.emailAddress,
    this.bottomKeyboardType = TextInputType.visiblePassword,
    this.isBottomObscured = true,
    this.bottomSuffixIcon,
    this.topFocusNode,
    this.bottomFocusNode,
    this.onTopFieldSubmitted,
    this.onBottomFieldSubmitted,
    this.topValidator,
    this.bottomValidator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? Colors.grey[800]
        : const Color(0xFFF2F2F7); // Apple-like light gray
    final dividerColor = isDarkMode
        ? Colors.grey[700]
        : const Color(0xFFC6C6C8);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        children: [
          _buildTextField(
            context: context,
            controller: topController,
            hintText: topHintText,
            keyboardType: topKeyboardType,
            focusNode: topFocusNode,
            onFieldSubmitted: onTopFieldSubmitted,
            validator: topValidator,
            isTopField: true,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 16,
          ),
          _buildTextField(
            context: context,
            controller: bottomController,
            hintText: bottomHintText,
            keyboardType: bottomKeyboardType,
            obscureText: isBottomObscured,
            suffixIcon: bottomSuffixIcon,
            focusNode: bottomFocusNode,
            onFieldSubmitted: onBottomFieldSubmitted,
            validator: bottomValidator,
            isTopField: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    ValueChanged<String>? onFieldSubmitted,
    FormFieldValidator<String>? validator,
    bool isTopField = false,
  }) {
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: false,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          suffixIcon: suffixIcon,
        ),
        onFieldSubmitted: onFieldSubmitted,
        textInputAction: isTopField ? TextInputAction.next : TextInputAction.done,
      ),
    );
  }
}
