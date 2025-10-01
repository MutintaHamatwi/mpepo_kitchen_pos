import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart'; // Assuming your Product model is here

class ProductService {
  // Use the IP address of your machine, not 'localhost', for physical/emulated devices
  static const String _baseUrl = 'http://10.0.2.2:8001/products';

  /// Fetches the list of all products.
  Future<List<Product>> fetchProducts() async {
    final response = await http.get(Uri.parse(_baseUrl));

    if (response.statusCode == 200) {
      List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Product.fromJson(json)).toList();
    } else {
      // Throw an exception with details for better debugging
      throw Exception('Failed to load products. Status Code: ${response.statusCode}');
    }
  }

  /// Creates a new product by sending a POST request to FastAPI.
  Future<Product> createProduct(Product productData) async {
    // We only send the required fields (name, price, category, stock_quantity)
    final Map<String, dynamic> dataToSend = {
      'name': productData.name,
      'price': productData.price,
      'category': productData.category,
      'stock_quantity': productData.stockQuantity,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(dataToSend),
    );

    if (response.statusCode == 201) {
      // FastAPI returns the complete Product object on success (status 201)
      final newProductJson = json.decode(response.body);
      return Product.fromJson(newProductJson);
    } else {
      // If the server returns an error, we throw an exception
      String errorDetail = 'Unknown Error';
      try {
        errorDetail = jsonDecode(response.body)['detail']?.toString() ?? 'Invalid data submitted.';
      } catch (e) {
        // Handle cases where response body isn't JSON
      }
      throw Exception('Failed to create product. Status ${response.statusCode}: $errorDetail');
    }
  }
}
