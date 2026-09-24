import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle_brand.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_brand_badge.dart';
import 'package:flutter/material.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Dialog for creating or editing a vehicle.
///
/// Returns the edited [Vehicle] when saved, or null when cancelled.
class VehicleFormDialog extends StatefulWidget {
  const VehicleFormDialog({super.key, this.vehicle});

  /// Existing vehicle to edit. If null, creates a new vehicle.
  final Vehicle? vehicle;

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateController;
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _plateController = TextEditingController(text: v?.plateNumber ?? '');
    _nameController = TextEditingController(text: v?.name ?? '');
    _brandController = TextEditingController(text: v?.brand ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _yearController = TextEditingController(text: v?.year ?? '');
  }

  @override
  void dispose() {
    _plateController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final year = _yearController.text.trim();
    final vehicle = Vehicle(
      id: widget.vehicle?.id ?? '',
      plateNumber: _plateController.text.trim(),
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      model: _modelController.text.trim(),
      metadata: year.isNotEmpty ? {'year': year} : const {},
    );
    Navigator.of(context).pop(vehicle);
  }

  String? _requiredValidator(String? value) {
    return (value == null || value.trim().isEmpty) ? 'Required' : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: context.palette.surface,
      title: Text(
        _isEditing ? 'Edit vehicle' : 'Add vehicle',
        style: TextStyle(color: context.palette.textPrimary),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _VehicleTextField(
                  controller: _plateController,
                  label: 'Plate number',
                  key: const Key('vehicle-form-plate'),
                  validator: _requiredValidator,
                ),
                _VehicleTextField(
                  controller: _nameController,
                  label: 'Vehicle name',
                  key: const Key('vehicle-form-name'),
                  validator: _requiredValidator,
                ),
                _BrandField(
                  controller: _brandController,
                  key: const Key('vehicle-form-brand'),
                ),
                _VehicleTextField(
                  controller: _modelController,
                  label: 'Model',
                  key: const Key('vehicle-form-model'),
                ),
                _VehicleTextField(
                  controller: _yearController,
                  label: 'Year',
                  keyboardType: TextInputType.number,
                  key: const Key('vehicle-form-year'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Brand input: quick-select chips for common brands (badge + name, no
/// manufacturer logos) plus a free-text field for anything else.
class _BrandField extends StatelessWidget {
  const _BrandField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: VehicleBrands.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final brand = VehicleBrands.all[index];
                  final isSelected = controller.text == brand;
                  return ChoiceChip(
                    key: Key('vehicle-form-brand-chip-$brand'),
                    avatar: VehicleBrandBadge(brand: brand, size: 20),
                    label: Text(brand),
                    selected: isSelected,
                    onSelected: (_) {
                      controller.text = brand;
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: TextStyle(color: context.palette.textPrimary),
            decoration: InputDecoration(
              labelText: 'Brand',
              labelStyle: TextStyle(color: context.palette.textSecondary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: context.palette.foreground.withValues(alpha: 0.24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleTextField extends StatelessWidget {
  const _VehicleTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: context.palette.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.palette.textSecondary),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: context.palette.foreground.withValues(alpha: 0.24),
            ),
          ),
        ),
      ),
    );
  }
}
