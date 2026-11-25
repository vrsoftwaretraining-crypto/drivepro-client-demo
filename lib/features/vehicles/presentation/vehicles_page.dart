// Developed by @Ramana Code Softwares

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/vehicle.dart';
import '../../../core/providers/auth_providers.dart';
import '../providers/vehicle_providers.dart';

class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {SchoolVehicle? current,}) async {
    final reg = TextEditingController(text: current?.registrationNumber ?? '');
    final model = TextEditingController(text: current?.makeModel ?? '');
    final photoUrl = TextEditingController(text: current?.photoUrl ?? '');
    String transmission = current?.transmission ?? 'Manual';
    String fuel = current?.fuelType ?? 'Petrol';
    DateTime? insurance = current?.insuranceExpiry;
    DateTime? fc = current?.fcExpiry;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<SchoolVehicle>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(current == null ? 'Add vehicle' : 'Edit vehicle'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: reg,
                      decoration: const InputDecoration(
                          labelText: 'Registration number',),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Registration number is required.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: model,
                      decoration:
                          const InputDecoration(labelText: 'Make / model'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Vehicle model is required.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: photoUrl,
                      decoration: const InputDecoration(labelText: 'Public vehicle photo URL (HTTPS)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: transmission,
                      decoration:
                          const InputDecoration(labelText: 'Transmission'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Manual', child: Text('Manual'),),
                        DropdownMenuItem(
                            value: 'Automatic', child: Text('Automatic'),),
                      ],
                      onChanged: (value) => setDialogState(
                          () => transmission = value ?? 'Manual',),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: fuel,
                      decoration: const InputDecoration(labelText: 'Fuel type'),
                      items: const ['Petrol', 'Diesel', 'CNG', 'Electric']
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text(value),),)
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => fuel = value ?? 'Petrol'),
                    ),
                    const SizedBox(height: 12),
                    _datePicker(context, 'Insurance expiry', insurance,
                        (value) {
                      setDialogState(() => insurance = value);
                    }),
                    const SizedBox(height: 8),
                    _datePicker(context, 'Fitness certificate expiry', fc,
                        (value) {
                      setDialogState(() => fc = value);
                    }),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  SchoolVehicle(
                    id: current?.id ?? '',
                    registrationNumber: reg.text,
                    makeModel: model.text,
                    transmission: transmission,
                    fuelType: fuel,
                    insuranceExpiry: insurance,
                    fcExpiry: fc,
                    photoUrl: photoUrl.text,
                    active: current?.active ?? true,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    reg.dispose();
    model.dispose();
    photoUrl.dispose();
    if (result == null) return;

    final repository = ref.read(vehicleRepositoryProvider);
    try {
      if (current == null) {
        await repository.add(result);
      } else {
        await repository.update(result);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save vehicle: $error')),
        );
      }
    }
  }

  static Widget _datePicker(
    BuildContext context,
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle:
          Text(value == null ? 'Not set' : DateFormat.yMMMd().format(value)),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_month),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(appUserProvider).valueOrNull?.isAdmin ?? false;
    final data = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => _openForm(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add vehicle'),
              ),
            ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Unable to load vehicles: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No vehicles registered yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final vehicle = items[index];
              return Card(
                child: ListTile(
                  leading: vehicle.photoUrl.isEmpty
                      ? const CircleAvatar(child: Icon(Icons.directions_car_filled_outlined))
                      : CircleAvatar(backgroundImage: NetworkImage(vehicle.photoUrl)),
                  title: Text(vehicle.registrationNumber),
                  subtitle: Text(
                    '${vehicle.makeModel} • ${vehicle.transmission} • ${vehicle.fuelType}\n'
                    'Insurance: ${vehicle.insuranceExpiry == null ? 'Not set' : DateFormat.yMMMd().format(vehicle.insuranceExpiry!)}'
                    '  |  FC: ${vehicle.fcExpiry == null ? 'Not set' : DateFormat.yMMMd().format(vehicle.fcExpiry!)}',
                  ),
                  isThreeLine: true,
                  trailing: isAdmin
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _openForm(context, ref, current: vehicle);
                            } else if (value == 'archive') {
                              await ref
                                  .read(vehicleRepositoryProvider)
                                  .archive(vehicle.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'archive', child: Text('Archive'),),
                          ],
                        )
                      : Chip(
                          label: Text(vehicle.active ? 'Active' : 'Archived'),),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
