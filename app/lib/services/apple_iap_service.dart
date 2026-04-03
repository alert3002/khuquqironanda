import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Хариди обуна дар iOS тавассути StoreKit; баргардонидани JWS барои сервер.
class AppleIapService {
  AppleIapService._();

  static final AppleIapService instance = AppleIapService._();

  StreamSubscription<List<PurchaseDetails>>? _sub;
  Completer<String?>? _pendingJwsCompleter;
  String? _pendingProductId;

  Future<void> _ensureListener() async {
    if (_sub != null) return;
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e, StackTrace st) {
        if (_pendingJwsCompleter != null &&
            !_pendingJwsCompleter!.isCompleted) {
          _pendingJwsCompleter!.completeError(e, st);
        }
        _clearPending();
      },
    );
  }

  void _clearPending() {
    _pendingProductId = null;
    _pendingJwsCompleter = null;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    final completer = _pendingJwsCompleter;
    final wantId = _pendingProductId;
    if (completer == null || wantId == null) return;

    for (final p in purchases) {
      if (p.productID != wantId) continue;

      if (p.status == PurchaseStatus.pending) {
        continue;
      }

      if (p.status == PurchaseStatus.canceled) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        _clearPending();
        return;
      }

      if (p.status == PurchaseStatus.error) {
        if (!completer.isCompleted) {
          completer.completeError(
            p.error?.message ?? 'Purchase error',
          );
        }
        _clearPending();
        return;
      }

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        final jws = p.verificationData.serverVerificationData.isNotEmpty
            ? p.verificationData.serverVerificationData
            : p.verificationData.localVerificationData;
        if (p.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(p);
        }
        if (!completer.isCompleted) {
          completer.complete(jws.isNotEmpty ? jws : null);
        }
        _clearPending();
        return;
      }
    }
  }

  /// Хариди non-consumable / обуна (Apple) ва баргаштани JWS барои `/iap/apple/confirm/`.
  Future<String?> buyAndGetServerJws(String productId) async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      throw StateError('App Store дастрас нест');
    }

    await _ensureListener();

    final response =
        await InAppPurchase.instance.queryProductDetails({productId});
    if (response.notFoundIDs.isNotEmpty) {
      throw StateError(
        'Product ID дар App Store Connect ёфт нашуд: ${response.notFoundIDs.join(", ")}',
      );
    }
    if (response.productDetails.isEmpty) {
      throw StateError('Маҳсулот холӣ аст');
    }

    _pendingProductId = productId;
    _pendingJwsCompleter = Completer<String?>();

    final param = PurchaseParam(
      productDetails: response.productDetails.first,
    );

    final started = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: param,
    );
    if (!started) {
      _clearPending();
      throw StateError('Харид оғоз нашуд');
    }

    return _pendingJwsCompleter!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _clearPending();
        return null;
      },
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _clearPending();
  }
}
