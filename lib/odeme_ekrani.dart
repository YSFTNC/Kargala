import 'package:flutter/material.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OdemeEkrani extends StatefulWidget {
  final double tutar;
  final String ilanAdi;

  const OdemeEkrani({Key? key, required this.tutar, required this.ilanAdi}) : super(key: key);

  @override
  State<StatefulWidget> createState() => OdemeEkraniState();
}

class OdemeEkraniState extends State<OdemeEkrani> {
  String cardNumber = '';
  String expiryDate = '';
  String cardHolderName = '';
  String cvvCode = '';
  bool isCvvFocused = false;
  bool _isLoading = false;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Koyu arka plan
      appBar: AppBar(
        title: const Text('Kart Bilgileri', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 20),
            // KART GÖRSELİ
            CreditCardWidget(
              cardNumber: cardNumber,
              expiryDate: expiryDate,
              cardHolderName: cardHolderName,
              cvvCode: cvvCode,
              showBackView: isCvvFocused,
              obscureCardNumber: true,
              obscureCardCvv: true,
              isHolderNameVisible: true,
              cardBgColor: const Color(0xFF32D74B), // Ana yeşil rengin
              backgroundImage: null,
              isSwipeGestureEnabled: true,
              onCreditCardWidgetChange: (CreditCardBrand creditCardBrand) {},
              // Yazı renklerini beyaz yapmak için:
              textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    // --- ÖNEMLİ DÜZELTME BURADA ---
                    // Formu özel bir "Koyu Tema" ile sarmalıyoruz.
                    // Bu sayede içine yazılan yazılar otomatik olarak BEYAZ olur.
                    // Formu özel bir "Koyu Tema" ile sarmalıyoruz.
                    Theme(
                      data: ThemeData(
                        brightness: Brightness.dark,
                        primaryColor: const Color(0xFF32D74B),
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF32D74B),
                          secondary: Color(0xFF32D74B),
                        ),
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          hintStyle: const TextStyle(color: Colors.white38),
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF32D74B), width: 1.5),
                          ),
                        ),
                      ),
                      child: CreditCardForm(
                        formKey: formKey,
                        obscureCvv: true,
                        obscureNumber: true,
                        cardNumber: cardNumber,
                        cvvCode: cvvCode,
                        isHolderNameVisible: true,
                        isCardNumberVisible: true,
                        isExpiryDateVisible: true,
                        cardHolderName: cardHolderName,
                        expiryDate: expiryDate,
                        
                        // --- DÜZELTME BURADA ---
                        // Süslemeler 'InputConfiguration' içine alındı
                        inputConfiguration: const InputConfiguration(
                          cardNumberDecoration: InputDecoration(
                            labelText: 'Kart Numarası',
                            hintText: 'XXXX XXXX XXXX XXXX',
                          ),
                          expiryDateDecoration: InputDecoration(
                            labelText: 'Son Kullanma',
                            hintText: 'AA/YY',
                          ),
                          cvvCodeDecoration: InputDecoration(
                            labelText: 'CVV',
                            hintText: 'XXX',
                          ),
                          cardHolderDecoration: InputDecoration(
                            labelText: 'Kart Sahibinin Adı',
                            hintText: 'Ad Soyad',
                          ),
                        ),
                        // -----------------------

                        onCreditCardModelChange: onCreditCardModelChange,
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // BUTON
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF32D74B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5,
                          shadowColor: const Color(0xFF32D74B).withOpacity(0.5),
                        ),
                        onPressed: _isLoading ? null : _odemeIsleminiBaslat,
                        child: _isLoading 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  '${widget.tutar.toStringAsFixed(2)} TL ÖDE', 
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                              ],
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security, color: Colors.grey, size: 14),
                        SizedBox(width: 6),
                        Text("256-bit SSL Güvenli Ödeme", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onCreditCardModelChange(CreditCardModel? creditCardModel) {
    setState(() {
      cardNumber = creditCardModel!.cardNumber;
      expiryDate = creditCardModel.expiryDate;
      cardHolderName = creditCardModel.cardHolderName;
      cvvCode = creditCardModel.cvvCode;
      isCvvFocused = creditCardModel.isCvvFocused;
    });
  }

  Future<void> _odemeIsleminiBaslat() async {
    // 1. Formu Kontrol Et
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // --- KESİN ÇÖZÜM BURADA ---
      if (user == null) {
        _hataGoster("Hata", "Oturum kapalı görünüyor. Lütfen tekrar giriş yapın.");
        setState(() => _isLoading = false);
        return;
      }

      // SİHİRLİ SATIR: Token'ı zorla yeniliyoruz.
      // Bu işlem 'unauthenticated' hatasını ortadan kaldırır.
      String? token = await user!.getIdToken(true); 
      print(">>> Token Başarıyla Yenilendi!");
      // --------------------------

      // Bölgeyi 'us-central1' olarak garantiliyoruz
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      final tarihParcalari = expiryDate.split('/');
      final ay = tarihParcalari.isNotEmpty ? tarihParcalari[0] : '';
      final yil = tarihParcalari.length > 1 ? tarihParcalari[1] : '';

      // Backend çağrısı
      final result = await functions.httpsCallable('odemeYap').call({
        'kartSahibi': cardHolderName,
        'kartNo': cardNumber.replaceAll(' ', ''),
        'ay': ay,
        'yil': yil,
        'cvv': cvvCode,
        'tutar': widget.tutar,
        'email': user.email,
        'adSoyad': user.displayName ?? "Kullanıcı",
        'userIp': "127.0.0.1"
      });

      final response = result.data as Map<dynamic, dynamic>;

      if (mounted) setState(() => _isLoading = false);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Ödeme Başarılı!"), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          _hataGoster("Ödeme Başarısız", response['message'] ?? "Bilinmeyen hata");
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      // Hatanın detayını görelim
      print("XXX Ödeme Hatası Detayı: $e");
      
      String hataMesaji = "Sistem Hatası: $e";
      if (e.toString().contains("unauthenticated")) {
        hataMesaji = "Oturum süreniz dolmuş olabilir. Lütfen Çıkış Yapıp tekrar girin.";
      } else if (e.toString().contains("NOT_FOUND")) {
        hataMesaji = "Sunucu fonksiyonu bulunamadı. Lütfen geliştiriciye başvurun.";
      }
      
      if (mounted) _hataGoster("Hata", hataMesaji);
    }
  }

  void _hataGoster(String baslik, String detay) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title: Text(baslik, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(child: Text(detay, style: const TextStyle(color: Colors.white70))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tamam", style: TextStyle(color: Color(0xFF32D74B))))],
      ),
    );
  }
}