import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/widgets/glass_card.dart';

class LifeScreen extends ConsumerStatefulWidget {
  const LifeScreen({super.key});

  @override
  ConsumerState<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends ConsumerState<LifeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _taskCtrl = TextEditingController();
  final _noteTitle = TextEditingController();
  final _noteBody = TextEditingController();
  final _noteSearch = TextEditingController();
  final _reelUrl = TextEditingController();
  final _reelCaption = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Listen to sharing intents for Reels tab
    try {
      ReceiveSharingIntent.instance.getMediaStream().listen((value) async {
        if (value.isEmpty) return;
        final first = value.first;
        await ref.read(reelsProvider.notifier)
            .addReel(first.path, first.message ?? '');
      });
    } catch (e) {
      debugPrint('Sharing intent error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskCtrl.dispose();
    _noteTitle.dispose();
    _noteBody.dispose();
    _noteSearch.dispose();
    _reelUrl.dispose();
    _reelCaption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentPurple,
          labelColor: AppColors.accentPurple,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.checklist), text: 'Planner'),
            Tab(icon: Icon(Icons.note_alt_outlined), text: 'Notes'),
            Tab(icon: Icon(Icons.video_collection_outlined), text: 'Reels'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlannerTab(controller: _taskCtrl),
          _NotesTab(
            titleCtrl: _noteTitle,
            bodyCtrl: _noteBody,
            searchCtrl: _noteSearch,
          ),
          _ReelsTab(urlCtrl: _reelUrl, captionCtrl: _reelCaption),
        ],
      ),
    );
  }
}

class _PlannerTab extends ConsumerWidget {
  const _PlannerTab({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(plannerTasksProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Add task'),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) return;
                  ref.read(plannerTasksProvider.notifier)
                      .addTask(controller.text.trim());
                  controller.clear();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tasks yet. Start planning!'),
            ),
          )
        else
          ...tasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline,
                            color: AppColors.accentTeal),
                        onPressed: () => ref
                            .read(plannerTasksProvider.notifier)
                            .removeTask(task),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(task)),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.searchCtrl,
  });
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController searchCtrl;

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final query = widget.searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? notes
        : notes
            .where((n) =>
                n.title.toLowerCase().contains(query) ||
                n.body.toLowerCase().contains(query))
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: widget.searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Search notes',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: widget.bodyCtrl,
                decoration: const InputDecoration(labelText: 'Body'),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (widget.titleCtrl.text.trim().isEmpty ||
                        widget.bodyCtrl.text.trim().isEmpty) {
                      return;
                    }
                    await ref.read(notesProvider.notifier).addNote(
                          widget.titleCtrl.text.trim(),
                          widget.bodyCtrl.text.trim(),
                        );
                    widget.titleCtrl.clear();
                    widget.bodyCtrl.clear();
                  },
                  child: const Text('Save + Summarize'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No notes found. Create one above!'),
            ),
          )
        else
          ...filtered.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => ref
                                .read(notesProvider.notifier)
                                .deleteNote(note.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(note.body),
                      if (note.aiSummary != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'AI Summary: ${note.aiSummary!}',
                            style: const TextStyle(
                                color: AppColors.accentPurple, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

class _ReelsTab extends ConsumerWidget {
  const _ReelsTab({required this.urlCtrl, required this.captionCtrl});
  final TextEditingController urlCtrl;
  final TextEditingController captionCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reels = ref.watch(reelsProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'Reel URL'),
              ),
              TextField(
                controller: captionCtrl,
                decoration: const InputDecoration(labelText: 'Caption'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (urlCtrl.text.trim().isEmpty) return;
                    await ref.read(reelsProvider.notifier)
                        .addReel(urlCtrl.text.trim(), captionCtrl.text.trim());
                    urlCtrl.clear();
                    captionCtrl.clear();
                  },
                  child: const Text('Save + Auto-tag'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (reels.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No saved reels yet. Paste a URL above!'),
            ),
          )
        else
          ...reels.map((reel) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              reel.url,
                              style: const TextStyle(
                                  color: AppColors.accentPurple, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => ref
                                .read(reelsProvider.notifier)
                                .deleteReel(reel.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(reel.caption),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: reel.aiTags
                            .map((tag) => Chip(
                                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor:
                                      AppColors.accentPink.withValues(alpha: 0.15),
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}
