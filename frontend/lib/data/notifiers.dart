import 'package:flutter/material.dart';
import 'package:frontend/models/pet.dart';

final Pet _defaultPet = Pet(
  id: '0',
  name: 'Sausage',
  imageUrl: 'assets/images/test_pet.jpg',
);

ValueNotifier<int> selectedPageNotifier = ValueNotifier<int>(2);
ValueNotifier<Pet> selectedPetNotificer = ValueNotifier<Pet>(_defaultPet);