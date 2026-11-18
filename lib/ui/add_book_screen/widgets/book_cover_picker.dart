import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:readmate/logic/cubit/edit_book_cubit.dart';
import 'package:readmate/core/themes/app_theme.dart';

class BookCoverPicker extends StatelessWidget {
  const BookCoverPicker({super.key});

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (context.mounted) {
        context.read<EditBookCoverCubit>().setCover(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cover selected!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditBookCoverCubit, Uint8List?>(
      builder: (context, cover) {
        return Center(
          child: Column(
            children: [
              Container(
                width: 150,
                height: 225,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: cover != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(cover, fit: BoxFit.cover),
                      )
                    : Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 50,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _pickImage(context),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                  ),
                  if (cover != null)
                    TextButton.icon(
                      onPressed: () => context.read<EditBookCoverCubit>().setCover(null),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text("Remove", style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
