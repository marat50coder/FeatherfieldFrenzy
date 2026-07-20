import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../services/audio.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'menu_screen.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  final store = GameStorage.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SkyBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ScreenHeader(
                    title: 'Quests',
                    onBack: () => Navigator.pop(context),
                    actions: const [CoinPill()],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: AppTheme.title(16),
                      tabs: const [
                        Tab(text: 'Daily'),
                        Tab(text: 'Weekly'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _QuestList(
                          quests: kDailyQuests,
                          progress: store.questProgress,
                          resetLabel: 'Resets every day',
                          isClaimed: store.isQuestClaimed,
                          onClaim: (q) {
                            store.claimQuest(q.id, q.reward);
                            Audio.instance.reward();
                            setState(() {});
                          },
                        ),
                        _QuestList(
                          quests: kWeeklyQuests,
                          progress: store.weeklyProgress,
                          resetLabel: 'Resets every week',
                          isClaimed: store.isWeeklyClaimed,
                          onClaim: (q) {
                            store.claimWeekly(q.id, q.reward);
                            Audio.instance.reward();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestList extends StatelessWidget {
  final List<QuestDef> quests;
  final Map<String, int> progress;
  final String resetLabel;
  final bool Function(String) isClaimed;
  final void Function(QuestDef) onClaim;

  const _QuestList({
    required this.quests,
    required this.progress,
    required this.resetLabel,
    required this.isClaimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(resetLabel, style: AppTheme.body(13)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: quests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final q = quests[i];
              return _card(q, progress[q.id] ?? 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _card(QuestDef q, int done) {
    final complete = done >= q.target;
    final claimed = isClaimed(q.id);
    final ratio = (done / q.target).clamp(0.0, 1.0);
    return WoodPanel(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(q.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.title, style: AppTheme.body(16, color: AppTheme.ink)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: Colors.black12,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${done.clamp(0, q.target)} / ${q.target}',
                    style: AppTheme.body(12, color: AppTheme.brown)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _rewardButton(q, complete, claimed),
        ],
      ),
    );
  }

  Widget _rewardButton(QuestDef q, bool complete, bool claimed) {
    if (claimed) {
      return const Icon(Icons.check_circle_rounded,
          color: AppTheme.green, size: 34);
    }
    return GestureDetector(
      onTap: complete ? () => onClaim(q) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: complete ? AppTheme.primary : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded,
                color: Color(0xFFFFF3C4), size: 18),
            Text('+${q.reward}', style: AppTheme.body(13)),
          ],
        ),
      ),
    );
  }
}
