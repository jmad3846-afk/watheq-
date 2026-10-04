class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String location;
  final String itemsSold;
  final String notes;

  const Supplier({
    this.id,
    required this.name,
    required this.phone,
    required this.location,
    this.itemsSold = '',
    this.notes = '',
  });

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? location,
    String? itemsSold,
    String? notes,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      itemsSold: itemsSold ?? this.itemsSold,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'location': location,
      'items_sold': itemsSold,
      'notes': notes,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      location: map['location'] as String? ?? '',
      itemsSold: map['items_sold'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }
}
