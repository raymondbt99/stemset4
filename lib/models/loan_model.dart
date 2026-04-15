class Loan {
  final String? id;
  final String assetId;
  final String userId;
  final DateTime loanDate;
  final DateTime? returnDate;
  final String? notes;
  final String status;

  Loan({
    this.id,
    required this.assetId,
    required this.userId,
    required this.loanDate,
    this.returnDate,
    this.notes,
    this.status = 'active',
  });

  // Untuk mengubah data dari Supabase (JSON) ke Object Flutter
  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'],
      assetId: json['asset_id'],
      userId: json['user_id'],
      loanDate: DateTime.parse(json['loan_date']),
      returnDate: json['return_date'] != null 
          ? DateTime.parse(json['return_date']) 
          : null,
      notes: json['notes'],
      status: json['status'],
    );
  }

  // Untuk mengubah Object Flutter ke Map (saat mau Insert ke Supabase)
  Map<String, dynamic> toJson() {
    return {
      'asset_id': assetId,
      'user_id': userId,
      'notes': notes,
      'status': status,
      // loan_date tidak perlu dikirim jika di SQL sudah pakai default now()
    };
  }
}