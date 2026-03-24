import 'package:flutter/material.dart';
import 'package:frontend/services/pets_api.dart';
import 'pet_form_page.dart';

class PetDetailPage extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PetDetailPage({super.key, required this.pet});

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  static const bg = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);
  static const cardColor = Colors.white;

  late Map<String, dynamic> _pet;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
  }

  Future<void> _handleMarkPassed() async {
    final hasPassed = _pet['date_of_death'] != null;

    if (hasPassed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove date of passing?'),
          content: const Text('This will mark the pet as still living.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await PetsApi.updatePet(
        petId: _pet['id'] as int,
        body: {'date_of_death': null},
      );
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1980),
        lastDate: DateTime.now(),
        helpText: 'Date of passing',
      );
      if (picked == null || !mounted) return;
      final dateStr =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      await PetsApi.updatePet(
        petId: _pet['id'] as int,
        body: {'date_of_death': dateStr},
      );
    }

    if (!mounted) return;
    try {
      final updated = await PetsApi.getPet(_pet['id'] as int);
      if (!mounted) return;
      setState(() => _pet = updated);
      Navigator.of(context).pop(true); // tell caller to refresh
    } catch (_) {}
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.of(
      context,
    ).push<dynamic>(MaterialPageRoute(builder: (_) => PetFormPage(pet: _pet)));
    if (!mounted) return;

    if (result is Map && result['__deleted'] == true) {
      Navigator.of(context).pop(true);
      return;
    }

    if (result == null) return;

    try {
      final updated = await PetsApi.getPet(_pet['id'] as int);
      if (!mounted) return;
      setState(() => _pet = updated);
    } catch (_) {
      setState(() => _pet = result as Map<String, dynamic>);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _PetDetailData.fromMap(_pet);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          data.appBarTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: muted),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: muted,
            tooltip: 'Edit pet',
            onPressed: _handleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PetHeaderAvatar(photoUrl: data.photoUrl),
            const SizedBox(height: 16),
            _PetName(name: data.displayName),
            const SizedBox(height: 24),
            _PetInfoCard(data: data),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _handleMarkPassed,
              style: TextButton.styleFrom(
                foregroundColor: data.dateOfDeath != null
                    ? muted
                    : Colors.red.shade400,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                data.dateOfDeath != null
                    ? 'Remove date of passing'
                    : 'My pet has passed away',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PetHeaderAvatar extends StatelessWidget {
  final String? photoUrl;

  const _PetHeaderAvatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Center(
      child: CircleAvatar(
        radius: 55,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
        child: hasPhoto
            ? null
            : const Icon(
                Icons.pets,
                color: _PetDetailPageState.muted,
                size: 48,
              ),
      ),
    );
  }
}

class _PetName extends StatelessWidget {
  final String name;

  const _PetName({required this.name});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: _PetDetailPageState.muted,
      ),
    );
  }
}

class _PetInfoCard extends StatelessWidget {
  final _PetDetailData data;

  const _PetInfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = <_PetInfoItem>[
      _PetInfoItem('Species', data.species),
      _PetInfoItem('Breed', data.breed),
      _PetInfoItem('Sex', data.sex),
      _PetInfoItem('Spayed / Neutered', data.spayedText),
      _PetInfoItem('Age', data.age),
      _PetInfoItem('Weight', data.weight),
      _PetInfoItem('Birthdate', data.birthdate),
      if (data.dateOfDeath != null)
        _PetInfoItem('Date of passing', data.dateOfDeath!),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _PetDetailPageState.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 6),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Column(
        children: List.generate(
          rows.length,
          (index) => _PetInfoRow(
            label: rows[index].label,
            value: rows[index].value,
            isFirst: index == 0,
          ),
        ),
      ),
    );
  }
}

class _PetInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isFirst;

  const _PetInfoRow({
    required this.label,
    required this.value,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst)
          const Divider(
            height: 1,
            indent: 18,
            endIndent: 18,
            color: Color(0xFFEEE8E2),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _PetDetailPageState.muted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _PetDetailPageState.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PetInfoItem {
  final String label;
  final String value;

  const _PetInfoItem(this.label, this.value);
}

class _PetDetailData {
  final String appBarTitle;
  final String displayName;
  final String? photoUrl;
  final String species;
  final String breed;
  final String sex;
  final String spayedText;
  final String age;
  final String weight;
  final String birthdate;
  final String? dateOfDeath;

  const _PetDetailData({
    required this.appBarTitle,
    required this.displayName,
    required this.photoUrl,
    required this.species,
    required this.breed,
    required this.sex,
    required this.spayedText,
    required this.age,
    required this.weight,
    required this.birthdate,
    required this.dateOfDeath,
  });

  factory _PetDetailData.fromMap(Map<String, dynamic> pet) {
    final petName = (pet['name'] ?? '').toString().trim();
    final species = (pet['species'] ?? '').toString().trim();
    final breed = (pet['breed_text'] ?? '').toString().trim();
    final sex = (pet['sex'] ?? '').toString().trim();
    final photoUrl = pet['photo_url']?.toString().trim();

    final spayedNeutered = pet['spayed_neutered'];
    String spayedText = '—';
    if (spayedNeutered is bool) {
      spayedText = spayedNeutered ? 'Yes' : 'No';
    } else if (spayedNeutered == 'true') {
      spayedText = 'Yes';
    } else if (spayedNeutered == 'false') {
      spayedText = 'No';
    }

    final weightKg = pet['weight_kg'];

    return _PetDetailData(
      appBarTitle: petName.isEmpty ? 'Pet' : petName,
      displayName: petName.isEmpty ? 'Unnamed pet' : petName,
      photoUrl: photoUrl != null && photoUrl.isNotEmpty ? photoUrl : null,
      species: species.isNotEmpty ? _capitalize(species) : '—',
      breed: breed.isNotEmpty ? breed : '—',
      sex: sex.isNotEmpty ? _capitalize(sex) : '—',
      spayedText: spayedText,
      age: _computeAge(pet['birthdate']) ?? '—',
      weight: weightKg != null ? '$weightKg kg' : '—',
      birthdate: _formatDate(pet['birthdate']) ?? '—',
      dateOfDeath: _formatDate(pet['date_of_death']),
    );
  }

  static String _capitalize(String s) {
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  static String? _computeAge(dynamic birthdateRaw) {
    if (birthdateRaw == null) return null;

    try {
      final birth = DateTime.parse(birthdateRaw.toString());
      final now = DateTime.now();

      int years = now.year - birth.year;
      int months = now.month - birth.month;

      if (now.day < birth.day) months--;

      if (months < 0) {
        years--;
        months += 12;
      }

      if (years < 0) return null;
      if (years == 0 && months == 0) return '< 1 month';
      if (years == 0) return '$months ${months == 1 ? 'month' : 'months'}';
      if (months == 0) return '$years ${years == 1 ? 'year' : 'years'}';

      return '$years ${years == 1 ? 'year' : 'years'} '
          '$months ${months == 1 ? 'month' : 'months'}';
    } catch (_) {
      return null;
    }
  }

  static String? _formatDate(dynamic raw) {
    if (raw == null) return null;

    try {
      final dt = DateTime.parse(raw.toString());
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return null;
    }
  }
}
