import '../models/cart_item.dart';
import '../models/product.dart';
import '../utils/constants.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  // Add product to cart
  void addToCart(Product product, {int quantity = 1}) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
  }

  // Remove product from cart
  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
  }

  // Update quantity
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity = quantity;
    }
  }

  // Calculate subtotal
  double getSubtotal() {
    return _items.fold(0, (sum, item) => sum + item.subtotal);
  }

  // Calculate tax
  double getTax({double taxRate = AppConstants.defaultTaxRate}) {
    return getSubtotal() * taxRate;
  }

  // Calculate discount
  double getDiscount({double discountRate = AppConstants.defaultDiscountRate}) {
    return getSubtotal() * discountRate;
  }

  // Calculate total
  double getTotal({
    double taxRate = AppConstants.defaultTaxRate,
    double discountRate = AppConstants.defaultDiscountRate,
  }) {
    final subtotal = getSubtotal();
    final tax = getTax(taxRate: taxRate);
    final discount = getDiscount(discountRate: discountRate);
    return subtotal + tax - discount;
  }

  // Clear cart
  void clearCart() {
    _items.clear();
  }

  // Get cart item count
  int getItemCount() {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }
}
