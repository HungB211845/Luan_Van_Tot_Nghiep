import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/customers/models/customer.dart';
import '../../features/products/models/product.dart';
import '../../features/pos/models/transaction.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Customer>> getCustomers() async {
    final response = await _client
        .from('customers')
        .select()
        .order('created_at', ascending: false);

    return response.map((json) => Customer.fromJson(json)).toList();
  }

  Future<Customer> addCustomer(Customer customer) async {
    final response = await _client
        .from('customers')
        .insert(customer.toJson())
        .select()
        .single();

    return Customer.fromJson(response);
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final response = await _client
        .from('customers')
        .update(customer.toJson())
        .eq('id', customer.id!)
        .select()
        .single();

    return Customer.fromJson(response);
  }

  Future<void> deleteCustomer(int customerId) async {
    await _client
        .from('customers')
        .delete()
        .eq('id', customerId);
  }

  Future<List<Product>> getProducts() async {
    final response = await _client
        .from('products')
        .select()
        .order('created_at', ascending: false);

    return response.map((json) => Product.fromJson(json)).toList();
  }

  Future<Product> addProduct(Product product) async {
    final response = await _client
        .from('products')
        .insert(product.toJson())
        .select()
        .single();

    return Product.fromJson(response);
  }

  Future<Product> updateProduct(Product product) async {
    final response = await _client
        .from('products')
        .update(product.toJson())
        .eq('id', product.id!)
        .select()
        .single();

    return Product.fromJson(response);
  }

  Future<void> deleteProduct(int productId) async {
    await _client
        .from('products')
        .delete()
        .eq('id', productId);
  }

  Future<List<Transaction>> getTransactions() async {
    final response = await _client
        .from('transactions')
        .select('*, transaction_items(*)')
        .order('created_at', ascending: false);

    return response.map((json) => Transaction.fromJson(json)).toList();
  }

  Future<Transaction> addTransaction(Transaction transaction) async {
    final response = await _client
        .from('transactions')
        .insert(transaction.toJson())
        .select('*, transaction_items(*)')
        .single();

    return Transaction.fromJson(response);
  }

  Future<Transaction> updateTransaction(Transaction transaction) async {
    final response = await _client
        .from('transactions')
        .update(transaction.toJson())
        .eq('id', transaction.id!)
        .select('*, transaction_items(*)')
        .single();

    return Transaction.fromJson(response);
  }

  Future<void> deleteTransaction(int transactionId) async {
    await _client
        .from('transactions')
        .delete()
        .eq('id', transactionId);
  }
}