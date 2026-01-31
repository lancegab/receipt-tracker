import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String? userId;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final bool isSystem;
  final bool isActive;

  const CategoryModel({
    required this.id,
    this.userId,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isSystem = false,
    this.isActive = true,
  });

  Color get colorValue {
    if (color == null) return Colors.grey;
    try {
      return Color(int.parse(color!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData get iconData {
    const iconMap = {
      'restaurant': Icons.restaurant,
      'shopping_cart': Icons.shopping_cart,
      'directions_car': Icons.directions_car,
      'shopping_bag': Icons.shopping_bag,
      'movie': Icons.movie,
      'receipt_long': Icons.receipt_long,
      'local_hospital': Icons.local_hospital,
      'spa': Icons.spa,
      'school': Icons.school,
      'flight': Icons.flight,
      'home': Icons.home,
      'card_giftcard': Icons.card_giftcard,
      'more_horiz': Icons.more_horiz,
      'work': Icons.work,
      'laptop': Icons.laptop,
      'trending_up': Icons.trending_up,
      'redeem': Icons.redeem,
      'replay': Icons.replay,
      'attach_money': Icons.attach_money,
    };
    return iconMap[icon] ?? Icons.category;
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isSystem: json['isSystem'] as bool? ?? json['is_system'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      };
}
