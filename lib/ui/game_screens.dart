part of 'finni_app.dart';

extension _RemainingScreens on _GameShellState {
  List<Widget> tasksPage(GameState state) => [
    heading('Давай поиграем!'),
    const ResourceText('Учебные задания. Покупки и копилка не меняются.'),
    for (final task in state.taskHub.tasks)
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResourceText(
              task.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ResourceText(
              task.completed
                  ? 'Выполнено · награда получена'
                  : 'Награда ${task.rewardAmount} монет',
            ),
            if (task.unavailableReason != null)
              ResourceText(task.unavailableReason!),
            button(
              task.completed ? 'Посмотреть задание' : 'Открыть задание',
              () {
                selectedTask = task.id;
                taskDraft = TaskDraft();
                taskDefinition = widget.service.getTaskDefinition(
                  state.profile.id,
                  task.id,
                );
                navigate(_Page.task);
              },
            ),
          ],
        ),
      ),
  ];

  List<Widget> taskPage(GameState state) => [
    FutureBuilder<TaskDefinitionResult>(
      future: taskDefinition,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError ||
            snapshot.data?.definition == null ||
            snapshot.data?.errorCode != null) {
          return Column(
            children: [
              const ResourceText('Задание не удалось открыть.'),
              button('Повторить загрузку задания', () {
                update(
                  () => taskDefinition = widget.service.getTaskDefinition(
                    state.profile.id,
                    selectedTask!,
                  ),
                );
              }),
            ],
          );
        }
        final task = state.taskHub.tasks
            .where((t) => t.id == selectedTask)
            .firstOrNull;
        if (task == null) {
          return const ResourceText(
            'Задание больше недоступно. Вернись к списку.',
          );
        }
        return TaskPanel(
          key: ValueKey(
            '${state.profile.id}-${state.profile.generation}-${task.id}',
          ),
          definition: snapshot.data!.definition!,
          draft: taskDraft,
          status: task,
          blocked: blocked,
          onSubmit: (answer) async {
            final current = game.state!;
            final command = TaskAnswerCommand(
              profileId: current.profile.id,
              expectedGeneration: current.profile.generation,
              expectedRevision: current.stateRevision,
              actionId: game.newActionId(),
              taskId: task.id,
              answer: answer,
            );
            await showResult(
              await game.execute(
                () => widget.service.submitTaskAnswer(command),
              ),
            );
          },
        );
      },
    ),
    button('К списку заданий', () => navigate(_Page.tasks), secondary: true),
  ];

  Future<void> periodAction(GameState state, {required bool finish}) async {
    final query = PeriodQuery(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      periodId: state.currentPeriod.id,
    );
    PeriodCommand command(String id, Set<WarningCode> warnings) =>
        PeriodCommand(
          profileId: query.profileId,
          expectedGeneration: query.expectedGeneration,
          expectedRevision: query.expectedRevision,
          periodId: query.periodId,
          actionId: id,
          acceptedWarnings: warnings,
        );
    if (finish) {
      await confirm(
        () => widget.service.previewFinishPeriod(query),
        (warnings, id) => widget.service.finishPeriod(command(id, warnings)),
      );
    } else {
      final cmd = command(game.newActionId(), {});
      await showResult(
        await game.execute(() => widget.service.startNextPeriod(cmd)),
      );
      if (mounted && game.state?.currentPeriod.status == PeriodStatus.open) {
        needs.clear();
        wants.clear();
        savings.clear();
        navigate(_Page.budget);
      }
    }
  }

  List<Widget> periodPage(GameState state) => [
    heading('Итог периода ${state.currentPeriod.number}'),
    coins(state),
    if (state.currentPeriod.status == PeriodStatus.open) ...[
      if (state.currentPeriod.budgetPlan case final plan?)
        planFactCard(plan, state.currentPeriod.actual)
      else
        ...budget(state).skip(2),
      button('Завершить период', () => periodAction(state, finish: true)),
    ] else ...[
      if (lastSummary?.periodId == state.currentPeriod.id)
        periodSummaryCard(lastSummary!),
      ResourceText(
        'Завершено: ${state.learningProgress.completedPeriods} · баллы заботы: ${state.learningProgress.qualityPoints}',
      ),
      if (state.currentPeriod.status == PeriodStatus.closed)
        button(
          'Начать следующий период',
          () => periodAction(state, finish: false),
        )
      else
        const ResourceText(
          'Пять периодов завершены! Посмотри, чему вы научились вместе.',
        ),
    ],
    button(
      'Посмотреть историю',
      () => navigate(_Page.history),
      secondary: true,
    ),
  ];

  Future<void> redeem(GameState state) async {
    final goal = state.activeGoal;
    if (goal == null) {
      return;
    }
    final query = GoalQuery(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      goalId: goal.goalId,
    );
    final applied = await confirm(
      () => widget.service.previewGoalRedemption(query),
      (warnings, id) => widget.service.redeemGoal(
        GoalCommand(
          profileId: query.profileId,
          expectedGeneration: query.expectedGeneration,
          expectedRevision: query.expectedRevision,
          actionId: id,
          goalId: query.goalId,
          acceptedWarnings: warnings,
        ),
      ),
    );
    if (mounted && applied) {
      navigate(_Page.savings);
    }
  }

  List<Widget> adultPage(GameState state) {
    if (!adultUnlocked) {
      return [
        heading('Взрослому'),
        const ResourceText('Попроси взрослого помочь. Сколько будет 8 + 7?'),
        number('Ответ взрослого', adultAnswer),
        button('Войти во взрослый раздел', () {
          if (adultAnswer.text.trim() != '15') {
            update(
              () => inputError = 'Проверь ответ или попроси взрослого помочь.',
            );
            return;
          }
          update(() {
            adultUnlocked = true;
            inputError = null;
            adultAnswer.clear();
          });
        }),
        const ResourceText(
          'Это защита от случайного нажатия, а не проверка личности.',
        ),
      ];
    }
    return [
      heading('Играем и обсуждаем'),
      ResourceText(
        'Профиль: ${state.pet.name} · ${state.profile.mode == ProfileMode.demo ? 'демо' : 'обычная игра'}',
      ),
      ResourceText(
        'Периодов: ${state.learningProgress.completedPeriods} · заданий: ${state.taskHub.tasks.where((t) => t.completed).length}/6',
      ),
      const ResourceText(
        'Обсудите: что было нужным, что можно отложить и как получилась мечта. Прогресс не является оценкой ребёнка.',
      ),
      for (final theme in TaskTheme.values)
        ResourceText(
          '${switch (theme) {
            TaskTheme.budget => 'Бюджет',
            TaskTheme.savings => 'Накопления',
            TaskTheme.paymentsAndPurchases => 'Покупки',
          }}: ${state.taskHub.tasks.where((t) => t.theme == theme && t.completed).length}/${state.taskHub.tasks.where((t) => t.theme == theme).length}',
        ),
      button('Настройки', () => navigate(_Page.settings)),
      button('История решений', () => navigate(_Page.history), secondary: true),
      button('Выбрать другой профиль', () async {
        game.leaveProfile();
        navigate(_Page.home);
        await game.initialize();
      }, secondary: true),
      if (state.profile.mode == ProfileMode.demo)
        button(
          'Сбросить демо',
          () => destructive(state, reset: true),
          secondary: true,
        ),
      button(
        'Удалить профиль',
        () => destructive(state, reset: false),
        secondary: true,
      ),
    ];
  }

  Future<void> destructive(GameState state, {required bool reset}) async {
    if (!adultUnlocked) {
      return;
    }
    final requiredText = reset
        ? resetDemoConfirmationText
        : deleteProfileConfirmationText;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => ProfileConfirmationDialog(
        name: state.pet.name,
        reset: reset,
        requiredText: requiredText,
      ),
    );
    if (!mounted || accepted != true) {
      return;
    }
    final cmd = ConfirmedProfileCommand(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      actionId: game.newActionId(),
      confirmationText: requiredText,
    );
    await showResult(
      await game.execute(
        () => reset
            ? widget.service.resetDemoProfile(cmd)
            : widget.service.deleteProfile(cmd),
        deletesProfile: !reset,
      ),
    );
  }

  List<Widget> settingsPage(GameState state) {
    Widget toggle(
      String label,
      bool value,
      ProfileSettings Function(bool) settings,
    ) => SwitchListTile(
      title: ResourceText(label),
      value: value,
      onChanged: blocked
          ? null
          : (v) async {
              final cmd = UpdateSettingsCommand(
                profileId: state.profile.id,
                expectedGeneration: state.profile.generation,
                expectedRevision: state.stateRevision,
                actionId: game.newActionId(),
                settings: settings(v),
              );
              await showResult(
                await game.execute(() => widget.service.updateSettings(cmd)),
              );
            },
    );
    final s = state.settings;
    return [
      heading('Настройки'),
      toggle(
        'Звуки',
        s.soundEnabled,
        (v) => ProfileSettings(
          soundEnabled: v,
          reducedMotion: s.reducedMotion,
          largeTextPreferred: s.largeTextPreferred,
        ),
      ),
      toggle(
        'Меньше анимации',
        s.reducedMotion,
        (v) => ProfileSettings(
          soundEnabled: s.soundEnabled,
          reducedMotion: v,
          largeTextPreferred: s.largeTextPreferred,
        ),
      ),
      toggle(
        'Крупный текст',
        s.largeTextPreferred,
        (v) => ProfileSettings(
          soundEnabled: s.soundEnabled,
          reducedMotion: s.reducedMotion,
          largeTextPreferred: v,
        ),
      ),
      const ResourceText(
        'Настройки сохраняются для этого питомца. Системное увеличение текста также учитывается.',
      ),
    ];
  }
}
