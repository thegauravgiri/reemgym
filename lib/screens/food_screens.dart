import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app.dart';
import '../models.dart';
import '../services/food_analyzer.dart';
import '../services/research_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

/// Where a new food entry should land.
class LogTarget {
  final String uid;
  final String dayKey;
  final MealType? meal;

  /// The user agreed to share analysed meals for research.
  final bool research;
  const LogTarget(this.uid, this.dayKey, {this.meal, this.research = false});

  FoodEntry draft(String title, List<FoodItem> items, String source) =>
      FoodEntry(
        id: newId(),
        dayKey: dayKey,
        meal: meal ?? mealForTime(DateTime.now()),
        title: title,
        items: items,
        source: source,
        createdAt: DateTime.now(),
      );
}

/// Takes or picks a photo, then runs it through the analyzer.
Future<void> logFromPhoto(
  BuildContext context,
  LogTarget target,
  ImageSource source,
) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 75,
    );
  } catch (e) {
    if (context.mounted) {
      showMessage(
        context,
        source == ImageSource.camera
            ? 'The camera is not available here. Try choosing a photo.'
            : 'Could not open your photos. $e',
      );
    }
    return;
  }
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnalyzeScreen(
        target: target,
        image: bytes,
        mimeType: file!.mimeType ?? 'image/jpeg',
      ),
    ),
  );
}

/// Asks the user to describe a meal in words, then analyzes the description.
Future<void> logFromText(BuildContext context, LogTarget target) async {
  final controller = TextEditingController();
  final text = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Describe your meal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Mention amounts if you know them.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'e.g. 2 boiled eggs, a plate of chicken momo '
                  'and a cup of milk tea',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Estimate nutrition'),
          ),
        ],
      ),
    ),
  );
  if (text == null || text.isEmpty || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnalyzeScreen(target: target, description: text),
    ),
  );
}

/// Opens an empty meal for the user to fill in by hand.
Future<void> logManually(BuildContext context, LogTarget target) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodReviewScreen(
          uid: target.uid,
          entry: target.draft('', const [], 'manual'),
          isNew: true,
        ),
      ),
    );

/// Lets the user re-log something they ate before.
Future<void> logFromRecent(BuildContext context, LogTarget target) async {
  final repo = Services.of(context).repo;
  final picked = await showModalBottomSheet<FoodEntry>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scroll) => FutureBuilder<List<FoodEntry>>(
        future: repo.recentFood(target.uid),
        builder: (context, snap) {
          final theme = Theme.of(context);
          if (snap.hasError) {
            return Center(child: Text('Could not load: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final recent = snap.data!;
          if (recent.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Meals you log will show up here so you can add them '
                  'again with one tap.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: recent.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Recent meals',
                    style: theme.textTheme.titleLarge,
                  ),
                );
              }
              final e = recent[i - 1];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${e.calories.round()} kcal · '
                  'P ${e.protein.round()} · C ${e.carbs.round()} · '
                  'F ${e.fat.round()}',
                ),
                trailing: const Icon(Icons.add_circle_outline_rounded),
                onTap: () => Navigator.pop(context, e),
              );
            },
          );
        },
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FoodReviewScreen(
        uid: target.uid,
        entry: target.draft(picked.title, picked.items, picked.source),
        isNew: true,
      ),
    ),
  );
}

/// Shows progress while the photo or description is analyzed, then hands the
/// result to [FoodReviewScreen] for the user to confirm or correct.
class AnalyzeScreen extends StatefulWidget {
  final LogTarget target;
  final Uint8List? image;
  final String mimeType;
  final String? description;

  const AnalyzeScreen({
    super.key,
    required this.target,
    this.image,
    this.mimeType = 'image/jpeg',
    this.description,
  });

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  String? _error;
  bool _quota = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    }
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _quota = false;
    });
    final analyzer = Services.of(context).analyzer;
    try {
      final result = widget.image != null
          ? await analyzer.analyzeImage(widget.image!, widget.mimeType)
          : await analyzer.analyzeText(widget.description!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => FoodReviewScreen(
            uid: widget.target.uid,
            entry: widget.target.draft(
              result.title,
              result.items,
              widget.image != null ? 'photo' : 'text',
            ),
            isNew: true,
            notes: result.notes,
            image: widget.image,
            mimeType: widget.mimeType,
            description: widget.description,
            analysis: result,
            research: widget.target.research,
          ),
        ),
      );
    } on AnalysisFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _quota = e.quotaExceeded;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: widget.image != null
                    ? ScanFrame(
                        scanning: _error == null,
                        child: Image.memory(widget.image!, fit: BoxFit.cover),
                      )
                    : Panel(
                        child: Center(
                          child: Text(
                            '“${widget.description}”',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              if (_error == null) ...[
                const LinearProgressIndicator(minHeight: 6),
                const SizedBox(height: 16),
                Text(
                  'Analyzing your meal…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const _AnalyzeSteps(),
                const SizedBox(height: 24),
              ] else ...[
                Text(
                  'Could not analyze this meal',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                if (_quota) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      if (await showKeySheet(context) && mounted) _run();
                    },
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Use my own Gemini key'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _run,
                    child: const Text('Try again'),
                  ),
                ] else
                  FilledButton(onPressed: _run, child: const Text('Try again')),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => FoodReviewScreen(
                        uid: widget.target.uid,
                        entry: widget.target.draft('', const [], 'manual'),
                        isNew: true,
                      ),
                    ),
                  ),
                  child: const Text('Add manually instead'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirm, correct or build a meal: used for AI results, manual entry and
/// editing something already logged.
class FoodReviewScreen extends StatefulWidget {
  final String uid;
  final FoodEntry entry;
  final bool isNew;
  final String notes;
  final Uint8List? image;
  final String mimeType;
  final String? description;

  /// Set when this meal came from an analysis, so the result and the user's
  /// corrections can be kept for research if [research] is on.
  final AnalysisResult? analysis;
  final bool research;

  const FoodReviewScreen({
    super.key,
    required this.uid,
    required this.entry,
    required this.isNew,
    this.notes = '',
    this.image,
    this.mimeType = 'image/jpeg',
    this.description,
    this.analysis,
    this.research = false,
  });

  @override
  State<FoodReviewScreen> createState() => _FoodReviewScreenState();
}

class _FoodReviewScreenState extends State<FoodReviewScreen> {
  late final _title = TextEditingController(text: widget.entry.title);
  late List<FoodItem> _items = [...widget.entry.items];
  late MealType _meal = widget.entry.meal;
  bool _saving = false;

  FoodEntry get _entry => widget.entry.copyWith(
    title: _title.text.trim().isEmpty
        ? (_items.isEmpty ? 'Meal' : _items.first.name)
        : _title.text.trim(),
    meal: _meal,
    items: _items,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isNew && _items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _editItem(null));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _editItem(int? index) async {
    final result = await showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemEditor(item: index == null ? null : _items[index]),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _items = [..._items, result];
      } else {
        _items = [..._items]..[index] = result;
      }
    });
  }

  void _setQuantity(int index, double quantity) {
    if (quantity < 0.25 || quantity > 20) return;
    setState(
      () =>
          _items = [..._items]
            ..[index] = _items[index].copyWith(quantity: quantity),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final services = Services.of(context);
      final entry = _entry;
      await services.repo.saveFood(widget.uid, entry);
      if (widget.research && widget.analysis != null) {
        // Runs in the background; it reports its own errors.
        services.research.save(
          widget.uid,
          ResearchSample(
            logged: entry,
            analysis: widget.analysis!,
            image: widget.image,
            mimeType: widget.mimeType,
            description: widget.description,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, 'Could not save. $e');
      }
    }
  }

  Future<void> _delete() async {
    final repo = Services.of(context).repo;
    final navigator = Navigator.of(context);
    await repo.deleteFood(widget.uid, widget.entry.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew
              ? (widget.entry.source == 'manual' ? 'Add food' : 'Review meal')
              : 'Edit meal',
        ),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: 'Delete meal',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (widget.image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(widget.image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.notes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.notes}\nThese are estimates. Tap any item '
                      'to correct it.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Meal name'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final m in MealType.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: _meal == m,
                  onSelected: (_) => setState(() => _meal = m),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatNumber(entry.calories),
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'kcal',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    MacroChip('Protein', entry.protein, AppColors.protein),
                    MacroChip('Carbs', entry.carbs, AppColors.carbs),
                    MacroChip('Fat', entry.fat, AppColors.fat),
                    MacroChip('Fiber', entry.fiber, scheme.primary),
                    MacroChip('Sugar', entry.sugar, scheme.onSurfaceVariant),
                  ],
                ),
                if (entry.sodiumMg > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Sodium ${entry.sodiumMg.round()} mg',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Items', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No items yet. Add the first one below.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                onTap: () => _editItem(i),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _items[i].name,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                _items[i].portion,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_items[i].totalCalories.round()} kcal',
                          style: theme.textTheme.titleMedium,
                        ),
                        IconButton(
                          tooltip: 'Remove ${_items[i].name}',
                          onPressed: () =>
                              setState(() => _items = [..._items]..removeAt(i)),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 12,
                            children: [
                              MacroChip(
                                'P',
                                _items[i].totalProtein,
                                AppColors.protein,
                              ),
                              MacroChip(
                                'C',
                                _items[i].totalCarbs,
                                AppColors.carbs,
                              ),
                              MacroChip('F', _items[i].totalFat, AppColors.fat),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Less',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _setQuantity(i, _items[i].quantity - 0.25),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${_trim(_items[i].quantity)}×',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'More',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _setQuantity(i, _items[i].quantity + 0.25),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _editItem(null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _items.isEmpty || _saving ? null : _save,
            child: Text(widget.isNew ? 'Log meal' : 'Save changes'),
          ),
        ),
      ),
    );
  }
}

String _trim(double v) => v == v.roundToDouble()
    ? v.round().toString()
    : v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

class _ItemEditor extends StatefulWidget {
  final FoodItem? item;
  const _ItemEditor({this.item});

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _portion = TextEditingController(
    text: widget.item?.portion ?? '1 serving',
  );
  late final _numbers = {
    for (final (key, value) in [
      ('Calories (kcal)', widget.item?.calories),
      ('Protein (g)', widget.item?.protein),
      ('Carbs (g)', widget.item?.carbs),
      ('Fat (g)', widget.item?.fat),
      ('Fiber (g)', widget.item?.fiber),
      ('Sugar (g)', widget.item?.sugar),
      ('Sodium (mg)', widget.item?.sodiumMg),
    ])
      key: TextEditingController(
        text: value == null || value == 0 ? '' : _trim(value),
      ),
  };

  @override
  void dispose() {
    _name.dispose();
    _portion.dispose();
    for (final c in _numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _value(String key) =>
      double.tryParse(_numbers[key]!.text.replaceAll(',', '.')) ?? 0;

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      FoodItem(
        name: _name.text.trim(),
        portion: _portion.text.trim().isEmpty
            ? '1 serving'
            : _portion.text.trim(),
        quantity: widget.item?.quantity ?? 1,
        calories: _value('Calories (kcal)'),
        protein: _value('Protein (g)'),
        carbs: _value('Carbs (g)'),
        fat: _value('Fat (g)'),
        fiber: _value('Fiber (g)'),
        sugar: _value('Sugar (g)'),
        sodiumMg: _value('Sodium (mg)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget number(String key, {bool required = false}) => TextFormField(
      controller: _numbers[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: key),
      validator: required
          ? (v) => (double.tryParse((v ?? '').replaceAll(',', '.')) ?? -1) >= 0
                ? null
                : 'Required'
          : null,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item == null ? 'Add item' : 'Edit item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: widget.item == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Food name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portion,
                decoration: const InputDecoration(
                  labelText: 'Portion',
                  hintText: 'e.g. 1 bowl, 200 g',
                ),
              ),
              const SizedBox(height: 12),
              number('Calories (kcal)', required: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: number('Protein (g)')),
                  const SizedBox(width: 10),
                  Expanded(child: number('Carbs (g)')),
                  const SizedBox(width: 10),
                  Expanded(child: number('Fat (g)')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: number('Fiber (g)')),
                  const SizedBox(width: 10),
                  Expanded(child: number('Sugar (g)')),
                  const SizedBox(width: 10),
                  Expanded(child: number('Sodium (mg)')),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.item == null ? 'Add' : 'Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the user add, replace or remove their own Gemini API key.
/// Returns true when a working key is saved.
Future<bool> showKeySheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _KeySheet(),
  );
  return saved ?? false;
}

class _KeySheet extends StatefulWidget {
  const _KeySheet();

  @override
  State<_KeySheet> createState() => _KeySheetState();
}

class _KeySheetState extends State<_KeySheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.length < 20) {
      setState(() => _error = 'That does not look like a full key.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final keys = Services.of(context).keys;
    final problem = await OwnKeyFoodAnalyzer.check(key);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _busy = false;
        _error = problem;
      });
      return;
    }
    try {
      await keys.write(key);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not store the key on this device. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keys = Services.of(context).keys;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your own Gemini key', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'With your own key, food analysis runs on your personal Google '
            'allowance instead of the shared one. Get a free key at:',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          SelectableText(
            'aistudio.google.com/apikey',
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            'The key is stored only on this device and sent only to Google.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Gemini API key',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Check and save key'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: keys.hasKey,
            builder: (context, has, _) => has
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              await keys.clear();
                              navigator.pop(false);
                            },
                      child: const Text('Remove saved key'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Cycles through what the analysis is doing, so the wait feels alive.
class _AnalyzeSteps extends StatelessWidget {
  const _AnalyzeSteps();

  static const _steps = [
    'Identifying the foods',
    'Estimating portions',
    'Working out calories and macros',
  ];

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(milliseconds: 1600), (i) => i + 1),
      initialData: 0,
      builder: (context, snap) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          _steps[snap.data! % _steps.length],
          key: ValueKey(snap.data! % _steps.length),
          textAlign: TextAlign.center,
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}
