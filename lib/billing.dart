import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api.dart';
import 'state.dart';

/// Google Play subscriptions. Product IDs must match Play Console and PLAY_PRODUCTS in config.php.
const Map<String, String> productIds = {'plus': 'plus_monthly', 'family': 'family_monthly'};

class Billing {
  Billing._();
  static final Billing I = Billing._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> products = {}; // keyed by plan ('plus' / 'family')
  bool available = false;

  /// Message for the Plans screen ("Plus plan is active", errors…). The screen listens to this.
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  Future<void> init() async {
    if (_sub != null) return;
    try {
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) => busy.value = false);
      available = await _iap.isAvailable();
    } catch (_) {
      available = false;
    }
  }

  /// Loads prices from Google Play. Returns false when the plans aren't set up in Play yet.
  Future<bool> loadProducts() async {
    await init();
    if (!available) return false;
    if (products.isNotEmpty) return true;
    try {
      final res = await _iap.queryProductDetails(productIds.values.toSet());
      for (final p in res.productDetails) {
        final plan = productIds.entries.firstWhere((e) => e.value == p.id, orElse: () => const MapEntry('', '')).key;
        if (plan.isNotEmpty && !products.containsKey(plan)) products[plan] = p;
      }
    } catch (_) {}
    return products.isNotEmpty;
  }

  /// Starts the Google Play checkout. Returns an error message, or null when the Play sheet opened.
  Future<String?> buy(String plan) async {
    if (!await loadProducts()) {
      return "Paid plans aren't available in Google Play yet. Please check back soon.";
    }
    final p = products[plan];
    if (p == null) return "This plan isn't available yet. Please try another plan.";
    try {
      busy.value = true;
      message.value = null;
      final ok = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
      if (!ok) busy.value = false;
      return ok ? null : "Couldn't open Google Play. Please try again.";
    } catch (e) {
      busy.value = false;
      return "Couldn't start the purchase. If you already subscribe, tap Restore purchases.";
    }
  }

  Future<void> restore() async {
    await init();
    if (!available) {
      message.value = "Google Play isn't available on this phone.";
      return;
    }
    busy.value = true;
    message.value = null;
    try {
      await _iap.restorePurchases();
    } catch (_) {}
    // If nothing comes back, stop the spinner after a moment.
    Future.delayed(const Duration(seconds: 6), () {
      if (busy.value) {
        busy.value = false;
        message.value ??= AppState.I.plan == 'free' ? 'No active subscription found on this Google account.' : null;
      }
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          busy.value = true;
          message.value = 'Waiting for Google Play to confirm your payment…';
          break;
        case PurchaseStatus.canceled:
          busy.value = false;
          break;
        case PurchaseStatus.error:
          busy.value = false;
          message.value = 'The purchase didn\'t go through. You have not been charged.';
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(p);
          break;
      }
    }
  }

  /// Our server checks the purchase with Google, then turns on the plan for this phone.
  Future<void> _verify(PurchaseDetails p) async {
    try {
      final d = await Api.post({
        'action': 'purchase',
        'product': p.productID,
        'token': p.verificationData.serverVerificationData,
      });
      AppState.I.applyStatus(d['status']);
      // Only acknowledge after our server confirmed it (unacknowledged purchases are refunded by Google).
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      message.value = 'Thank you! Your ${AppState.I.planName} plan is active.';
    } on ApiError catch (e) {
      message.value = e.code == 'not_configured'
          ? "Your payment is safe, but our server couldn't confirm it yet. Please try Restore purchases later."
          : errorText(e);
    } catch (_) {
      message.value = "Couldn't confirm your purchase. Please try Restore purchases.";
    } finally {
      busy.value = false;
    }
  }
}
