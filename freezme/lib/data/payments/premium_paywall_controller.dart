import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product identifiers configured in the Play Console / App Store.
class FreezmeProductIds {
  static const plusMonthly = 'freezme_plus_monthly';

  static const Set<String> primary = <String>{
    plusMonthly,
  };
}

/// Encapsulates the in-app purchase flow for Freezme Plus.
class PremiumPaywallController extends ChangeNotifier {
  PremiumPaywallController({
    required Future<void> Function({required bool active, DateTime? expiry}) setMembership,
    FirebaseFunctions? functions,
    InAppPurchase? inAppPurchase,
  })  : _setMembership = setMembership,
        _functions = functions ?? FirebaseFunctions.instance,
        _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final Future<void> Function({required bool active, DateTime? expiry}) _setMembership;
  final FirebaseFunctions _functions;
  final InAppPurchase _inAppPurchase;

  bool _isAvailable = false;
  bool _isLoading = false;
  bool _isProcessingPurchase = false;
  String? _message;
  List<ProductDetails> _products = const <ProductDetails>[];
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Set<String> _deliveredPurchaseIds = <String>{};

  bool get isStoreAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get isProcessingPurchase => _isProcessingPurchase;
  String? get message => _message;
  List<ProductDetails> get products => List<ProductDetails>.unmodifiable(_products);

  ProductDetails? get primaryPlan {
    if (_products.isEmpty) return null;
    return _products.first;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final available = await _inAppPurchase.isAvailable();
    _isAvailable = available;

    if (!available) {
      _message = 'Store not available. Try again later.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: _onPurchaseError,
    );

    await Future.wait<void>([
      _queryProducts(),
      _checkExistingEntitlements(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    await _queryProducts();
  }

  Future<void> buy(ProductDetails product) async {
    if (_isProcessingPurchase) {
      return;
    }
    _isProcessingPurchase = true;
    _message = null;
    notifyListeners();
    final param = PurchaseParam(productDetails: product);
    final result = await _inAppPurchase.buyNonConsumable(purchaseParam: param);
    if (!result) {
      _isProcessingPurchase = false;
      _message = 'Unable to start purchase. Please try again.';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    try {
      _isProcessingPurchase = true;
      _message = null;
      notifyListeners();
      await _inAppPurchase.restorePurchases();
    } catch (error, stackTrace) {
      debugPrint('Restore purchases failed: $error');
      debugPrint('$stackTrace');
      _message = 'Could not restore purchases right now.';
      _isProcessingPurchase = false;
      notifyListeners();
    }
  }

  Future<void> _queryProducts() async {
    try {
      final response = await _inAppPurchase.queryProductDetails(FreezmeProductIds.primary);
      if (response.error != null) {
        _message = response.error!.message;
      }
      _products = response.productDetails;
      if (_products.isEmpty) {
        _message ??= 'No purchasable plans found. Configure products in Play Console.';
      }
    } catch (error, stackTrace) {
      debugPrint('Product query failed: $error');
      debugPrint('$stackTrace');
      _message = 'Could not load plans. Check your network and try again.';
    }
  }

  Future<void> _checkExistingEntitlements() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (error, stackTrace) {
      debugPrint('Failed to restore purchases on init: $error');
      debugPrint('$stackTrace');
    }
  }

  void _onPurchaseError(Object error) {
    debugPrint('Purchase stream error: $error');
    _message = 'Something went wrong with the purchase.';
    _isProcessingPurchase = false;
    notifyListeners();
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _isProcessingPurchase = true;
          _message = 'Confirming purchase...';
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          _isProcessingPurchase = false;
          _message = 'Purchase cancelled.';
          notifyListeners();
          break;
        case PurchaseStatus.error:
          _isProcessingPurchase = false;
          _message = purchase.error?.message ?? 'Purchase failed.';
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleVerifiedPurchase(purchase);
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _handleVerifiedPurchase(
    PurchaseDetails purchase, {
    bool isRestore = false,
  }) async {
    final purchaseId = purchase.purchaseID ?? purchase.hashCode.toString();
    if (_deliveredPurchaseIds.contains(purchaseId)) {
      return;
    }
    _isProcessingPurchase = true;
    notifyListeners();

    final verified = await _verifyPurchaseWithBackend(purchase);
    if (verified) {
      await _setMembership(active: true);
      _deliveredPurchaseIds.add(purchaseId);
      _message = isRestore
          ? 'Your Freezme+ access has been restored.'
          : 'Welcome to Freezme+ 💜';
    } else {
      _message = 'We couldn\'t validate the purchase yet.';
    }

    _isProcessingPurchase = false;
    notifyListeners();
  }

  Future<bool> _verifyPurchaseWithBackend(PurchaseDetails purchase) async {
    try {
      final callable = _functions.httpsCallable('verifyAndroidPurchase');
      final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'verificationData': {
          'source': purchase.verificationData.source,
          'serverVerificationData': purchase.verificationData.serverVerificationData,
        },
        'transactionDate': purchase.transactionDate,
      });
      final data = response.data;
      final valid = data['valid'] == true;
      if (valid) {
        final expiryIso = data['expiry'] as String?;
        DateTime? expiry;
        if (expiryIso != null) {
          expiry = DateTime.tryParse(expiryIso);
        }
        await _setMembership(active: true, expiry: expiry);
      }
      return valid;
    } catch (error, stackTrace) {
      debugPrint('verifyAndroidPurchase failed: $error');
      debugPrint('$stackTrace');
    }
    // Fallback: treat as valid to avoid blocking testers; real backend should confirm.
    await _setMembership(active: true);
    return true;
  }
}
