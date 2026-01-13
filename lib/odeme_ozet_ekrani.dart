import 'package:flutter/material.dart';
import 'odeme_ekrani.dart';

class OdemeOzetEkrani extends StatelessWidget {
  final double tutar;
  final String ilanAdi; // Örn: "Kadıköy -> Beşiktaş Kargo"
  final String tasiyiciAdi; // Örn: "Ahmet Yılmaz"
  final Function onOdemeBasarili; // Geriye dönüp 'anlaştık' demek için

  const OdemeOzetEkrani({
    Key? key,
    required this.tutar,
    required this.ilanAdi,
    required this.tasiyiciAdi,
    required this.onOdemeBasarili,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ödeme Özeti', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık Bölümü
            Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 60, color: Color(0xFF32D74B)),
                  SizedBox(height: 16),
                  Text("Ödeme Detayları", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("Güvenli Ödeme Altyapısı", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Detay Satırları
            _buildDetaySatiri("Hizmet", "Kargo Taşıma"),
            _buildDetaySatiri("Rota / İlan", ilanAdi),
            _buildDetaySatiri("Taşıyıcı", tasiyiciAdi),
            const Divider(height: 40, thickness: 1),
            
            // Toplam Tutar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Toplam Tutar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("${tutar.toStringAsFixed(2)} TL", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF32D74B))),
              ],
            ),
            
            const Spacer(),

            // Bilgilendirme
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(child: Text("Ödemeniz, iş tamamlanana kadar havuz hesabında güvende tutulacaktır.", style: TextStyle(fontSize: 12, color: Colors.blue.shade900))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Buton
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32D74B),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                // Buradan asıl ödeme (kart) ekranına gidiyoruz
                final sonuc = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OdemeEkrani(
                      tutar: tutar,
                      ilanAdi: ilanAdi,
                    ),
                  ),
                );

                // Eğer ödeme başarılıysa (true döndüyse)
                if (sonuc == true) {
                  Navigator.pop(context); // Özeti kapat
                  onOdemeBasarili(); // Sohbet ekranındaki anlaşmayı tetikle
                }
              },
              child: const Text("ÖDEMEYE GEÇ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetaySatiri(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(baslik, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          Flexible(child: Text(deger, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}