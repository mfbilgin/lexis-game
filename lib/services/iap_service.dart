import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../providers/providers.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

final iapServiceProvider = ChangeNotifierProvider<IapService>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final jokerNotifier = ref.watch(jokerProvider.notifier);
  final authState = ref.watch(authStateProvider);
  
  final service = IapService(firestoreService, jokerNotifier, authState.value?.uid);
  
  return service;
});

class IapService extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final JokerNotifier _jokerNotifier;
  final String? _uid;
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // IAP Product IDs
  static const String removeAdsId = 'remove_ads';
  static const String smallJokerPackId = 'small_joker_pack';
  static const String largeJokerPackId = 'large_joker_pack';

  final Set<String> _kIds = <String>{removeAdsId, smallJokerPackId, largeJokerPackId};

  List<ProductDetails> products = [];
  bool isAvailable = false;
  bool isStoreLoading = true;

  IapService(this._firestoreService, this._jokerNotifier, this._uid) {
    _init();
  }

  void _init() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('IAP stream error: $error');
      },
    );
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    isAvailable = await _iap.isAvailable();
    if (isAvailable) {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_kIds);
      if (response.error == null) {
        products = response.productDetails;
      } else {
        debugPrint('IAP query error: ${response.error?.message}');
      }
    }
    
    isStoreLoading = false;
    notifyListeners();
  }

  void buyProduct(ProductDetails product) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    if (product.id == removeAdsId) {
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      _iap.buyConsumable(purchaseParam: purchaseParam);
    }
  }

  /// Sadece geliştirme/test için mock satın alma
  Future<void> mockPurchase(String productId) async {
    await _deliverProduct(productId);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Pending state (e.g. slow credit card)
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _deliverProduct(purchaseDetails.productID);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _deliverProduct(String productId) async {
    if (productId == removeAdsId) {
      if (_uid != null) {
        await _firestoreService.setHasRemovedAds(_uid, true);
      }
    } else if (productId == smallJokerPackId) {
      _jokerNotifier.addJokers(vowel: 3, consonant: 3, extra: 3);
    } else if (productId == largeJokerPackId) {
      _jokerNotifier.addJokers(vowel: 15, consonant: 15, extra: 15);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
