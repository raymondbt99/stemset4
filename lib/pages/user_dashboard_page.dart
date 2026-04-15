import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stemset/models/user_asset_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Pastikan sudah di pubspec.yaml
import 'package:stemset/login_page.dart';
import 'package:stemset/pages/loan_history_page.dart';
import 'package:url_launcher/url_launcher.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final TextEditingController _notesController = TextEditingController();
  final supabase = Supabase.instance.client;
  int _currentIndex = 0; // Index untuk Bottom Navbar
  List<UserAsset> myAssets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndListen();
  }

  // --- LOGIKA DATA ---

  void _fetchAndListen() {
    // Ambil data awal
    _loadData();

    // Buat channel baru
    final channel = supabase.channel('public:assets');

    channel
        .onPostgresChanges(
          event:
              PostgresChangeEvent.all, // Mendengar Insert, Update, dan Delete
          schema: 'public',
          table: 'assets',
          callback: (payload) {
            debugPrint('Perubahan terdeteksi: ${payload.toString()}');
            _loadData(); // Ambil data terbaru saat ada perubahan
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('Berhasil terhubung ke Realtime!');
          }
          if (error != null) {
            debugPrint('Gagal terhubung');
          }
        });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('assets')
          .select('id, name, asset_code, status, image_url, rooms(room_name)')
          .eq('assigned_to', userId);

      if (mounted) {
        setState(() {
          myAssets =
              (response as List)
                  .map((json) => UserAsset.fromJson(json))
                  .toList();
        });
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA SCANNER & PEMINJAMAN ---

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Wajib agar bisa melebihi setengah layar
      backgroundColor: Colors.transparent,
      builder:
          (context) => SizedBox(
            // Mengatur tinggi modal menjadi 90% dari tinggi layar
            height: MediaQuery.of(context).size.height * 0.9,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A), // Hitam elegan (Deep Charcoal)
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Handle Bar (Garis penarik)
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Scanner Aset",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      child: _buildScannerOverlay(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showQRDialog(UserAsset asset) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Judul
                  Text(
                    asset.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Kode Aset: ${asset.assetCode}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),

                  const SizedBox(height: 30),

                  // QR Code Standar
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: asset.assetCode,
                      version: QrVersions.auto,
                      size: 200.0,
                      // Gaya standar (kotak)
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Tombol Tutup
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "TUTUP",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  

  Future<void> _showAssetDetail(String assetCode) async {
    // 1. Fetch data dari Supabase
    final data =
        await supabase
            .from('assets')
            .select('*, rooms(room_name), categories(name)')
            .eq('asset_code', assetCode)
            .maybeSingle();

    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Aset tidak ditemukan!"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final asset = UserAsset.fromJson(data);

    // 2. Tampilkan Bottom Sheet yang Tinggi & Elegan
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            // Mengatur tinggi menjadi 75% dari layar
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                // Handle Bar
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Nama & Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusBadge(asset.status),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          asset.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          "ID: ${asset.assetCode}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Text(
                          "INFORMASI ASET",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Kartu Detail
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                Icons.location_on_rounded,
                                "Lokasi",
                                asset.roomName,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                              _buildInfoRow(
                                Icons.category_rounded,
                                "Kategori",
                                asset.categoryName,
                              ), // Contoh statis
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Tombol Aksi
                        // --- TAMBAHKAN INPUT NOTES SEBELUM TOMBOL ---
if (asset.status.toLowerCase() == 'available') ...[
  const Text(
    "CATATAN PEMINJAMAN (OPSIONAL)",
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Colors.grey,
      letterSpacing: 1,
    ),
  ),
  const SizedBox(height: 8),
  TextField(
    controller: _notesController,
    decoration: InputDecoration(
      hintText: "Contoh: Untuk keperluan meeting di ruang lab...",
      fillColor: const Color(0xFFF8F9FA),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    maxLines: 2,
  ),
  const SizedBox(height: 24),
  
  // Tombol Konfirmasi
  SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      // UBAH BAGIAN INI: Kirim notes ke fungsi process
      onPressed: () => _processLoan(asset.id, _notesController.text), 
      child: const Text("KONFIRMASI PINJAM", style: TextStyle(fontWeight: FontWeight.bold)),
    ),
  ),
]
else if (asset.status.toLowerCase() == 'in_use')
  SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent, // Warna merah untuk pengembalian
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: () => _processReturn(asset.id),
      child: const Text(
        "KEMBALIKAN BARANG",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.orange.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lock_clock_rounded,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Aset ini sedang tidak tersedia untuk dipinjam.",
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _processLoan(String assetId, String notes) async {
  try {
    // 1. Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final userId = supabase.auth.currentUser!.id;

    // 2. Insert ke tabel loans
    await supabase.from('loans').insert({
      'asset_id': assetId,
      'user_id': userId,
      'notes': notes,
      'status': 'active', // Status di tabel loans tetap 'active'
    });

    // 3. Update status aset menjadi 'in_use'
    await supabase.from('assets').update({
      'status': 'in_use', // <--- Perubahan di sini
      'assigned_to': userId,
    }).eq('id', assetId);

    if (!mounted) return;
    
    Navigator.pop(context); // Tutup loading
    Navigator.pop(context); // Tutup bottom sheet
    _notesController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aset berhasil digunakan!")),
    );

    _loadData(); // Segarkan data di Dashboard

  } catch (e) {
    Navigator.pop(context); 
    print("Error: $e");
  }
}

Future<void> _processReturn(String assetId) async {
  try {
    // 1. Tampilkan Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final userId = supabase.auth.currentUser!.id;

    // 2. Update tabel LOANS: Tandai transaksi selesai
    await supabase.from('loans').update({
      'status': 'returned',
      'return_date': DateTime.now().toIso8601String(),
    }).match({
      'asset_id': assetId,
      'user_id': userId,
      'status': 'active', // Pastikan hanya mengupdate yang masih aktif
    });

    // 3. Update tabel ASSETS: Kembalikan ke kondisi awal
    await supabase.from('assets').update({
      'status': 'available',
      'assigned_to': null, // Kosongkan peminjam
    }).eq('id', assetId);

    if (!mounted) return;

    Navigator.pop(context); // Tutup loading
    Navigator.pop(context); // Tutup bottom sheet detail

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aset berhasil dikembalikan!")),
    );

    _loadData(); // Segarkan Dashboard

  } catch (e) {
    Navigator.pop(context);
    print("Error Return: $e");
  }
}

Future<void> _launchHelpdesk() async {
  final Uri url = Uri.parse('https://helpdesk.stella-maris.sch.id');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Tidak dapat membuka $url');
  }
}
  // --- UI COMPONENTS ---

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF8F9FA,
      ), // Latar belakang abu-abu sangat muda
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: Text(
          _currentIndex == 0 ? "My Assets" : "Profile",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
        ),
      ),
      body: _currentIndex == 0 ? _buildAssetList() : _buildProfilePage(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: Colors.blue[800],
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            if (index == 1) {
              _openScanner();
            } else {
              setState(() => _currentIndex = index);
              if (index == 0) _loadData();
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Aset',
            ),
            BottomNavigationBarItem(
              icon: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (myAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "Belum ada aset terdaftar",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
  physics: const BouncingScrollPhysics(), // Tambahan agar scroll lebih smooth
  padding: const EdgeInsets.symmetric(vertical: 16),
  itemCount: myAssets.length,
  itemBuilder: (context, index) {
    final asset = myAssets[index];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: () => _showQRDialog(asset), // Sesuai permintaan: tap muncul QR
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
  width: 50,
  height: 50,
  decoration: BoxDecoration(
    color: Colors.grey[200],
    borderRadius: BorderRadius.circular(12),
  ),
  child: ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: asset.fullImageUrl.isNotEmpty // Pakai getter fullImageUrl untuk pengecekan
      ? Image.network(
          asset.fullImageUrl,
          key: ValueKey(asset.id), // Penting agar widget refresh jika ID sama tapi data beda
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Jika masuk ke sini, berarti URL-nya salah atau internet bermasalah
            return const Icon(Icons.broken_image_outlined, color: Colors.red);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        )
      : const Icon(Icons.inventory_2, color: Color.fromARGB(255, 212, 223, 4)),
),
),
            title: Text(
              asset.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      asset.roomName,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _buildStatusBadge(asset.status),
          ),
        ),
      ),
    );
  },
);
  }

  // Helper untuk Badge Status
  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status.toLowerCase()) {
      case 'available':
        color = Colors.green;
        text = "Tersedia";
        break;
      case 'in_use':
        color = Colors.orange;
        text = "Dipinjam";
        break;
      default:
        color = Colors.red;
        text = "Rusak";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    final user = supabase.auth.currentUser;
    final String? avatarUrl = user?.userMetadata?['avatar_url'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Header Profil
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade800],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child:
                      avatarUrl == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.userMetadata?['full_name'] ?? "User Stella Maris",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user?.email ?? "-",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Menu List
          _buildMenuTile(Icons.help_outline_rounded, "Pusat Bantuan", () {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Bantuan & Hubungi Kami", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Opsi 1: Kontak via Email
            ListTile(
              leading: const Icon(Icons.chat_outlined, color: Colors.green),
              title: const Text("Hubungi Admin IT"),
              subtitle: const Text("Tanya seputar kendala aplikasi"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Logo Stema
          Image.asset(
            'assets/images/logo_stema.png',
            height: 60,
            errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.business, size: 60, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          
          const Text(
            "IT Helpdesk Support",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          
          // 2. Email Support
          const Text(
            "it-departement@stella-maris.sch.id",
            style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
          ),
          const SizedBox(height: 20),
          
          const Divider(),
          const SizedBox(height: 10),
          
          // 3. Instruksi Helpdesk
          const Text(
            "Untuk kendala teknis lebih lanjut, silakan buat tiket laporan Anda melalui sistem helpdesk kami:",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          
          // Tombol Link Helpdesk
          InkWell(
            onTap: () {
    _launchHelpdesk(); // Memanggil future yang sudah Anda buat
  },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    "helpdesk.stella-maris.sch.id",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("TUTUP"),
        ),
      ],
    ),
  );
},
            ),
            
            // Opsi 2: Panduan Singkat
            const Divider(),
            const ExpansionTile(
              leading: Icon(Icons.qr_code_scanner_rounded, color: Colors.blue),
              title: Text("Cara Scan QR Code"),
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Buka tab Scanner, arahkan kamera ke stiker QR yang tertempel di aset. Pastikan kamera fokus agar data muncul."),
                )
              ],
            ),
            
            const ExpansionTile(
              leading: Icon(Icons.assignment_return_outlined, color: Colors.orange),
              title: Text("Cara Mengembalikan Aset"),
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Buka profil, pilih Riwayat Peminjaman, cari aset yang aktif, lalu klik tombol Kembalikan Barang."),
                )
              ],
            ),

            const ExpansionTile(
              leading: Icon(Icons.front_hand, color: Color.fromARGB(255, 255, 0, 60)),
              title: Text("Cara Meminjam Aset"),
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Arahkan kamera ke QR Code, isi tanggal mulai peminjaman lalu klik tombol Konfirmasi Pinjam."),
                )
              ],
            ),
          ],
        ),
      ),
    ),
  );
}),
          // Cari baris ini di Profile Page Anda:
_buildMenuTile(Icons.history_rounded, "Riwayat Peminjaman", () {
  // Tambahkan navigasi ke halaman history
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const LoanHistoryPage()),
  );
}),
          _buildMenuTile(Icons.settings_outlined, "Pengaturan Akun", () {}),
          _buildMenuTile(
  Icons.info_outline_rounded,
  "Tentang STEMSET v1.0",
  () {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // MEMANGGIL LOGO LOKAL ANDA
            Image.asset(
              'assets/images/logo_stema.png',
              height: 80,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.business_rounded,
                size: 80,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "STEMSET",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Text(
              "v1.0.0 (Stable)",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              "Sistem Manajemen Aset Stella Maris International Education berbasis Mobile untuk pelacakan inventaris yang lebih efisien.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const Divider(height: 32),
            const Text(
              "Dikembangkan oleh:",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Text(
              "Tim IT Stella Maris",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  },
),

          const SizedBox(height: 40),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: TextButton.icon(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              label: const Text(
                "KELUAR APLIKASI",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                // 1. Proses Sign Out dari Supabase
                await Supabase.instance.client.auth.signOut();

                // 2. Navigasi balik ke Login
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) =>
                        false, // Ini akan menghapus semua halaman dari memori
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String code = barcodes.first.rawValue ?? "";
              Navigator.pop(context);
              _showAssetDetail(code);
            }
          },
        ),
        // Lapisan Transparan Hitam (Hole)
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.2), // Naik sedikit dari center
                child: Container(
                  height: 280, // Kotak lebih besar agar lebih lega
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Garis Border Fokus (Neon Blue)
        Align(
          alignment: const Alignment(0, -0.2),
          child: Container(
            height: 280,
            width: 280,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueAccent, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // Instruksi di bawah kotak
        Align(
          alignment: const Alignment(0, 0.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                "Arahkan kamera ke QR Code aset",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Tombol Tutup (Alternatif selain drag)
        Positioned(
          top: 20,
          right: 20,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}

