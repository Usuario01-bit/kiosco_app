import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const Map<String, IconData> productIcons = {
  'inventory_2': LucideIcons.package,
  'iceCreamCone': LucideIcons.iceCreamCone,
  'local_pizza': LucideIcons.pizza,
  'lunch_dining': LucideIcons.utensils,
  'local_drink': LucideIcons.cupSoda,
  'water_drop': LucideIcons.droplets,
  'breakfast_dining': LucideIcons.egg,
  'donut_small': LucideIcons.donut,
  'cookie': LucideIcons.cookie,
  'apple': LucideIcons.apple,
  'fastfood': LucideIcons.sandwich,
  'cake': LucideIcons.cake,
  'coffee': LucideIcons.coffee,
  'bakery_dining': LucideIcons.croissant,
  'set_meal': LucideIcons.beef,
  'egg': LucideIcons.egg,
  'rice_bowl': LucideIcons.soup,
  'emoji_food_beverage': LucideIcons.coffee,
  'shopping_cart': LucideIcons.shoppingCart,
};

const Map<String, String> categoryIcons = {
  'Emparedados': 'breakfast_dining',
  'Empanadas': 'set_meal',
  'Especiales': 'fastfood',
  'Café': 'coffee',
  'Bebidas': 'local_drink',
  'Duros': 'iceCreamCone',
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
  return LucideIcons.shoppingBag;
}
