import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/support_provider.dart';

class SupportListScreen extends ConsumerWidget {
  const SupportListScreen({super.key});

  Future<void> _createNewTicket(BuildContext context, WidgetRef ref) async {
    final fetchedTopics = await ref.read(supportProvider.notifier).fetchTopics();
    final predefinedSubjects = [...fetchedTopics, 'Other'];
    String selectedSubjectOption = predefinedSubjects.first;
    final customSubjectController = TextEditingController();
    final messageController = TextEditingController();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Support Ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subject Topic', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedSubjectOption,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: predefinedSubjects.map((subject) {
                    return DropdownMenuItem(
                      value: subject,
                      child: Text(subject, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedSubjectOption = val);
                    }
                  },
                ),
                if (selectedSubjectOption == 'Other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customSubjectController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Subject',
                      hintText: 'Enter your issue subject...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe your issue in detail...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final finalSubject = selectedSubjectOption == 'Other'
                    ? customSubjectController.text.trim()
                    : selectedSubjectOption;

                if (finalSubject.isNotEmpty && messageController.text.trim().isNotEmpty) {
                  await ref.read(supportProvider.notifier).createTicket(finalSubject, messageController.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(supportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Desk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(supportProvider.notifier).fetchTickets(),
          )
        ],
      ),
      body: tickets.isEmpty
          ? const Center(child: Text('You have no active support tickets.'))
          : RefreshIndicator(
              onRefresh: () => ref.read(supportProvider.notifier).fetchTickets(),
              child: ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  return ListTile(
                    title: Text(ticket.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Status: ${ticket.status.toUpperCase()} • ${ticket.messagesCount} messages'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/home/support/chat', extra: ticket.id);
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewTicket(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
