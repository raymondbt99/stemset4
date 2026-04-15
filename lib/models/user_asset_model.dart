class UserAsset {
  final String id;
  final String assetCode;
  final String name;
  final String status;
  final String purchaseDate;
  final String roomName;
  final String? description;
  final String categoryName;
  final String? imageUrl;

  UserAsset({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.status,
    required this.purchaseDate,
    required this.roomName,
    required this.categoryName,
    this.imageUrl,
    this.description,
  });

  String get fullImageUrl {
  // Jika imageUrl null, kosong, atau hanya berisi spasi
  if (imageUrl == null || imageUrl!.trim().isEmpty) {
    return "";
  }
  
  final path = imageUrl!.trim();
  final fullUrl = "https://gbptnphvlbfudeilmdcu.supabase.co/storage/v1/object/public/assets-images/$path";
  
  // Log ini akan muncul di Debug Console setiap kali widget memanggil gambar
  print("DEBUG URL: $fullUrl"); 
  
  return fullUrl;
}

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
      imageUrl: json['image_url']?.toString(),
    );
  }
}
