import 'package:flutter/material.dart';
import '../data/ebook_repo_supabase.dart';
import '../data/models/ebook.dart';

class EbookLibraryPage extends StatefulWidget {
  const EbookLibraryPage({super.key});

  @override
  State<EbookLibraryPage> createState() => _EbookLibraryPageState();
}

class _EbookLibraryPageState extends State<EbookLibraryPage> {
  final _repo = EbookRepoSupabase();
  late Future<List<Ebook>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchEbooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Book Library')),
      body: FutureBuilder<List<Ebook>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final ebooks = snapshot.data!;
          if (ebooks.isEmpty) {
            return const Center(child: Text('No ebooks found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: ebooks.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final ebook = ebooks[index];
              return ListTile(
                leading: Icon(
                  ebook.fileType == 'pdf'
                      ? Icons.picture_as_pdf
                      : Icons.menu_book,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(ebook.title),
                subtitle: Text(ebook.author),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Step 3: open bottom sheet (Download / Read)
                },
              );
            },
          );
        },
      ),
    );
  }
}
