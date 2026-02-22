import 'package:flutter/material.dart';
import 'package:frontend/data/notifiers.dart';
import 'package:frontend/views/models/pet.dart';

class PetsDropdown extends StatefulWidget {
  const PetsDropdown({super.key});

  @override
  State<PetsDropdown> createState() => _PetsDropdownState();
}

class _PetsDropdownState extends State<PetsDropdown> {
  List<Pet> pets = [
    Pet(id: '0', name: 'Sausage', imageUrl: 'assets/images/test_pet.jpg'),
    Pet(id: '1', name: 'Pausage', imageUrl: 'assets/images/test_pet.jpg'),
    Pet(id: '2', name: 'Mortage', imageUrl: 'assets/images/test_pet.jpg'),
  ]; //temporary list
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedPetNotificer,
      builder: (context, currentPet, child) {
        return PopupMenuButton<Pet>(
          offset: Offset(10, 42),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(currentPet.name, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(width: 5),
              CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage(currentPet.imageUrl),
              ),
            ],
          ),
          onSelected: (Pet selectedPet) {
            selectedPetNotificer.value = selectedPet;
          },
          itemBuilder: (context) {
            return pets
                .where((pet) => pet.id != currentPet.id)
                .map(
                  (pet) => PopupMenuItem<Pet>(
                    value: pet,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pet.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 3),
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: AssetImage(pet.imageUrl),
                        ),
                      ],
                    ),
                  ),
                )
                .toList();
          },
        );
      },
    );
  }
}
