import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import '../data/freezme_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// IAP Service - centralized payment stack handler
class IAPService extends ChangeNotifier {
  static const Set<String> _kProductIds = {'freezme_plus_weekly', 'freezme_plus_monthly'};
  
  final InAppPurchase _iap = InAppPurchase.instance;
  final FreezmeRepository _repository;
  final VoidCallback? _onSuccess;
  
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  String? _error;

  IAPService(this._repository, {VoidCallback? onSuccess}) : _onSuccess = onSuccess {
    _init();
  }

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  String? get error => _error;

  ProductDetails? get weeklyPlan {
    for (final p in _products) {
      if (p.id == 'freezme_plus_weekly') return p;
    }
    // Fallback to mock for UI preview if store hasn't returned it yet
    return _mockProduct('freezme_plus_weekly', 'Weekly', '₹149');
  }

  ProductDetails? get monthlyPlan {
    for (final p in _products) {
      if (p.id == 'freezme_plus_monthly') return p;
    }
    return _mockProduct('freezme_plus_monthly', 'Monthly', '₹499');
  }

  // Fallback product if store is unreachable (for UI preview)
  ProductDetails _mockProduct(String id, String title, String price) {
    return ProductDetails(
      id: id,
      title: title,
      description: 'Premium subscription',
      price: price,
      rawPrice: 0,
      currencyCode: 'INR',
    );
  }

  void _init() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
    _initStore();
  }

  Future<void> _initStore() async {
    final available = await _iap.isAvailable();
    _isAvailable = available;
    notifyListeners();

    if (available) {
      const ids = _kProductIds;
      final response = await _iap.queryProductDetails(ids);
      _products = List<ProductDetails>.from(response.productDetails);
      if (response.notFoundIDs.isNotEmpty) {
         if (kDebugMode) print('IAP: Products not found: ${response.notFoundIDs}');
      }
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    _error = null;
    _purchasePending = true;
    notifyListeners();

    final purchaseParam = PurchaseParam(productDetails: product);
    
    // For subscriptions, we usually use buyNonConsumable (auto-renewable)
    // or buyConsumable (if it's simple consumable).
    // Auto-renewable subs are treated as non-consumables in logic (restore supported).
    // Simulator/Debug Bypass: If we're on a simulator/debug and the product wasn't found in the store query,
    // allow a simulated success so the user can test Premium features.
    final bool productNotFound = !_products.any((p) => p.id == product.id);
    if (kDebugMode && productNotFound) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await _handleSuccess(null as dynamic); 
      notifyListeners();
      return;
    }

    try {
      if (_iapVerificationRequired()) {
        // iOS specific handling could go here
      }
      
      final bool success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!success) {
        _purchasePending = false;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Could not start purchase: $e';
      _purchasePending = false;
      notifyListeners();
    }
  }

  bool _iapVerificationRequired() {
    return Platform.isIOS; 
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _error = purchaseDetails.error?.message ?? 'Purchase failed';
          _purchasePending = false;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          await _handleSuccess(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
        notifyListeners();
      }
    }
  }

  Future<void> _handleSuccess(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // In a real app, verify 'purchase.verificationData.serverVerificationData' with Backend
      // via Cloud Function.
      // For now, we trust the client and update Firestore directly.
      await _repository.updateProfile(uid: uid, isPremium: true);
      _onSuccess?.call();
      _purchasePending = false;
    }
  }
  
  /// Restore purchases logic
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
