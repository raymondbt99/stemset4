class UserAsset {
  final String id;
  final String assetCode;
  final String name;
  final String status;
  final String purchaseDate;
  final String roomName;
  final String? description;
  final String categoryName;

  UserAsset({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.status,
    required this.purchaseDate,
    required this.roomName,
    required this.categoryName,
    this.description,
  });

  // Getter untuk mempermudah pengecekan status di UI (Warna Badge)
  bool get isMaintenance => status.toLowerCase() == 'maintenance';
  bool get isAvailable => status.toLowerCase() == 'available';
  bool get isBroken => status.toLowerCase() == 'broken';

  // Factory method untuk mapping JSON dari Supabase
  factory UserAsset.fromJson(Map<String, dynamic> json) {
    return UserAsset(
      id: json['id'] ?? '',
      assetCode: json['asset_code'] ?? 'NO-CODE',
      name: json['name'] ?? 'Unnamed Asset',
      status: json['status'] ?? 'available',
      purchaseDate: json['purchase_date'] ?? '',
      // Menangani join table dari 'rooms'
      categoryName:
          json['categories'] != null
              ? json['categories']['name']
              : 'Uncategorized',
      roomName:
          json['rooms'] != null
              ? json['rooms']['room_name']
              : 'General Storage',
      description: json['description'],
    );
  }
}
