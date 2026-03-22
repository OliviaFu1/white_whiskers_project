import 'package:frontend/models/pet.dart';
import 'package:frontend/services/pets_api.dart';

abstract class PetRepository {
  Future<List<Pet>> fetchPets();
}

class RealPetRepository implements PetRepository {
  @override
  Future<List<Pet>> fetchPets() async {
    final rawList = await PetsApi.listPets();
    return rawList
        .map(
          (p) => Pet(
            id: p["id"] as int,
            name: (p["name"] ?? "").toString(),
            photoUrl: p["photo_url"]?.toString(),
          ),
        )
        .toList();
  }
}
