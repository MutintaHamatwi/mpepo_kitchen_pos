import 'package:flutter/material.dart';
import '../models/product.dart'; // Assuming your Product model is here
import '../services/newproduct.dart'; // Import the service created above

class NewProductScreen extends StatefulWidget {
  const NewProductScreen({super.key});

  @override
  State<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends State<NewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  // Common categories for the dropdown
  final List<String> _categories = ['Main Course', 'Side Dish', 'Beverage', 'Dessert', 'Snack'];
  String? _selectedCategory;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  // --- Submission Logic ---
  Future<void> _submitProduct() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      setState(() {
        _isLoading = true;
      });

      final newProduct = Product(
        // These fields are required by the Product constructor but not sent in POST
        // They will be overwritten by the server's response.
        id: '',
        name: _nameController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        category: _selectedCategory!,
        stockQuantity: int.tryParse(_stockController.text) ?? 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        final Product createdProduct = await _productService.createProduct(newProduct);

        // Success message and navigate back
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product created: ${createdProduct.name} (ID: ${createdProduct.id})'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear fields and go back to the previous screen (e.g., product list)
        Navigator.pop(context, true);

      } catch (e) {
        // Error message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add product: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. Product Name Input
              _buildTextFormField(
                controller: _nameController,
                labelText: 'Product Name',
                icon: Icons.kitchen,
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16.0),

              // 2. Price Input
              _buildTextFormField(
                controller: _priceController,
                labelText: 'Price (e.g., 150.00)',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a price';
                  if (double.tryParse(value) == null) return 'Must be a valid number';
                  if (double.parse(value) <= 0) return 'Price must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // 3. Category Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.teal.shade50,
                ),
                value: _selectedCategory,
                hint: const Text('Select Category'),
                validator: (value) => value == null ? 'Please select a category' : null,
                items: _categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
              ),
              const SizedBox(height: 16.0),

              // 4. Stock Quantity Input
              _buildTextFormField(
                controller: _stockController,
                labelText: 'Stock Quantity',
                icon: Icons.inventory_2,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter quantity';
                  if (int.tryParse(value) == null) return 'Must be a whole number';
                  if (int.parse(value) < 0) return 'Quantity cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 32.0),

              // 5. Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                    : const Text(
                  'Create Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for consistent text field styling
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade200),
        ),
        filled: true,
        fillColor: Colors.teal.shade50,
      ),
    );
  }
}
