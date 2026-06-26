1. Genel Bakış
Bu doküman; Wordle mekaniklerine sahip, başlangıç aşamasında yalnızca Türkçe dilinde hizmet verecek, tekil ve online rekabet odaklı bir kelime oyununun geliştirme kılavuzudur.

Platformlar: iOS + Android

Frontend: Flutter

Backend: Firebase (Auth, Firestore, Cloud Functions)

Dil: Türkçe (Özel karakter desteği: Ğ, Ü, Ş, İ, Ö, Ç)

2. Oyun Modları
2.1 Single Player
Günlük Kelime Modu: Günde 1 kelime, her oyuncu için aynı kelime, 6 tahmin hakkı.

Puanlı Seri Modu:

Bir oyunda 5 kelime.

4, 5 ve 6 harfli modlar.

Her tahmin için 10 saniye süre sınırı.

Sözlükte olmayan kelime girişi veya süre bitimi round'u bitirir ve 0 puan verir.

2.2 Online Mod (1v1)
Genel Kurallar: 4, 5 veya 6 harfli kelimeler karışık gelebilir; her iki oyuncuya da aynı uzunlukta kelime atanır.

Matchmaking: Rating bazlı eşleşme (yakın rating öncelikli).

Zaman ve Gecikme: Her tahmin için 10 saniye süre verilir. Ağ gecikmeleri için server tarafında +1.5 saniye "Grace Period" (tolerans) uygulanır.

Disconnect & Reconnect: Oyuncu düşerse bekleme süresi başlar; bağlanamazsa kaybeder. Rakip, galibiyet rating'inin 2/3'ünü alır.

2.3 Özel Oyun
Oyuncu oda kurarak arkadaşını davet eder. Kelime uzunluğu, tahmin hakkı, süre ve round sayısı gibi ayarlar kurucu tarafından belirlenir.

3. Kelime ve Dil Kuralları
Dil: Başlangıçta sadece Türkçe desteklenir.

Karakter Seti: Türkçe karakterlerin (İ-i, I-ı ayrımı dahil) hem client hem server tarafında UTF-8 standartlarına uygun işlenmesi zorunludur.

Kısıtlar: Argo, küfür ve özel isim yasaktır. Fiiller sadece mastar eki (-mak, -mek) alabilir.

4. Joker Sistemi (Sadece Single Mode)
Joker Türleri: 1 sesli harf açma, 1 sessiz harf açma, +1 tahmin hakkı.

Kurallar: Online modda joker kullanılamaz. Ek tahmin hakkı jokeri, 6. tahminden sonra bilinemediyse oyun bitmeden hemen önce sunulur.

Elde Etme: Reklam izleyerek veya uygulama içi satın alma ile.

5. Puanlama, Leaderboard ve Rating
5.1 Single Mode Puan Tablosu
Tahmin: 100 Puan

Tahmin: 90 Puan

Tahmin: 75 Puan

Tahmin: 55 Puan

Tahmin: 30 Puan

Tahmin: 10 Puan

Ek Tahmin Jokeri ile: 50 Puan

5.2 Sıralama (Leaderboard)
Tek oyunda alınan en yüksek skor (süre bazlı tie-break ile).

Tüm single oyunlardan toplanan toplam skor.

Misafir kullanıcılar listeye giremez.

5.3 Rating ve Ligler
Elo benzeri basitleştirilmiş sistem.

Lig Basamakları: Bronze (0-1000), Silver (1001-2000), Gold (2001-3500), Diamond (3501-5000), Champion (5000+).

6. Güvenlik ve Anti-Cheat
Temel İlke: Client güvenilmezdir; tüm kontroller server otoritelidir.

Payload: Tahminler, cihazda üretilen secret key ile AES-256 encrypt edilerek server'a iletilir.

Doğrulama: Server, süreyi ve kelimenin sözlük varlığını Cloud Functions üzerinde doğrular.

7. Teknik Mimari (Flutter & Firebase)
7.1 State Management & Katmanlar
Logic: Riverpod veya Bloc.

Katmanlar: UI Layer, GameSession Controller, Socket/Realtime Service, Crypto Service.

7.2 Veri Şeması (Firestore)
users: uid, username, rating, items{jokers}, total_score

games: game_id, player_1_id, player_2_id, status, winner_id, timestamp

dictionaries: tr_words_4[], tr_words_5[], tr_words_6[]

8. Auth ve Kullanıcı Türleri
Misafir (Guest): İlerleme sadece cihazda saklanır, leaderboard'a giremez.

Kayıtlı: Google Auth ve Apple Sign-In desteği; ilerleme bulut ile senkronize edilir.

9. Reklam ve Monetizasyon
Reklam: Joker kazanımı için ödüllü reklamlar ve her 10 single maç sonrası geçiş reklamı. Oyun ortasında reklam gösterilmez.

Satın Alma: Reklam kaldırma (günlük joker hediyeli) ve joker paketleri.

10. UI/UX ve "Game Feel"
Klavye: Türkçe karakterlere özel dinamik klavye yerleşimi.

Haptic Feedback: Doğru harfte (Yeşil) hafif, hatalı girişte sert titreşim.

Sosyal Paylaşım: Maç sonu skorları için emoji grid (🟩🟨⬜) formatında paylaşım butonu.

11. Son olarak ek özellikler
Sezonluk online liderlik tabloları.

Maç geçmişi ve tekrar izleme.

Günlük görev (streak) sistemi.