import 'package:frontend/models/pet.dart';

abstract class PetRepository {
  Future<List<Pet>> fetchPets();
}

//TODO: change to actual backend
class FakePetRepository implements PetRepository {
  @override
  Future<List<Pet>> fetchPets() async {
    await Future.delayed(const Duration(seconds: 1)); // delay from API

    return [
      Pet(id: '0', name: 'Sausage', imageUrl: 'assets/images/test_pet.jpg'),
      Pet(id: '1', name: 'Pausage', imageUrl: 'assets/images/test_pet.jpg'),
      Pet(id: '2', name: 'Mortage', imageUrl: 'assets/images/test_pet.jpg'),
    ];
  }
}
