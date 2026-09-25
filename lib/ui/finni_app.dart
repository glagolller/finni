import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contracts/contracts.dart';
import 'game_controller.dart';
import 'pet_avatar.dart';

class FinniApp extends StatelessWidget {
  const FinniApp({super.key, this.service, this.previewMode = false});
  final LogicService? service;
  final bool previewMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Питомец Финни',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6851a5)),
      scaffoldBackgroundColor: const Color(0xfffff2d9),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontFamily: 'Pangolin',
          fontSize: 27,
          color: Color(0xff38295c),
        ),
        titleLarge: TextStyle(
          fontFamily: 'Pangolin',
          fontSize: 24,
          color: Color(0xff38295c),
        ),
      ),
      cardTheme: const CardThemeData(color: Color(0xffe5f4ec)),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xffe9defb),
        indicatorColor: Color(0xffcbb5f0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xffffe4ac),
        titleTextStyle: TextStyle(
          fontFamily: 'Pangolin',
          fontSize: 25,
          color: Color(0xff38295c),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: service == null
        ? const Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Интерфейс подготовлен. Игровой сервис ещё не подключён.\n'
                    'Тестовый просмотр запускается отдельно через main_preview.dart.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          )
        : _GameShell(service: service!, previewMode: previewMode),
  );
}

enum _Page { home, budget, shop, savings, tasks, progress, help }

class _GameShell extends StatefulWidget {
  const _GameShell({required this.service, required this.previewMode});
  final LogicService service;
  final bool previewMode;
  @override
  State<_GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<_GameShell> {
  late final GameController game;
  _Page page = _Page.home;
  String? formId;
  String? paletteId;
  ProfileMode mode = ProfileMode.normal;
  final name = TextEditingController(text: 'Финни');
  final needs = TextEditingController();
  final wants = TextEditingController();
  final savings = TextEditingController();
  final amount = TextEditingController();
  String? inputError;
  Future<CatalogResult<ItemSummary>>? items;
  Future<CatalogResult<GoalSummary>>? goals;

  @override
  void initState() {
    super.initState();
    game = GameController(widget.service)..initialize();
  }

  @override
  void dispose() {
    game.dispose();
    for (final controller in [name, needs, wants, savings, amount]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get blocked => game.busy || game.canRetry;

  void navigate(_Page target) {
    setState(() {
      page = target;
      inputError = null;
      final state = game.state;
      if (target == _Page.shop && state != null) {
        items = widget.service.getItemCatalog(state.profile.id);
      }
      if (target == _Page.savings && state != null) {
        goals = widget.service.getGoalCatalog(state.profile.id);
      }
    });
  }

  Widget button(String text, VoidCallback? action, {bool secondary = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          child: secondary
              ? OutlinedButton(
                  onPressed: blocked ? null : action,
                  child: Text(text),
                )
              : FilledButton(
                  onPressed: blocked ? null : action,
                  child: Text(text),
                ),
        ),
      );

  Widget card(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
  );

  Widget metric(IconData icon, Color color, String label, String value) =>
      Semantics(
        label: '$label: $value',
        child: Tooltip(
          message: label,
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 25),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(value, style: const TextStyle(fontSize: 19)),
                ),
              ],
            ),
          ),
        ),
      );

  Widget coins(GameState state) {
    Widget balance(String label, IconData icon, Color color, int value) => card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label), metric(icon, color, label, '$value')],
      ),
    );
    final available = balance(
      'Можно потратить',
      Icons.monetization_on,
      const Color(0xffa66b00),
      state.availableBalance,
    );
    final saved = balance(
      'В копилке',
      Icons.savings,
      const Color(0xffac396b),
      state.savingsBalance,
    );
    if (MediaQuery.textScalerOf(context).scale(16) > 23) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [available, saved],
      );
    }
    return Row(
      children: [
        Expanded(child: available),
        Expanded(child: saved),
      ],
    );
  }

  Widget number(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: controller,
      enabled: !blocked,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: game,
    builder: (context, _) {
      final state = game.state;
      return PopScope(
        canPop: page == _Page.home,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) navigate(_Page.home);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Питомец Финни'),
            leading: page == _Page.home
                ? null
                : IconButton(
                    tooltip: 'На главный экран',
                    onPressed: () => navigate(_Page.home),
                    icon: const Icon(Icons.arrow_back),
                  ),
            actions: [
              IconButton(
                tooltip: 'Справка',
                onPressed: () => navigate(_Page.help),
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (widget.previewMode)
                  const MaterialBanner(
                    content: Text('Тестовый UI · данные не сохраняются'),
                    actions: [Text('ПРОСМОТР')],
                  ),
                if (game.busy)
                  const LinearProgressIndicator(semanticsLabel: 'Загружаем'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (game.error != null)
                        card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.error!,
                                semanticsLabel: 'Ошибка: ${game.error}',
                              ),
                              TextButton(
                                onPressed: game.busy
                                    ? null
                                    : () async {
                                        if (game.canRetry) {
                                          await showResult(
                                            await game.retryLast(),
                                          );
                                        } else {
                                          await game.initialize();
                                        }
                                      },
                                child: Text(
                                  game.canRetry
                                      ? 'Повторить действие'
                                      : 'Повторить загрузку',
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (inputError != null)
                        Text(
                          inputError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (page == _Page.help)
                        ...help()
                      else if (state == null)
                        ...welcome()
                      else
                        ...content(state),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: state == null
              ? null
              : NavigationBar(
                  height: MediaQuery.textScalerOf(context).scale(16) > 23
                      ? 110
                      : 80,
                  selectedIndex: switch (page) {
                    _Page.shop => 1,
                    _Page.savings => 2,
                    _Page.tasks => 3,
                    _ => 0,
                  },
                  onDestinationSelected: (i) => navigate(
                    [_Page.home, _Page.shop, _Page.savings, _Page.tasks][i],
                  ),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined, color: Color(0xff416ea5)),
                      label: 'Дом',
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xffb65432),
                      ),
                      label: 'Покупки',
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.savings_outlined,
                        color: Color(0xffa43e79),
                      ),
                      label: 'Копилка',
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.school_outlined,
                        color: Color(0xff36734f),
                      ),
                      label: 'Задания',
                    ),
                  ],
                ),
        ),
      );
    },
  );

  List<Widget> welcome() {
    final config = game.bootstrap;
    if (config == null) return [const Text('Подготавливаем игру…')];
    final form = formId ?? config.petForms.first.id;
    final palette = paletteId ?? config.petPalettes.first.id;
    return [
      heading('Знакомься, Финни!'),
      const Text(
        'Планируй монеты, выбирай нужное и копи на мечту. Здесь только игровые деньги.',
      ),
      for (final profile in game.profiles)
        button(
          'Продолжить: ${profile.petName} · ${profile.mode == ProfileMode.demo ? 'демо' : 'игра'}',
          () => game.openProfile(profile.id),
        ),
      heading('Создать питомца'),
      TextField(
        controller: name,
        maxLength: 20,
        enabled: !blocked,
        decoration: const InputDecoration(
          labelText: 'Игровое имя',
          helperText: 'Настоящее имя не нужно',
        ),
      ),
      Center(
        child: PetAvatar(formId: form, paletteId: palette),
      ),
      const Text('Форма'),
      Wrap(
        spacing: 8,
        children: [
          for (final option in config.petForms)
            ChoiceChip(
              label: Text(option.label),
              selected: form == option.id,
              onSelected: blocked
                  ? null
                  : (_) => setState(() => formId = option.id),
            ),
        ],
      ),
      const Text('Окраска и узор'),
      Wrap(
        spacing: 8,
        children: [
          for (final option in config.petPalettes)
            ChoiceChip(
              label: Text(option.label),
              selected: palette == option.id,
              onSelected: blocked
                  ? null
                  : (_) => setState(() => paletteId = option.id),
            ),
        ],
      ),
      SwitchListTile(
        title: const Text('Демо: пять периодов'),
        value: mode == ProfileMode.demo,
        onChanged: blocked
            ? null
            : (v) => setState(
                () => mode = v ? ProfileMode.demo : ProfileMode.normal,
              ),
      ),
      button('Начать дружбу', () async {
        final value = name.text.trim();
        if (value.isEmpty) {
          setState(() => inputError = 'Придумай имя питомца.');
          return;
        }
        final command = CreateProfileCommand(
          actionId: game.newActionId(),
          mode: mode,
          petName: value,
          formId: form,
          paletteId: palette,
        );
        await showResult(
          await game.execute(() => widget.service.createProfile(command)),
        );
      }),
    ];
  }

  List<Widget> content(GameState state) => switch (page) {
    _Page.home => home(state),
    _Page.budget => budget(state),
    _Page.shop => [
      heading('Покупки'),
      coins(state),
      Text(
        'Покупок использовано: ${state.currentPeriod.purchaseSlotsUsed} из ${state.currentPeriod.purchaseSlotsTotal}',
      ),
      catalog<ItemSummary>(
        items,
        (item) => card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${item.price} монет · ${item.expenseType == ExpenseType.need ? 'Нужное' : 'Желание'}',
              ),
              Text(item.petEffect.explanationForChild),
              if (item.availabilityReason != null)
                Text(item.availabilityReason!),
              button(
                item.purchasedThisPeriod ? 'Уже куплено' : 'Посмотреть покупку',
                item.purchasedThisPeriod ||
                        !item.availableThisPeriod ||
                        state.currentPeriod.status != PeriodStatus.open
                    ? null
                    : () => purchase(state, item),
              ),
            ],
          ),
        ),
        () => navigate(_Page.shop),
      ),
    ],
    _Page.savings => savingsPage(state),
    _Page.tasks => [
      heading('Задания'),
      const Text(
        'Учебные симуляции. Выполнение заданий подключается следующим шагом.',
      ),
      for (final task in state.taskHub.tasks)
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title),
              Text(
                task.completed
                    ? 'Выполнено · повтор без награды'
                    : 'Награда ${task.rewardAmount} монет',
              ),
              if (task.unavailableReason != null) Text(task.unavailableReason!),
            ],
          ),
        ),
    ],
    _Page.progress => [
      heading('Как мы растём'),
      Text('Завершено периодов: ${state.learningProgress.completedPeriods}'),
      Text(
        'Выполнено заданий: ${state.taskHub.tasks.where((t) => t.completed).length} из ${state.taskHub.tasks.length}',
      ),
      const Text(
        'Рост зависит от серии решений: нужных покупок, соблюдения плана и накоплений.',
      ),
      for (final stage in state.learningProgress.stageHistory)
        card(
          Text(
            '${stageLabel(stage.stage)} · после периода ${stage.reachedAfterPeriod}',
          ),
        ),
    ],
    _Page.help => help(),
  };

  String stageLabel(PetStage stage) => switch (stage) {
    PetStage.baby => 'Малыш',
    PetStage.junior => 'Подросший',
    PetStage.grown => 'Взрослый',
  };

  List<Widget> home(GameState state) => [
    heading('Привет, ${state.pet.name}!'),
    Text(
      'Период ${state.currentPeriod.number}${state.profile.mode == ProfileMode.demo ? ' · демо' : ''}',
    ),
    coins(state),
    Row(
      children: [
        PetAvatar(
          formId: state.pet.formId,
          paletteId: state.pet.paletteId,
          stage: state.pet.stage,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stageLabel(state.pet.stage),
                style: const TextStyle(
                  fontFamily: 'Neucha',
                  fontSize: 23,
                  color: Color(0xff68428d),
                ),
              ),
              Text(switch (state.pet.moodCode) {
                MoodCode.happy => 'Радуется',
                MoodCode.calm => 'Спокоен',
                MoodCode.needsAttention => 'Нужна забота',
              }),
              metric(
                Icons.restaurant,
                const Color(0xffb95426),
                'Сытость',
                '${state.pet.satiety}/100',
              ),
              metric(
                Icons.sentiment_very_satisfied,
                const Color(0xff8e4dab),
                'Настроение',
                '${state.pet.mood}/100',
              ),
            ],
          ),
        ),
      ],
    ),
    goalCard(state),
    card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Следующее задание'),
          Text(
            state.taskHub.recommendedTask?.title ??
                'Посмотри выполненные задания',
          ),
          button('К заданиям', () => navigate(_Page.tasks)),
        ],
      ),
    ),
    button('Мой бюджет', () => navigate(_Page.budget)),
    button('Прогресс', () => navigate(_Page.progress), secondary: true),
    if (state.currentPeriod.status != PeriodStatus.open)
      Text(
        state.currentPeriod.status == PeriodStatus.demoCompleted
            ? 'Пять периодов завершены. Нового дохода в этом демо нет.'
            : 'Период закрыт.',
      ),
  ];

  Widget goalCard(GameState state) {
    final goal = state.activeGoal;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goal?.title ?? 'Выберем мечту?'),
          if (goal != null) ...[
            Text('${goal.savedAmount} из ${goal.targetAmount} монет'),
            LinearProgressIndicator(
              value: goal.targetAmount > 0
                  ? (goal.savedAmount / goal.targetAmount)
                        .clamp(0.0, 1.0)
                        .toDouble()
                  : 0,
              semanticsLabel:
                  'Накоплено ${goal.savedAmount} из ${goal.targetAmount}',
            ),
            Text('Осталось ${goal.remainingAmount} монет'),
          ] else
            button('Выбрать цель', () => navigate(_Page.savings)),
        ],
      ),
    );
  }

  List<Widget> budget(GameState state) {
    final plan = state.currentPeriod.budgetPlan;
    if (plan != null) {
      return [
        heading('Мой бюджет · план и факт'),
        const Text(
          'Подтверждённый план сохранён. Его можно сравнить с решениями.',
        ),
        card(
          Text(
            'Нужное: ${plan.needsLimit} / ${state.currentPeriod.actual.needsSpent}\n'
            'Желания: ${plan.wantsLimit} / ${state.currentPeriod.actual.wantsSpent}\n'
            'В копилку: ${plan.savingsTarget} / ${state.currentPeriod.actual.qualifyingSavings}',
          ),
        ),
        const Text(
          'Слева план, справа факт. Накопления — пополнения за вычетом обычных снятий.',
        ),
        coins(state),
      ];
    }
    return [
      heading('Мой бюджет'),
      coins(state),
      const Text(
        'Распредели монеты. План сам ничего не покупает и не переводит.',
      ),
      number('Нужное', needs),
      number('Желания', wants),
      number('В копилку', savings),
      button(
        'Посмотреть план',
        state.currentPeriod.status != PeriodStatus.open
            ? null
            : () async {
                final n = int.tryParse(needs.text),
                    w = int.tryParse(wants.text),
                    s = int.tryParse(savings.text);
                if (n == null || w == null || s == null) {
                  setState(
                    () => inputError = 'Заполни все три суммы целыми числами.',
                  );
                  return;
                }
                final query = BudgetQuery(
                  profileId: state.profile.id,
                  expectedGeneration: state.profile.generation,
                  expectedRevision: state.stateRevision,
                  needsLimit: n,
                  wantsLimit: w,
                  savingsTarget: s,
                );
                await confirm(
                  () => widget.service.previewBudget(query),
                  (accepted, id) => widget.service.confirmBudget(
                    BudgetCommand(
                      profileId: query.profileId,
                      expectedGeneration: query.expectedGeneration,
                      expectedRevision: query.expectedRevision,
                      actionId: id,
                      acceptedWarnings: accepted,
                      needsLimit: n,
                      wantsLimit: w,
                      savingsTarget: s,
                    ),
                  ),
                );
              },
      ),
    ];
  }

  Widget catalog<T>(
    Future<CatalogResult<T>>? future,
    Widget Function(T) render,
    VoidCallback retry,
  ) => FutureBuilder<CatalogResult<T>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError ||
          snapshot.data?.errorCode != null ||
          snapshot.data == null) {
        return card(
          Column(
            children: [
              const Text('Не удалось загрузить каталог.'),
              button('Повторить', retry),
            ],
          ),
        );
      }
      if (snapshot.data!.items.isEmpty) return const Text('Каталог пока пуст.');
      return Column(children: snapshot.data!.items.map(render).toList());
    },
  );

  Future<void> purchase(GameState state, ItemSummary item) async {
    final query = PurchaseQuery(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      itemId: item.id,
    );
    await confirm(
      () => widget.service.previewPurchase(query),
      (accepted, id) => widget.service.buyItem(
        PurchaseCommand(
          profileId: query.profileId,
          expectedGeneration: query.expectedGeneration,
          expectedRevision: query.expectedRevision,
          actionId: id,
          acceptedWarnings: accepted,
          itemId: item.id,
        ),
      ),
    );
    if (mounted) navigate(_Page.shop);
  }

  List<Widget> savingsPage(GameState state) => [
    heading('Копилка'),
    coins(state),
    goalCard(state),
    number('Сколько монет перевести?', amount),
    for (final direction in TransferDirection.values)
      button(
        direction == TransferDirection.toSavings
            ? 'Положить в копилку'
            : 'Взять из копилки',
        state.currentPeriod.status != PeriodStatus.open
            ? null
            : () async {
                final value = int.tryParse(amount.text);
                if (value == null || value <= 0) {
                  setState(() => inputError = 'Введи целое число больше нуля.');
                  return;
                }
                final query = SavingsTransferQuery(
                  profileId: state.profile.id,
                  expectedGeneration: state.profile.generation,
                  expectedRevision: state.stateRevision,
                  direction: direction,
                  amount: value,
                );
                await confirm(
                  () => widget.service.previewSavingsTransfer(query),
                  (accepted, id) => widget.service.transferSavings(
                    SavingsTransferCommand(
                      profileId: query.profileId,
                      expectedGeneration: query.expectedGeneration,
                      expectedRevision: query.expectedRevision,
                      actionId: id,
                      acceptedWarnings: accepted,
                      direction: direction,
                      amount: value,
                    ),
                  ),
                );
              },
        secondary: direction == TransferDirection.fromSavings,
      ),
    heading('Выбери мечту'),
    catalog<GoalSummary>(
      goals,
      (goal) => card(
        Column(
          children: [
            Text('${goal.title} · ${goal.targetAmount} монет'),
            button(
              goal.selected ? 'Выбрана' : 'Выбрать',
              goal.selected
                  ? null
                  : () async {
                      final query = GoalQuery(
                        profileId: state.profile.id,
                        expectedGeneration: state.profile.generation,
                        expectedRevision: state.stateRevision,
                        goalId: goal.id,
                      );
                      await confirm(
                        () => widget.service.previewGoalChange(query),
                        (accepted, id) => widget.service.changeGoal(
                          GoalCommand(
                            profileId: query.profileId,
                            expectedGeneration: query.expectedGeneration,
                            expectedRevision: query.expectedRevision,
                            actionId: id,
                            acceptedWarnings: accepted,
                            goalId: goal.id,
                          ),
                        ),
                      );
                      if (mounted) navigate(_Page.savings);
                    },
            ),
          ],
        ),
      ),
      () => navigate(_Page.savings),
    ),
  ];

  Future<void> confirm(
    Future<PreviewResult> Function() preview,
    Future<ActionResult> Function(Set<WarningCode>, String) action,
  ) async {
    final result = await game.preview(preview);
    if (!mounted || result == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.allowed ? 'Проверим действие' : 'Действие пока недоступно',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.messageForChild),
              if (result.expectedMoneyDelta case final delta?)
                Text(
                  'Изменение доступных монет: ${delta.availableChange}\nИзменение копилки: ${delta.savingsChange}',
                ),
              if (result.expectedPetDelta case final delta?)
                Text(delta.explanationForChild),
              for (final warning in result.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(warning.messageForChild),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          if (result.allowed)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Подтвердить'),
            ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    final warnings = result.warnings.map((w) => w.code).toSet();
    final id = game.newActionId();
    await showResult(await game.execute(() => action(warnings, id)));
  }

  Future<void> showResult(ActionResult? result) async {
    if (!mounted || result == null) return;
    if (!result.success) return; // The error panel provides the retry path.
    final message = result.outcome == ActionOutcome.replayed
        ? 'Действие уже было сохранено. Показаны актуальные данные.'
        : result.messageForChild;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Результат'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  List<Widget> help() => [
    heading('Подсказки'),
    card(const Text('Бюджет — план: сколько потратить и сколько отложить.')),
    card(
      const Text('Сначала нужное. Желания можно отложить на следующий период.'),
    ),
    card(
      const Text(
        'Накопления — монеты, оставленные на будущую цель. Перевод в копилку не является новым доходом.',
      ),
    ),
    card(
      const Text(
        'Ошибка — это опыт. Посмотри объяснение и попробуй другой выбор.',
      ),
    ),
  ];
}
