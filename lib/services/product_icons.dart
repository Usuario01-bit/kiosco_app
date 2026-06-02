import 'package:flutter/material.dart';

const Map<String, IconData> productIcons = {
  'inventory_2': Icons.inventory_2,
  'icecream': Icons.icecream,
  'local_pizza': Icons.local_pizza,
  'lunch_dining': Icons.lunch_dining,
  'local_drink': Icons.local_drink,
  'water_drop': Icons.water_drop,
  'breakfast_dining': Icons.breakfast_dining,
  'donut_small': Icons.donut_small,
  'cookie': Icons.cookie,
  'apple': Icons.apple,
  'fastfood': Icons.fastfood,
  'cake': Icons.cake,
  'coffee': Icons.coffee,
  'bakery_dining': Icons.bakery_dining,
  'set_meal': Icons.set_meal,
  'egg': Icons.egg,
  'rice_bowl': Icons.rice_bowl,
  'emoji_food_beverage': Icons.emoji_food_beverage,
  'shopping_cart': Icons.shopping_cart,
};

IconData getIcon(String? iconName) {
  return productIcons[iconName] ?? Icons.inventory_2;
}
