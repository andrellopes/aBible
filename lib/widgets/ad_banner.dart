import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_ids.local.dart';

/// Banner de anúncios (AdMob) discreto para o rodapé.
/// Usa AdSize.largeBanner (altura ~100dp) conforme pedido.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // Exibe apenas em dispositivos móveis
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    final ad = BannerAd(
      adUnitId: AdIds.homeBanner,
      request: const AdRequest(),
      size: AdSize.banner, // ~320x100 (telefones)
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // Silencioso em produção; opcionalmente logar
        },
      ),
    );

    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      // Reserva espaço pequeno para evitar saltos na UI
      return const SizedBox(height: 0);
    }

    final ad = _bannerAd!;
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

/// Banner de anúncios específico para a tela de configurações
class SettingsAdBanner extends StatefulWidget {
  const SettingsAdBanner({super.key});

  @override
  State<SettingsAdBanner> createState() => _SettingsAdBannerState();
}

class _SettingsAdBannerState extends State<SettingsAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // Exibe apenas em dispositivos móveis
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    setState(() {
      _isLoading = true;
    });

    final ad = BannerAd(
      adUnitId: AdIds.settingsBanner,
      request: const AdRequest(),
      size: AdSize.banner, // ~320x50 (banner padrão)
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('🎯 Banner de configurações carregado com sucesso!');
          setState(() {
            _isLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Erro ao carregar banner de configurações: $error');
          ad.dispose();
          setState(() {
            _isLoading = false;
          });
          // Silencioso em produção; opcionalmente logar
        },
      ),
    );

    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return const SizedBox.shrink();
    }

    // Sempre reserva espaço para o banner (50px de altura)
    return Container(
      width: double.infinity,
      height: 50, // Altura padrão do banner
      color: Colors.transparent,
      child: _isLoaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : _isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Center(
                  child: Text(
                    'Anúncio',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
    );
  }
}
