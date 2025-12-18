import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../services/iap_service.dart';
import '../../main.dart';
import '../design_system.dart';
import '../components/premium_components.dart';

/// Freezme+ Subscription Page
/// Clean, simple design following the frozen creamy theme
class FreezmePlusPage extends StatefulWidget {
  const FreezmePlusPage({super.key});

  @override
  State<FreezmePlusPage> createState() => _FreezmePlusPageState();
}

class _FreezmePlusPageState extends State<FreezmePlusPage> {
  int _selectedPlan = 0; // 0 = weekly, 1 = monthly

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final iap = flow.iapService;

    final features = [
      (icon: Icons.bolt_rounded, title: 'Unlimited Vibes', description: 'Send unlimited likes every day'),
      (icon: Icons.favorite_rounded, title: 'Extra Matches', description: 'Get 6 daily matches instead of 3'),
      (icon: Icons.public_rounded, title: 'Global Visibility', description: 'Connect beyond your local area'),
      (icon: Icons.auto_awesome_rounded, title: 'Priority Match', description: 'Get shown first to top matches'),
      (icon: Icons.visibility_rounded, title: 'See Who Likes You', description: 'View profiles that liked you'),
      (icon: Icons.undo_rounded, title: 'Rewind', description: 'Undo your last swipe'),
    ];

    return AnimatedBuilder(
      animation: iap,
      builder: (context, child) {
        // Show error if transient
        if (iap.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             PremiumSnackBar.show(context, iap.error!, type: SnackBarType.error);
          });
        }
        
        final weeklyProduct = iap.weeklyPlan;
        final monthlyProduct = iap.monthlyPlan;

        // Extract price strings
        final weeklyPrice = weeklyProduct?.price ?? '₹149';
        final monthlyPrice = monthlyProduct?.price ?? '₹499';
        
        // Simple heuristic for raw price display if simple string format
        String weeklyRaw = weeklyPrice.replaceAll(RegExp(r'[^0-9.]'), '');
        String monthlyRaw = monthlyPrice.replaceAll(RegExp(r'[^0-9.]'), '');
        
        return Scaffold(
          backgroundColor: FreezmeDesignSystem.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: flow.pop,
            ),
            title: const Text('Freezme+'),
            actions: [
              TextButton(
                onPressed: () async {
                  await iap.restorePurchases();
                  if (context.mounted) {
                    PremiumSnackBar.show(context, 'Purchases Restored', type: SnackBarType.info);
                  }
                },
                child: Text('Restore', style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.primary)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
            child: Column(
              children: [
                // Header
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: FreezmeDesignSystem.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 40,
                    color: FreezmeDesignSystem.primary,
                  ),
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                Text(
                  'Upgrade to Freezme+',
                  style: FreezmeDesignSystem.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceSm),
                Text(
                  'Unlock premium features to find your perfect match faster',
                  style: FreezmeDesignSystem.body.copyWith(
                    color: FreezmeDesignSystem.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: FreezmeDesignSystem.spaceLg),
                
                // Features List
                Container(
                  decoration: FreezmeDesignSystem.cardDecorationFlat,
                  child: Column(
                    children: features.asMap().entries.map((entry) {
                      final feature = entry.value;
                      final isLast = entry.key == features.length - 1;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: FreezmeDesignSystem.primaryLight,
                                    borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                                  ),
                                  child: Icon(
                                    feature.icon,
                                    color: FreezmeDesignSystem.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: FreezmeDesignSystem.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        feature.title,
                                        style: FreezmeDesignSystem.bodyMedium,
                                      ),
                                      Text(
                                        feature.description,
                                        style: FreezmeDesignSystem.small,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: FreezmeDesignSystem.success,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(height: 1, color: FreezmeDesignSystem.border),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                
                const SizedBox(height: FreezmeDesignSystem.spaceLg),
                
                // Plan Selection
                Container(
                  padding: const EdgeInsets.all(FreezmeDesignSystem.spaceXs),
                  decoration: BoxDecoration(
                    color: FreezmeDesignSystem.surfaceAlt,
                    borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildPlanTab('Weekly', 0),
                      ),
                      Expanded(
                        child: _buildPlanTab('Monthly', 1),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                
                // Pricing Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
                  decoration: BoxDecoration(
                    gradient: FreezmeGradients.header,
                    borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusLg),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _selectedPlan == 0 ? 'Weekly Plan' : 'Monthly Plan',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: FreezmeDesignSystem.spaceSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /* 
                           Display Price nicely. 
                           StoreKit returns formatted strings like "₹ 149.00" or "$4.99".
                           We just display the string directly usually.
                          */
                          Text(
                             _selectedPlan == 0 ? weeklyPrice : monthlyPrice,
                             style: const TextStyle(
                               color: Colors.white,
                               fontSize: 32, // Adjusted size for potentially long strings
                               fontWeight: FontWeight.bold,
                               height: 1,
                             ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _selectedPlan == 0 ? '/ week' : '/ month',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_selectedPlan == 0) ...[
                        const SizedBox(height: FreezmeDesignSystem.spaceSm),
                        const Text(
                          'Save 25% vs monthly',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: FreezmeDesignSystem.spaceMd),
                      const Text(
                        'Cancel anytime • No commitment',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                
                // Subscribe Button
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    label: iap.purchasePending 
                         ? 'Processing...' 
                         : 'Subscribe to Freezme+',
                    loading: iap.purchasePending,
                    onPressed: iap.purchasePending ? null : () {
                      HapticFeedback.mediumImpact();
                      if (flow.isPremium) {
                         PremiumSnackBar.show(context, 'You are already a Premium member!', type: SnackBarType.success);
                         return;
                      }
                      
                      ProductDetails? product = _selectedPlan == 0 ? weeklyProduct : monthlyProduct;
                      if (product != null) {
                        iap.buy(product);
                      } else {
                        PremiumSnackBar.show(context, 'Products not loaded. Please try again.', type: SnackBarType.error);
                      }
                    },
                    variant: ButtonVariant.filled,
                  ),
                ),
                
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                
                // Footer
                Text(
                  'Join 10,000+ premium members',
                  style: FreezmeDesignSystem.caption,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Terms & Conditions',
                    style: FreezmeDesignSystem.small.copyWith(
                      color: FreezmeDesignSystem.textTertiary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildPlanTab(String label, int index) {
    final isSelected = _selectedPlan == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPlan = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusSm),
          boxShadow: isSelected ? FreezmeDesignSystem.shadowSm : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: FreezmeDesignSystem.bodyMedium.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected 
                    ? FreezmeDesignSystem.textPrimary 
                    : FreezmeDesignSystem.textSecondary,
              ),
            ),
            if (isSelected && index == 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FreezmeDesignSystem.success,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
