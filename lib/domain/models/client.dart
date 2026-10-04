class Client {
  final int? id;
  final String name;
  final String phone;
  final String address;
  final String profession;

  const Client({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.profession,
  });

  Client copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? profession,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      profession: profession ?? this.profession,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'profession': profession,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      profession: map['profession'] as String? ?? '',
    );
  }
}
