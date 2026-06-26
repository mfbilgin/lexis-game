import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/iap_service.dart';
import '../services/firestore_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_colors.dart';
import '../providers/providers.dart';
import '../services/services.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iapService = ref.watch(iapServiceProvider);
    final userStatsAsync = ref.watch(userStatsProvider);
    final hasRemovedAds = userStatsAsync.value?.hasRemovedAds ?? false;
    final jokers = ref.watch(jokerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağaza'),
        centerTitle: true,
      ),
      body: iapService.isStoreLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildStoreContent(context, ref, iapService, hasRemovedAds, jokers),
    );
  }

  Widget _buildStoreContent(
      BuildContext context, WidgetRef ref, IapService iapService, bool hasRemovedAds, JokerInventory jokers) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 10),
        
        // Joker Inventory Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Mevcut Jokerleriniz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _buildInventoryItem(Icons.spellcheck, 'Sesli', jokers.vowelJokers)),
                  Expanded(child: _buildInventoryItem(Icons.text_fields, 'Sessiz', jokers.consonantJokers)),
                  Expanded(child: _buildInventoryItem(Icons.plus_one, 'Ekstra', jokers.extraGuessJokers)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Watch Ad for Free Jokers
        _buildStoreItem(
          context: context,
          title: 'Bedava Joker Kazan',
          description: 'Reklam izleyerek +1 Joker paketi (Tümünden 1 adet) kazanın.',
          icon: Icons.play_circle_filled,
          color: Colors.greenAccent.shade700,
          price: 'Ücretsiz',
          onTap: () {
            ref.read(adServiceProvider).showRewardedAd(
              onUserEarnedReward: () {
                ref.read(jokerProvider.notifier).addJokers(vowel: 1, consonant: 1, extra: 1);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tebrikler! +1 Joker Paketi kazandınız.')),
                  );
                }
              },
            );
          },
        ),
        const SizedBox(height: 16),

        const Text(
          'Oyun Deneyiminizi Geliştirin',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Remove Ads Product
        if (!hasRemovedAds) ...[
          _buildStoreItem(
            context: context,
            title: 'Reklamları Kaldır',
            description: 'Oyun içi reklamları kalıcı olarak kaldırır ve kesintisiz bir deneyim sunar.',
            icon: Icons.block,
            color: Colors.redAccent,
            price: _getPrice(iapService, IapService.removeAdsId) ?? '₺29.99',
            onTap: () => _buyProduct(context, iapService, IapService.removeAdsId),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reklamlar Kaldırıldı! Desteğiniz için teşekkürler.',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Joker Packs
        _buildStoreItem(
          context: context,
          title: 'Küçük Joker Paketi',
          description: '10x Sesli, 10x Sessiz, 10x Ekstra Tahmin',
          icon: Icons.star_border,
          color: Colors.blueAccent,
          price: _getPrice(iapService, IapService.smallJokerPackId) ?? '₺19.99',
          onTap: () => _buyProduct(context, iapService, IapService.smallJokerPackId),
        ),
        const SizedBox(height: 16),

        _buildStoreItem(
          context: context,
          title: 'Büyük Joker Paketi',
          description: '50x Sesli, 50x Sessiz, 50x Ekstra Tahmin',
          icon: Icons.star,
          color: Colors.orange,
          price: _getPrice(iapService, IapService.largeJokerPackId) ?? '₺69.99',
          onTap: () => _buyProduct(context, iapService, IapService.largeJokerPackId),
        ),
        
        const SizedBox(height: 32),
        Center(
          child: TextButton.icon(
            onPressed: () => iapService.restorePurchases(),
            icon: const Icon(Icons.restore),
            label: const Text('Satın Alımları Geri Yükle'),
          ),
        ),
      ],
    );
  }

  String? _getPrice(IapService iapService, String id) {
    if (iapService.products.isEmpty) return null;
    try {
      final product = iapService.products.firstWhere((p) => p.id == id);
      return product.price;
    } catch (e) {
      return null;
    }
  }

  void _buyProduct(BuildContext context, IapService iapService, String id) {
    if (iapService.products.isEmpty) {
      // Mock purchase for development
      _showMockPurchaseDialog(context, iapService, id);
      return;
    }
    
    try {
      final product = iapService.products.firstWhere((p) => p.id == id);
      iapService.buyProduct(product);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün bulunamadı.')),
      );
    }
  }

  void _showMockPurchaseDialog(BuildContext context, IapService iapService, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test Satın Alımı'),
        content: const Text('Google Play / App Store bağlantısı kurulamadı. Test amaçlı bu ürünü ücretsiz almak ister misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              iapService.mockPurchase(id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test ürünü başarıyla eklendi!')),
              );
            },
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreItem({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String price,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryItem(IconData icon, String label, int count) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            count >= 10000 ? '10.000+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

