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
    _loadData();
    supabase
        .channel('public:assets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assets',
          callback: (payload) => _loadData(),
        )
        .subscribe();
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
        title: const Text("STEMSET - My Assets"),
        actions: [
          IconButton(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      // Body akan berubah sesuai index navbar
      body:
          _currentIndex == 0
              ? _buildAssetList()
              : const Center(child: Text("Halaman Profil (Coming Soon)")),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            _openScanner(); // Panggil scanner jika tombol tengah diklik
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
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
