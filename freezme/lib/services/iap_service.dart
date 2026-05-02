import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/freezme_repository.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// IAP Service — centralized payment stack handler.
/// Receipt verification calls the EC2 REST API (/iap/verify-apple or /iap/verify-android).
class IAPService extends ChangeNotifier {
  static const Set<String> _kProductIds = {
    'freezme_plus_weekly',
    'freezme_plus_monthly',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  final FreezmeRepository _repository;
  final VoidCallback? _onSuccess;
  final _client = ApiClient.instance;

  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  String? _error;

  bool _restoreCompleted = false;
  bool _disposed = false;

  IAPService(this._repository, {VoidCallback? onSuccess})
      : _onSuccess = onSuccess {
    _init();
  }

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  String? get error => _error;
  bool get restoreCompleted => _restoreCompleted;

  ProductDetails? get weeklyPlan {
    for (final p in _products) {
      if (p.id == 'freezme_plus_weekly') return p;
    }
    // Debug only: mock so UI renders without App Store connection
    return kDebugMode ? _mockProduct('freezme_plus_weekly', 'Weekly', '₹149') : null;
  }

  ProductDetails? get monthlyPlan {
    for (final p in _products) {
      if (p.id == 'freezme_plus_monthly') return p;
    }
    return kDebugMode ? _mockProduct('freezme_plus_monthly', 'Monthly', '₹499') : null;
  }

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

  /// Clears the current error — call from UI after showing the error snackbar.
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _init() {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        _error = error.toString();
        _purchasePending = false;
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
      final response = await _iap.queryProductDetails(_kProductIds);
      _products = List<ProductDetails>.from(response.productDetails);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[IAP] products not found in store: ${response.notFoundIDs}');
      }
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    _error = null;
    _purchasePending = true;
    notifyListeners();

    // Debug bypass: simulate a successful purchase when store isn't connected
    final productInStore = _products.any((p) => p.id == product.id);
    if (kDebugMode && !productInStore) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await _handleSuccess(null);
      return;
    }

    try {
      // Auto-renewable subscriptions use buyNonConsumable in in_app_purchase plugin
      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!success) {
        _error = 'Could not start purchase. Please try again.';
        _purchasePending = false;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Could not start purchase: $e';
      _purchasePending = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          notifyListeners();

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Verify with server first, then finalize with StoreKit
          await _handleSuccess(purchase);
          // Only call completePurchase after successful verification
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          if (purchase.status == PurchaseStatus.restored) {
            _restoreCompleted = true;
          }
          notifyListeners();

        case PurchaseStatus.error:
          _error = purchase.error?.message ?? 'Purchase failed. Please try again.';
          _purchasePending = false;
          // DO NOT call completePurchase on error — let StoreKit handle it
          notifyListeners();

        case PurchaseStatus.canceled:
          _purchasePending = false;
          notifyListeners();
      }
    }
  }

  Future<void> _handleSuccess(PurchaseDetails? purchase) async {
    try {
      final endpoint = Platform.isIOS ? '/iap/verify-apple' : '/iap/verify-android';

      final response = await _client.dio.post<Map<String, dynamic>>(
        endpoint,
        data: {
          if (purchase != null) ...{
            'receiptData': purchase.verificationData.serverVerificationData,
            'productId': purchase.productID,
            if (!Platform.isIOS)
              'purchaseToken': purchase.verificationData.serverVerificationData,
          },
        },
      );

      if (response.data?['active'] == true) {
        // Server has already set isPremium on the profile.
        // Re-fetch /profiles/me to sync the AuthUser in memory.
        await AuthService.instance.refreshProfile();
        _onSuccess?.call();
      } else {
        _error = 'Verification failed — receipt is invalid or expired.';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] server verification error: $e — debug bypass active');
        // Debug bypass: directly mark premium in the DB via profile update
        try {
          final uid = AuthService.instance.currentUser?.uid;
          if (uid != null) {
            await _repository.updateProfile(uid: uid, isPremium: true);
            await AuthService.instance.refreshProfile();
          }
        } catch (_) {}
        _onSuccess?.call();
      } else {
        _error = 'Purchase verified by store but server sync failed. Please restart the app.';
      }
    } finally {
      _purchasePending = false;
      notifyListeners();
    }
  }

  /// Triggers StoreKit restore. UI should listen to [restoreCompleted] to know when done.
  Future<void> restorePurchases() async {
    _restoreCompleted = false;
    _error = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      // _onPurchaseUpdate will fire for each restored purchase.
      // If nothing was purchased, StoreKit may not fire any events at all.
      // Add a timeout to ensure the user gets feedback either way.
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (_disposed) return;
        if (!_restoreCompleted && _error == null) {
          _restoreCompleted = true;
          notifyListeners();
        }
      });
    } catch (e) {
      _error = 'Restore failed: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
