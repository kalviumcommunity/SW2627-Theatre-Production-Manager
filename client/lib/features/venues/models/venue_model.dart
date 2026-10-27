import 'package:cloud_firestore/cloud_firestore.dart';

class Venue {
  final String id;
  final String name;
  final String address;
  final int capacity;
  final String description;
  final List<String> facilities;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  const Venue({
    required this.id,
    required this.name,
    this.address = '',
    required this.capacity,
    this.description = '',
    this.facilities = const [],
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  bool get isValidCapacity => capacity > 0;

  Venue copyWith({
    String? id,
    String? name,
    String? address,
    int? capacity,
    String? description,
    List<String>? facilities,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Venue(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      capacity: capacity ?? this.capacity,
      description: description ?? this.description,
      facilities: facilities ?? this.facilities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'address': address.trim(),
      'capacity': capacity,
      'description': description.trim(),
      'facilities': facilities,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Venue.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawFacilities = map['facilities'];
    List<String> parsedFacilities = [];
    if (rawFacilities is List) {
      parsedFacilities = rawFacilities.map((e) => e.toString()).toList();
    }

    return Venue(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      address: (map['address'] as String? ?? '').trim(),
      capacity: (map['capacity'] as num? ?? 0).toInt(),
      description: (map['description'] as String? ?? '').trim(),
      facilities: parsedFacilities,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      isDeleted: map['deleted'] == true,
    );
  }
}
