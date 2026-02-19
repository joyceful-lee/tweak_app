import 'package:flutter/material.dart';
import '../services/dish_service.dart';

/// ------------------------------
/// Add a new dish to the dish list
/// ------------------------------
class AddDishScreen extends StatefulWidget {
  final DishService dishService;

  const AddDishScreen({super.key, required this.dishService});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController tagsController = TextEditingController();

  String status = "in_testing";

  final List<TextEditingController> ingredientControllers = [TextEditingController()];
  final List<TextEditingController> directionControllers = [TextEditingController()];

  bool _isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    tagsController.dispose();
    for (var c in ingredientControllers) {
      c.dispose();
    }
    for (var c in directionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveDish() async {
    if (!_formKey.currentState!.validate()) return;

    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    final ingredients = ingredientControllers
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final directions = directionControllers
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final notes = notesController.text.trim();
    final tags = tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (ingredients.isEmpty || directions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ingredients and directions cannot be empty"),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.dishService.createDish(
        name: name,
        description: description,
        status: status,
        ingredients: ingredients,
        directions: directions,
        notes: notes,
        tags: tags,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dish created successfully")),
      );
      Navigator.pop(context); // Return to dish list
    } catch (e, stackTrace) {
      debugPrint('ERROR: $e');
      debugPrint('STACKTRACE:\n$stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildDynamicList(String title, List<TextEditingController> controllers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Noot')),
        const SizedBox(height: 8),
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Cannot be empty' : null,
                  decoration: InputDecoration(labelText: "$title ${index + 1}"),
                ),
              ),
              if (controllers.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle),
                  onPressed: () => setState(() => controllers.removeAt(index)),
                ),
            ],
          );
        }),
        TextButton(
          onPressed: () => setState(() => controllers.add(TextEditingController())),
          child: Text("Add $title"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Dish")),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dish Name
              TextFormField(
                controller: nameController,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                decoration: const InputDecoration(labelText: "Dish Name"),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: descriptionController,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Description is required' : null,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 12),

              // Status
              DropdownButtonFormField<String>(
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: "finalized", child: Text("Finalized")),
                  DropdownMenuItem(value: "in_testing", child: Text("In Testing")),
                  DropdownMenuItem(value: "abandoned", child: Text("Abandoned")),
                ],
                onChanged: (value) => setState(() => status = value!),
                decoration: const InputDecoration(labelText: "Status"),
              ),
              const SizedBox(height: 16),

              // Ingredients
              _buildDynamicList("Ingredient", ingredientControllers),
              const SizedBox(height: 16),

              // Directions
              _buildDynamicList("Step", directionControllers),
              const SizedBox(height: 16),

              // Tags
              TextFormField(
                controller: tagsController,
                decoration: const InputDecoration(labelText: "Tags (comma separated)"),
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: "Notes"),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDish,
                  child: const Text("Save Dish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
