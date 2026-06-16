import 'package:flutter/material.dart';

const Map<String, IconData> productIcons = {
  'inventory_2': Icons.inventory_2_outlined,
  'icecream': Icons.icecream_outlined,
  'local_pizza': Icons.local_pizza_outlined,
  'lunch_dining': Icons.lunch_dining_outlined,
  'local_drink': Icons.local_drink_outlined,
  'water_drop': Icons.water_drop_outlined,
  'breakfast_dining': Icons.breakfast_dining_outlined,
  'donut_small': Icons.donut_small_outlined,
  'cookie': Icons.cookie_outlined,
  'apple': Icons.apple_outlined,
  'fastfood': Icons.fastfood_outlined,
  'cake': Icons.cake_outlined,
  'coffee': Icons.coffee_outlined,
  'bakery_dining': Icons.bakery_dining_outlined,
  'set_meal': Icons.set_meal_outlined,
  'egg': Icons.egg_outlined,
  'rice_bowl': Icons.rice_bowl_outlined,
  'emoji_food_beverage': Icons.emoji_food_beverage_outlined,
  'shopping_cart': Icons.shopping_cart_outlined,
};

const Map<String, String> categoryIcons = {
  'Emparedados': 'breakfast_dining',
  'Empanadas': 'set_meal',
  'Especiales': 'fastfood',
  'Café': 'coffee',
  'Bebidas': 'local_drink',
  'Duros': 'icecream',
  'General': 'inventory_2',
};

IconData resolveProductIcon(Map<String, dynamic> product) {
  final iconName = product['icon'] as String?;
  if (iconName != null && productIcons.containsKey(iconName)) {
    return productIcons[iconName]!;
  }
  final cat = product['category'] as String? ?? 'General';
  final catIcon = categoryIcons[cat];
  if (catIcon != null && productIcons.containsKey(catIcon)) {
    return productIcons[catIcon]!;
  }
  return Icons.shopping_bag;
}
