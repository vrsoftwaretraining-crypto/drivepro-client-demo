// Developed by @Ramana Code Softwares

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/vehicle.dart';
import '../../../core/providers/auth_providers.dart';
import '../data/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(ref.watch(firestoreProvider));
});

final vehiclesProvider = StreamProvider<List<SchoolVehicle>>((ref) {
  return ref.watch(vehicleRepositoryProvider).watchAll();
});
