/// Centralized localized strings for all UI text.
/// Adding a new language requires adding entries to _strings map.
class AppStrings {
  static String get(String key, String locale) {
    return _strings[locale]?[key] ?? _strings['tr']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _strings = {
    'tr': {
      // Common
      'app_name': 'Lexis',
      'play': 'Oyna',
      'cancel': 'İptal',
      'ok': 'Tamam',
      'close': 'Kapat',
      'exit': 'Çık',
      'continue_game': 'Devam et',
      'back': 'Geri',
      'save': 'Kaydet',
      'loading': 'Yükleniyor...',
      'error': 'Hata',
      'success': 'Başarılı',

      // Splash
      'splash_tagline': 'Kelime oyunlarının yeni adresi',

      // Home
      'daily_word': 'GÜNÜN KELİMESİ',
      'find_5_letter': '5 harfli kelimeyi bul',
      'daily_subtitle': 'Her gün yeni bir kelime seni bekliyor',
      'daily_completed': 'Bugünü tamamladın ✅',
      'daily_tomorrow': 'Yarın yeni kelime gelecek',
      'game_modes': 'OYUN MODLARI',
      'single_player': 'Tek Oyunculu',
      'single_player_desc': 'Kendi hızında pratik yap',
      'online_match': 'Online Eşleşme',
      'online_match_desc': 'Rakiplerine meydan oku',
      'leaderboard': 'Liderlik Tablosu',
      'leaderboard_desc': 'En iyiler sıralaması',

      // Bottom Nav
      'nav_home': 'Ana Sayfa',
      'nav_play': 'Oyna',
      'nav_ranking': 'Sıralama',
      'nav_profile': 'Profil',

      // Mode Selection
      'mode_selection': 'Mod Seçimi',
      'daily_challenge': 'GÜNLÜK MEYDAN OKUMA',
      'daily_challenge_desc': 'Her gün yeni bir kelime',
      'scored_series': 'PUANLI SERİ',
      'practice': 'PRATİK',
      'letters_4': '4 harfli',
      'letters_5': '5 harfli',
      'letters_6': '6 harfli',

      // Game Screen
      'mode_daily': 'GÜNLÜK',
      'mode_scored': 'PUANLI',
      'mode_practice': 'PRATİK',
      'mode_game': 'OYUN',
      'use_joker': 'Joker Kullan',
      'exit_game': 'Oyundan çık?',
      'progress_lost': 'İlerlemeniz kaybolacak.',
      'daily_resume': 'Kaldığınız yerden devam edebilirsiniz.',
      'invalid_word': 'Kelime Listesinde Yok.',

      // Joker Panel
      'joker_panel_title': 'Jokerler',
      'vowel_joker': 'Sesli Harf',
      'vowel_joker_desc': 'Bir sesli harfi gösterir',
      'consonant_joker': 'Sessiz Harf',
      'consonant_joker_desc': 'Bir sessiz harfi gösterir',
      'extra_guess_joker': 'Ekstra Tahmin',
      'extra_guess_joker_desc': 'Bir tahmin hakkı ekler',
      'buy_jokers': 'Joker Satın Al',

      // Result Screen
      'congratulations': 'Tebrikler! 🎉',
      'game_over': 'Oyun Bitti 😔',
      'correct_word': 'Doğru kelime:',
      'score': 'Puan',
      'time': 'Süre',
      'guesses': 'Tahmin',
      'rating': 'Puan',
      'play_again': 'Tekrar Oyna',
      'go_home': 'Ana Sayfa',
      'share_result': 'Paylaş',

      // Leaderboard
      'leaderboard_title': 'Liderlik Tablosu',
      'daily_tab': 'Günlük',
      'all_time_tab': 'Tüm Zamanlar',
      'points_label': 'puan',

      // Settings
      'settings': 'Ayarlar',
      'appearance': 'GÖRÜNÜM',
      'theme_light': 'Açık',
      'theme_dark': 'Koyu',
      'theme_auto': 'Otomatik',
      'sound_section': 'SES',
      'sound_effects': 'Ses Efektleri',
      'music': 'Müzik',
      'premium_section': 'PREMİUM',
      'remove_ads': 'Reklamları Kaldır',
      'ad_free': 'Reklamsız deneyim',
      'restore_purchases': 'Satın Alımları Geri Yükle',
      'support_section': 'DESTEK',
      'contact_us': 'Bize Ulaşın',
      'privacy_policy': 'Gizlilik Politikası',
      'terms_of_use': 'Kullanım Şartları',
      'online_status': 'Çevrimiçi',

      // Profile
      'profile': 'Profil',
      'save_progress': 'İlerlemenizi kaydedin',
      'save_progress_desc': 'İstatistiklerinizi takip edin, sıralamada yer alın ve verilerinizi senkronize edin.',
      'sign_in_anonymous': 'Misafir olarak devam et',
      'link_google': 'Google Hesabı Bağla',
      'link_google_desc': 'Verilerinizi senkronize edin',
      'statistics': 'İstatistikler',
      'games_played': 'Oynanan',
      'games_won': 'Kazanılan',
      'win_rate': 'Kazanma Oranı',
      'current_streak': 'Günlük Seri',
      'badges': 'Rozetler',
      'view_all': 'Tümünü Gör',
      'language_section': 'DİL',

      // Badges
      'badge_first_win': 'İlk Zafer',
      'badge_first_win_desc': 'İlk oyununu kazan',
      'badge_streak_3': '3 Günlük Seri',
      'badge_streak_3_desc': '3 gün üst üste günlük oyunu tamamla',
      'badge_streak_7': 'Haftalık Seri',
      'badge_streak_7_desc': '7 gün üst üste günlük oyunu tamamla',
      'badge_streak_30': 'Aylık Seri',
      'badge_streak_30_desc': '30 gün üst üste günlük oyunu tamamla',
      'badge_perfect': 'Mükemmel Tahmin',
      'badge_perfect_desc': 'Bir oyunda kelimeyi ilk tahminde bul',
      'badge_games_10': '10 Oyun',
      'badge_games_10_desc': '10 oyun tamamla',
      'badge_games_50': '50 Oyun',
      'badge_games_50_desc': '50 oyun tamamla',
      'badge_games_100': 'Yüzüncü Oyun',
      'badge_games_100_desc': '100 oyun tamamla',
      'badge_locked': 'Kilitli',
      'badge_unlocked': 'Kazanıldı',

      // Online
      'searching_opponent': 'Rakip aranıyor...',
      'cancel_search': 'Aramayı İptal Et',
      'forfeit': 'Pes Et',
      'forfeit_confirm': 'Pes etmek istediğinize emin misiniz?',
      'opponent_turn': 'Rakibin sırası',
      'your_turn': 'Senin sıran',
    },
  };
}
