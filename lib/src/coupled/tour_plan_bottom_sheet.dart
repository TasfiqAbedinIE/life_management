import 'package:flutter/material.dart';
import 'couple_repository.dart';

Future<void> showTourPlanBottomSheet({
  required BuildContext context,
  required CoupleRepository repo,
  required String coupleId,
  Map<String, dynamic>? existing,
}) async {
  final titleCtrl = TextEditingController(text: existing?['title']);
  final descCtrl = TextEditingController(text: existing?['description']);
  final budgetCtrl = TextEditingController(
    text: existing?['estimated_budget']?.toString(),
  );

  DateTime? tourDate = existing?['probable_date'] != null
      ? DateTime.tryParse(existing!['probable_date'])
      : null;

  String status = existing?['status'] ?? 'PLANNED';

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (_, scrollCtrl) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              controller: scrollCtrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    existing == null ? 'Add Tour Plan 🌍' : 'Tour Plan Details',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 18),

                  /// Title
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Tour Title'),
                  ),

                  const SizedBox(height: 12),

                  /// Description (BIG)
                  TextField(
                    controller: descCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Detailed Plan Description',
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Budget
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Budget',
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Date picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: tourDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        tourDate = picked;
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Probable Tour Date',
                      ),
                      child: Text(
                        tourDate == null
                            ? 'Select date'
                            : tourDate!.toLocal().toString().split(' ').first,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Status
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Tour Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'PLANNED',
                        child: Text('Planned'),
                      ),
                      DropdownMenuItem(
                        value: 'CONFIRMED',
                        child: Text('Confirmed'),
                      ),
                      DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (v) => status = v!,
                  ),

                  const SizedBox(height: 22),

                  /// Save / Update
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final err = existing == null
                            ? await repo.addTourPlan(
                                coupleId: coupleId,
                                title: titleCtrl.text,
                                description: descCtrl.text,
                                budget: double.tryParse(budgetCtrl.text),
                                probableDate: tourDate,
                                status: status,
                              )
                            : await repo.updateTourPlan(
                                planId: existing['id'],
                                title: titleCtrl.text,
                                description: descCtrl.text,
                                budget: double.tryParse(budgetCtrl.text),
                                probableDate: tourDate,
                                status: status,
                              );

                        if (err == null) Navigator.pop(ctx);
                      },
                      child: Text(existing == null ? 'Save' : 'Update'),
                    ),
                  ),

                  if (existing != null)
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await repo.deleteTourPlan(existing['id']);
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
