// KOD BLOK BAŞLANGICI (ayarlar_ekrani.dart - DİL SEÇENEĞİ EKLENDİ)
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // <<< YENİ İMPORT
import 'profil_duzenle_ekrani.dart'; 
import 'sifre_degistir_ekrani.dart'; 
import 'bildirim_ayarlari_ekrani.dart';

class AyarlarEkrani extends StatelessWidget {
  const AyarlarEkrani({super.key});

  // Dil Değiştirme Penceresini Açan Fonksiyon
  void _diliDegistir(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("select_language".tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // Türkçe Seçeneği
              ListTile(
                leading: const Text("🇹🇷", style: TextStyle(fontSize: 24)),
                title: const Text("Türkçe"),
                trailing: context.locale.languageCode == 'tr' 
                    ? const Icon(Icons.check_circle, color: Colors.green) 
                    : null,
                onTap: () async {
                  await context.setLocale(const Locale('tr')); // Dili değiştir
                  if (context.mounted) Navigator.pop(context); // Pencereyi kapat
                },
              ),
              
              // İngilizce Seçeneği
              ListTile(
                leading: const Text("🇬🇧", style: TextStyle(fontSize: 24)),
                title: const Text("English"),
                trailing: context.locale.languageCode == 'en' 
                    ? const Icon(Icons.check_circle, color: Colors.green) 
                    : null,
                onTap: () async {
                  await context.setLocale(const Locale('en')); // Dili değiştir
                  if (context.mounted) Navigator.pop(context); // Pencereyi kapat
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        // Başlığı çeviri dosyasından çekiyoruz
        title: Text("settings".tr(), style: const TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // 1. Hesap Ayarları
          _buildSectionHeader(context, "account".tr()), // Çeviri
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text("edit_profile".tr()), // Çeviri
            subtitle: const Text('Adınızı ve soyadınızı güncelleyin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilDuzenleEkrani()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text("change_password".tr()), // Çeviri
            subtitle: const Text('Giriş şifrenizi yenileyin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SifreDegistirEkrani()));
            },
          ),
          const Divider(height: 32),

          // 2. Tercihler
          _buildSectionHeader(context, "Tercihler"), // Bunu da json'a ekleyebilirsin
          
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text("notifications".tr()), // Çeviri
            subtitle: const Text('Hangi bildirimleri alacağınızı seçin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BildirimAyarlariEkrani()));
            },
          ),

          // --- YENİ: DİL SEÇENEĞİ ---
          ListTile(
            leading: const Icon(Icons.language),
            title: Text("language".tr()), // "Dil" veya "Language"
            subtitle: Text(context.locale.languageCode == 'tr' ? 'Türkçe' : 'English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _diliDegistir(context),
          ),
          // ---------------------------
          
          const Divider(height: 32),
          
          // 3. Yasal
          _buildSectionHeader(context, "about".tr()), // Çeviri
          ListTile(
            leading: Icon(Icons.description_outlined, color: Colors.grey[400]),
            title: Text("terms".tr(), style: TextStyle(color: Colors.grey[400])),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: null,
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: Colors.grey[400]),
            title: Text("privacy".tr(), style: TextStyle(color: Colors.grey[400])),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
// KOD BLOK SONU