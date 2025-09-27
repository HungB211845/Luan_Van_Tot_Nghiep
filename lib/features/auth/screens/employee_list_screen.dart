import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/layout/main_layout_wrapper.dart';
import '../../../shared/layout/models/layout_config.dart';
import '../providers/employee_provider.dart';
import '../models/user_profile.dart';
// import '../models/employee_invitation.dart'; // Commented out temporarily

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  @override
  void initState() {
    super.initState();
    // Temporarily comment out until Auth system is fully implemented
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nhân viên')),
      body: Center(
        child: Text('Employee management - Under development'),
      ),
    );
  }
}