import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stemset/models/user_asset_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Pastikan sudah di pubspec.yaml

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
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
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('assets')
          .select('id, name, asset_code, status, rooms(room_name)')
          .eq('assigned_to', userId);

      if (mounted) {
        setState(() {
          myAssets =
              (response as List)
                  .map((json) => UserAsset.fromJson(json))
                  .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA SCANNER & PEMINJAMAN ---

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.rawValue ?? "";
                  Navigator.pop(context); // Tutup kamera
                  _showAssetDetail(code); // Munculkan detail
                }
              },
            ),
          ),
    );
  }

  void _showQRDialog(UserAsset asset) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(asset.name, textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Scan kode ini untuk verifikasi aset"),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: asset.assetCode,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  asset.assetCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Tutup"),
              ),
            ],
          ),
    );
  }

  Future<void> _showAssetDetail(String assetCode) async {
    final data =
        await supabase
            .from('assets')
            .select('*, rooms(room_name)')
            .eq('asset_code', assetCode)
            .maybeSingle();

    if (data == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Aset tidak ditemukan!")));
      return;
    }

    final asset = UserAsset.fromJson(data);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Kode: ${asset.assetCode}",
                  style: const TextStyle(color: Colors.grey),
                ),
                const Divider(height: 30),
                _buildInfoRow(Icons.location_on, "Lokasi", asset.roomName),
                _buildInfoRow(
                  Icons.info_outline,
                  "Status Saat Ini",
                  asset.status,
                ),
                const SizedBox(height: 30),
                if (asset.status.toLowerCase() == 'available')
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _processLoan(asset.id),
                      child: const Text(
                        "PINJAM ASET INI",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Text(
                      "Aset tidak tersedia untuk dipinjam.",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _processLoan(String assetId) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase
          .from('assets')
          .update({'assigned_to': userId, 'status': 'in_use'})
          .eq('id', assetId);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Peminjaman Berhasil!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print(e);
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
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? "STEMSET - My Assets" : "Profil Pengguna",
        ),
        elevation: 0,
      ),
      // Update bagian ini:
      body:
          _currentIndex == 0
              ? _buildAssetList()
              : _buildProfilePage(), // Memanggil halaman profil

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            _openScanner();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Aset Saya',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan QR',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildAssetList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (myAssets.isEmpty)
      return const Center(child: Text("Belum ada aset terdaftar."));

    return ListView.builder(
      itemCount: myAssets.length,
      itemBuilder: (context, index) {
        final asset = myAssets[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            onTap: () => _showQRDialog(asset),
            leading: QrImageView(data: asset.assetCode, size: 40),
            title: Text(
              asset.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(asset.roomName),
            trailing: Icon(
              Icons.circle,
              size: 12,
              color:
                  asset.status == 'available'
                      ? Colors.green
                      : asset.status == 'in_use'
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfilePage() {
    final user = supabase.auth.currentUser;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Avatar / Foto Profil
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue.shade100,
            child: const Icon(Icons.person, size: 60, color: Colors.blue),
          ),
          const SizedBox(height: 20),
          // Informasi User
          Text(
            user?.userMetadata?['full_name'] ?? "User Stella Maris",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(user?.email ?? "-", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          const Divider(),
          // Menu Pengaturan/Bantuan
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("Pusat Bantuan"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("Tentang STEMSET v1.0"),
            onTap: () {},
          ),
          const Spacer(),
          // Tombol Logout
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                "KELUAR APLIKASI",
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await supabase.auth.signOut();
                // Setelah logout, arahkan kembali ke LoginPage
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
