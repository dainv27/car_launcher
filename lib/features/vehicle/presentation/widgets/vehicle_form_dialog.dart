import 'dart:async';
import 'dart:io';

import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle_brand.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_brand_badge.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:car_launcher/core/theme/launcher_palette.dart';
import 'package:car_launcher/features/vehicle/data/vehicle_api_client.dart';

/// Dialog for creating or editing a vehicle.
///
/// Runs [onSubmit] itself and stays open until it succeeds, so a rejected
/// save keeps what the driver typed and shows the server's reason inline.
/// Returns the submitted [Vehicle] once saved, or null when cancelled.
class VehicleFormDialog extends StatefulWidget {
  const VehicleFormDialog({super.key, this.vehicle, required this.onSubmit});

  /// Existing vehicle to edit. If null, creates a new vehicle.
  final Vehicle? vehicle;

  /// Persists the vehicle; a thrown error is shown in the dialog.
  final Future<void> Function(Vehicle vehicle) onSubmit;

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
  // Explicit keyboard "next" chain. The default traversal lost focus after
  // the name field on the head unit, closing the keyboard mid-form.
  final _nameFocus = FocusNode();
  final _brandFocus = FocusNode();
  final _modelFocus = FocusNode();
  final _yearFocus = FocusNode();
  final _scrollController = ScrollController();
  bool _saving = false;
  String? _error;

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
    _nameFocus.dispose();
    _brandFocus.dispose();
    _modelFocus.dispose();
    _yearFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final year = _yearController.text.trim();
    final vehicle = Vehicle(
      id: widget.vehicle?.id ?? '',
      plateNumber: _plateController.text.trim(),
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      model: _modelController.text.trim(),
      metadata: year.isNotEmpty ? {'year': year} : const {},
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(vehicle);
      if (mounted) Navigator.of(context).pop(vehicle);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = describeVehicleError(error);
        });
        // The banner sits above the fields; bring it into view when the
        // driver submitted from further down the form.
        if (_scrollController.hasClients) {
          unawaited(
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
          );
        }
      }
    }
  }

  String? _requiredValidator(String? value) {
    return (value == null || value.trim().isEmpty) ? 'Required' : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(
        _isEditing ? 'Edit vehicle' : 'Add vehicle',
        style: TextStyle(color: context.palette.textPrimary),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) _ErrorBanner(message: _error!),
                if (!_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'The vehicle will be linked to this head unit.',
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                  ),
                _VehicleTextField(
                  controller: _plateController,
                  label: 'Plate number',
                  key: const Key('vehicle-form-plate'),
                  validator: _requiredValidator,
                  onFieldSubmitted: (_) => _nameFocus.requestFocus(),
                ),
                _VehicleTextField(
                  controller: _nameController,
                  label: 'Vehicle name',
                  key: const Key('vehicle-form-name'),
                  validator: _requiredValidator,
                  focusNode: _nameFocus,
                  onFieldSubmitted: (_) => _brandFocus.requestFocus(),
                ),
                _BrandField(
                  controller: _brandController,
                  focusNode: _brandFocus,
                  onSubmitted: (_) => _modelFocus.requestFocus(),
                  key: const Key('vehicle-form-brand'),
                ),
                _VehicleTextField(
                  controller: _modelController,
                  label: 'Model',
                  key: const Key('vehicle-form-model'),
                  focusNode: _modelFocus,
                  onFieldSubmitted: (_) => _yearFocus.requestFocus(),
                ),
                _VehicleTextField(
                  controller: _yearController,
                  label: 'Year',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  focusNode: _yearFocus,
                  onFieldSubmitted: (_) => _save(),
                  key: const Key('vehicle-form-year'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('vehicle-form-save'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Brand input: quick-select chips for common brands (badge + name, no
/// manufacturer logos) plus a free-text field for anything else.
class _BrandField extends StatelessWidget {
  const _BrandField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            // Touch-only shortcuts: keep them out of focus traversal so the
            // keyboard's "next" goes Brand → Model instead of into the chips.
            child: ExcludeFocus(
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
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.next,
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
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        focusNode: focusNode,
        // Per field, not per Form: a Form-level mode validates every field
        // as soon as any one changes, flagging fields not reached yet. This
        // re-checks only what the driver touched, so "Required" clears once
        // the field is filled.
        autovalidateMode: AutovalidateMode.onUserInteraction,
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

/// Turns a save/load failure into text for the driver: the server's own
/// message when it gave one, otherwise a generic connectivity hint.
String describeVehicleError(Object error) {
  if (error is VehicleServiceException) return error.message;
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException) {
    return 'Could not reach the vehicle service. Check the connection and try again.';
  }
  return 'Something went wrong: $error';
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('vehicle-form-error'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: context.palette.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
