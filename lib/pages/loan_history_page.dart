import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan_model.dart'; // Sesuaikan path model Anda

class LoanHistoryPage extends StatefulWidget {
  const LoanHistoryPage({super.key});

  @override
  State<LoanHistoryPage> createState() => _LoanHistoryPageState();
}

class _LoanHistoryPageState extends State<LoanHistoryPage> {
  final supabase = Supabase.instance.client;
  // Ubah atau tambahkan variabel ini
  List<dynamic> _loanHistoryRaw = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLoanHistory();
  }

Future<void> _fetchLoanHistory() async {
  try {
    final userId = supabase.auth.currentUser!.id;
    
    // Melakukan JOIN dengan tabel assets
    final response = await supabase
        .from('loans')
        .select('''
          *,
          assets:asset_id (
            name,
            asset_code
          )
        ''')
        .eq('user_id', userId)
        .order('loan_date', ascending: false);

    setState(() {
      // Kita simpan hasil response mentah (Map) ke list agar mudah diakses
      _loanHistoryRaw = response as List; 
      _isLoading = false;
    });
  } catch (e) {
    print("Error history: $e");
    setState(() => _isLoading = false);
  }
}

String _formatDate(String? dateStr) {
  if (dateStr == null) return "-";
  final date = DateTime.parse(dateStr);
  // Format: 15 Apr 2026
  return "${date.day} ${_getMonthName(date.month)} ${date.year}";
}

String _getMonthName(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  return months[month - 1];
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Peminjaman"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loanHistoryRaw.isEmpty // Gunakan _loanHistoryRaw
              ? const Center(child: Text("Belum ada riwayat peminjaman."))
              : ListView.builder( // WAJIB ada widget ListView.builder di sini
                  padding: const EdgeInsets.all(16),
                  itemCount: _loanHistoryRaw.length,
                  itemBuilder: (context, index) {
                    final loan = _loanHistoryRaw[index];
                    final asset = loan['assets'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: loan['status'] == 'active'
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            loan['status'] == 'active'
                                ? Icons.pending
                                : Icons.check,
                            color: loan['status'] == 'active'
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                        title: Text(
                          asset != null ? asset['name'] : "Aset Tidak Diketahui",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(asset != null ? "Kode: ${asset['asset_code']}" : "-"),
    const SizedBox(height: 4),
    
    // Baris Tanggal Pinjam
    Row(
      children: [
        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          "Pinjam: ${_formatDate(loan['loan_date'])}",
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),

    // LOGIC TAMPILKAN TANGGAL KEMBALI
    if (loan['status'] == 'returned' && loan['return_date'] != null)
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            const Icon(Icons.event_available, size: 12, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              "Kembali: ${_formatDate(loan['return_date'])}",
              style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
  ],
),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              loan['status'] == 'active' ? "AKTIF" : "KEMBALI",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: loan['status'] == 'active'
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}