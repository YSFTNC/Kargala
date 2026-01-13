import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KayitOlEkrani extends StatefulWidget {
  const KayitOlEkrani({super.key});

  @override
  State<KayitOlEkrani> createState() => _KayitOlEkraniState();
}

class _KayitOlEkraniState extends State<KayitOlEkrani> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();

  Future<void> kayitOl() async {
    try {
      // 1. Kullanıcıyı oluştur
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user;
      if (user == null) return; // Kullanıcı null ise dur


      try {
        await user.sendEmailVerification();
        print(">>> Doğrulama e-postası gönderildi.");
      } catch (e) {
        print("XXX Doğrulama e-postası gönderme hatası: $e");
      }

      
      await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).set({
        'ad': _adController.text.trim(),
        'soyad': _soyadController.text.trim(),
        'email': _emailController.text.trim(),
        'profilFotoUrl': null, // Başlangıçta boş
        'tamamlananGorevSayisi': 0,
      });


      if (context.mounted) {
        Navigator.of(context).pop(); 
      }

    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt Hatası: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white), // Geri okunu beyaz yapar
        title: const Text('Hesap Oluştur', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _adController,
              decoration: InputDecoration(labelText: 'Adınız', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _soyadController,
              decoration: InputDecoration(labelText: 'Soyadınız', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'E-posta', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Şifre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF32D74B),
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: kayitOl,
              child: const Text('KAYIT OL'),
            ),
          ],
        ),
      ),
    );
  }
}