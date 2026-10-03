import 'package:flutter/material.dart';

/// Đại diện cho một môn học / học phần trong hệ thống (Tương đương Wallets trong Cashew)
class Subject {
  final String subjectPk;
  final String name;
  final String code;
  final String colour;
  final String iconName;
  final DateTime dateTimeModified;

  Subject({
    required this.subjectPk,
    required this.name,
    required this.code,
    required this.colour,
    required this.iconName,
    required this.dateTimeModified,
  });

  Color get colorValue {
    try {
      final hex = colour.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }

  Subject copyWith({
    String? subjectPk,
    String? name,
    String? code,
    String? colour,
    String? iconName,
    DateTime? dateTimeModified,
  }) {
    return Subject(
      subjectPk: subjectPk ?? this.subjectPk,
      name: name ?? this.name,
      code: code ?? this.code,
      colour: colour ?? this.colour,
      iconName: iconName ?? this.iconName,
      dateTimeModified: dateTimeModified ?? this.dateTimeModified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectPk': subjectPk,
      'name': name,
      'code': code,
      'colour': colour,
      'iconName': iconName,
      'dateTimeModified': dateTimeModified.toIso8601String(),
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      subjectPk: map['subjectPk'] as String,
      name: map['name'] as String,
      code: (map['code'] as String?) ?? '',
      colour: (map['colour'] as String?) ?? '#1E88E5',
      iconName: (map['iconName'] as String?) ?? 'book',
      dateTimeModified: DateTime.tryParse(map['dateTimeModified'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
