import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/freezme_repository.dart';
import 'api_client.dart';

/// IAP Service — centralized payment stack handler.
/// Receipt verification now calls the EC2 REST API instead of Cloud Functions.
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

  IAPService(this._repository, {VoidCallback? onSuccess})
      : _onSuccess = onSuccess {
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
    return _mockProduct('freezme_plus_weekly', 'Weekly', '₹149');
  }

  ProductDetails? get monthlyPlan {
    for (final p in _products) {
      if (p.id == 'freezme_plus_monthly') return p;
    }
    return _mockProduct('freezme_plus_monthly', 'Monthly', '₹499');
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

  void _init() {
    _subscription = _iap.purchaseStream.listen(
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
      final response = await _iap.queryProductDetails(_kProductIds);
      _products = List<ProductDetails>.from(response.productDetails);
      if (response.notFoundIDs.isNotEmpty && kDebugMode) {
        debugPrint('[IAP] products not found: ${response.notFoundIDs}');
      }
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    _error = null;
    _purchasePending = true;
    notifyListeners();

    final productNotFound = !_products.any((p) => p.id == product.id);
    if (kDebugMode && productNotFound) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await _handleSuccess(null);
      notifyListeners();
      return;
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final success =
          await _iap.buyNonConsumable(purchaseParam: purchaseParam);
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

  Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _purchasePending = true;
        notifyListeners();
      } else {
        if (purchase.status == PurchaseStatus.error) {
          _error = purchase.error?.message ?? 'Purchase failed';
          _purchasePending = false;
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _handleSuccess(purchase);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        notifyListeners();
      }
    }
  }

  Future<void> _handleSuccess(PurchaseDetails? purchase) async {
    try {
      final endpoint = Platform.isIOS
          ? '/iap/verify-apple'
          : '/iap/verify-android';

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
        _onSuccess?.call();
      } else {
        _error = 'Verification failed: receipt is invalid or expired.';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] verification error: $e');
        // In debug, fall back to local flag
        final uid = await _client.getAccessToken();
        if (uid != null) {
          await _repository.updateProfile(uid: uid, isPremium: true);
        }
        _onSuccess?.call();
      } else {
        _error = 'Failed to verify purchase. Please contact support.';
      }
    } finally {
      _purchasePending = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
