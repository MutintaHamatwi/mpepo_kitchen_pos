import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../services/cart_service.dart';
import '../services/offline_queue_service.dart';
import '../utils/constants.dart';

class CartProvider with ChangeNotifier {
  final CartService _cartService = CartService();
  final OfflineQueueService _offlineQueueService = OfflineQueueService();

  double _taxRate = AppConstants.defaultTaxRate;
  double _discountRate = AppConstants.defaultDiscountRate;

  List<CartItem> get items => _cartService.items;
  double get taxRate => _taxRate;
  double get discountRate => _discountRate;

  void addToCart(Product product, {int quantity = 1}) {
    _cartService.addToCart(product, quantity: quantity);
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartService.removeFromCart(productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    _cartService.updateQuantity(productId, quantity);
    notifyListeners();
  }

  void setTaxRate(double rate) {
    _taxRate = rate;
    notifyListeners();
  }

  void setDiscountRate(double rate) {
    _discountRate = rate;
    notifyListeners();
  }

  double getSubtotal() => _cartService.getSubtotal();

  double getTax() => _cartService.getTax(taxRate: _taxRate);

  double getDiscount() => _cartService.getDiscount(discountRate: _discountRate);

  double getTotal() => _cartService.getTotal(
    taxRate: _taxRate,
    discountRate: _discountRate,
  );

  int getItemCount() => _cartService.getItemCount();

  Future<String> checkout() async {
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: items.map((item) => item.toJson()).toList(),
      subtotal: getSubtotal(),
      tax: getTax(),
      discount: getDiscount(),
      total: getTotal(),
      timestamp: DateTime.now(),
    );

    // Add to offline queue
    await _offlineQueueService.addToQueue(transaction);

    // Try to sync immediately
    await _offlineQueueService.syncTransactions();

    // Clear cart
    _cartService.clearCart();
    notifyListeners();

    return transaction.id!;
  }

  void clearCart() {
    _cartService.clearCart();
    notifyListeners();
  }
}
