import 'package:flutter/material.dart';
import '../../../core/constants/academic_levels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../users/models/user.dart';
import '../viewmodels/group_viewmodel.dart';
import '../widgets/ai_description_sheet.dart';

/// Page 2: Creation of a new group.
class CreateGroupPage extends StatefulWidget {
  final GroupViewModel viewModel;

  const CreateGroupPage({
    super.key,
    required this.viewModel,
  });

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedLevel = 'Licence 3';
  bool _isPublic = true;
  double _maxMembers = 10;
  final Set<User> _selectedMembers = {};
  bool _isSubmitting = false;

  final List<String> _levels = AcademicLevels.all;

  @override
  void initState() {
    super.initState();
    // Le créateur fait automatiquement partie des membres dès l'initialisation
    final currentId = widget.viewModel.currentUserId;
    try {
      final current =
          widget.viewModel.allUsers.firstWhere((u) => u.id == currentId);
      _selectedMembers.add(current);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableUsers = widget.viewModel.allUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un nouveau groupe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Informations du groupe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              const SizedBox(height: 16),

              // Nom du groupe
              TextFormField(
                controller: _nameController,
                maxLength: 50,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nom du groupe *',
                  hintText: 'ex: Spring Boot Masters',
                  prefixIcon: Icon(Icons.group, color: AppColors.muted),
                ),
                validator: FormValidators.validateGroupName,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descController,
                maxLength: 300,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Décrivez brièvement les objectifs et sujets du groupe (min. 10 caractères)...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.description, color: AppColors.muted),
                  ),
                ),
                validator: FormValidators.validateGroupDescription,
              ),
              const SizedBox(height: 8),
              AiAssistButton(onPressed: _openAiAssistant),
              const SizedBox(height: 20),

              // Niveau / Filière
              const Text(
                'Niveau d\'études *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _levels.map((level) {
                  final selected = _selectedLevel == level;
                  return AppChip(
                    level,
                    selected: selected,
                    onTap: () => setState(() => _selectedLevel = level),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Visibilité & Capacité
              AppCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Groupe Public',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _isPublic
                            ? 'Tout étudiant peut voir et rejoindre le groupe.'
                            : 'Le groupe sera accessible sur invitation seulement.',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      value: _isPublic,
                      onChanged: (val) => setState(() => _isPublic = val),
                    ),
                    const Divider(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Nombre max de membres',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AppBadge(
                              '${_maxMembers.toInt()} max',
                              type: AppBadgeType.primary,
                            ),
                          ],
                        ),
                        Slider(
                          value: _maxMembers,
                          min: 2,
                          max: 20,
                          divisions: 18,
                          label: '${_maxMembers.toInt()}',
                          onChanged: (val) {
                            setState(() => _maxMembers = val);
                          },
                        ),
                        if (_selectedMembers.length > _maxMembers.toInt())
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 16, color: AppColors.danger),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Attention : ${_selectedMembers.length} membres sélectionnés pour une capacité de ${_maxMembers.toInt()}.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Membres fictifs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Membres initiaux',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '${_selectedMembers.length}/${_maxMembers.toInt()} sélectionné(s)',
                    style: TextStyle(
                      fontSize: 13,
                      color: _selectedMembers.length > _maxMembers.toInt()
                          ? AppColors.danger
                          : AppColors.muted,
                      fontWeight: _selectedMembers.length > _maxMembers.toInt()
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: availableUsers.map((user) {
                    final isChecked = _selectedMembers.contains(user);
                    final isCreator = user.id == widget.viewModel.currentUserId;

                    return CheckboxListTile(
                      value: isChecked,
                      onChanged: (bool? checked) {
                        if (isCreator) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.muted,
                              duration: Duration(seconds: 2),
                              content: Text(
                                'En tant que créateur, vous faites automatiquement partie du groupe.',
                              ),
                            ),
                          );
                          return;
                        }

                        if (checked == true) {
                          if (_selectedMembers.length >= _maxMembers.toInt()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.danger,
                                duration: const Duration(seconds: 2),
                                content: Text(
                                  'Capacité maximale atteinte (${_maxMembers.toInt()} membres). '
                                  'Augmentez la capacité pour en ajouter davantage.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _selectedMembers.add(user));
                        } else {
                          setState(() => _selectedMembers.remove(user));
                        }
                      },
                      secondary: CircleAvatar(
                        backgroundColor: user.avatarColor,
                        radius: 18,
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isCreator)
                            const AppBadge('Créateur', type: AppBadgeType.primary),
                        ],
                      ),
                      subtitle: Text(
                        user.role,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Créer le groupe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _openAiAssistant() async {
    FocusScope.of(context).unfocus();
    final suggestion = await showAiDescriptionSheet(
      context,
      groupName: _nameController.text,
      level: _selectedLevel,
      isPublic: _isPublic,
      currentDescription: _descController.text,
    );
    if (suggestion == null || !mounted) return;
    setState(() {
      _descController.text = suggestion;
      _descController.selection =
          TextSelection.collapsed(offset: suggestion.length);
    });
  }

  Future<void> _submitForm() async {
    final name = _nameController.text.trim();
    final description = _descController.text.trim();

    // 1. Contrôle direct des champs obligatoires avec remontée en haut de page
    final nameError = FormValidators.validateGroupName(name);
    if (nameError != null) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(nameError),
        ),
      );
      _formKey.currentState?.validate();
      return;
    }

    final descError = FormValidators.validateGroupDescription(description);
    if (descError != null) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(descError),
        ),
      );
      _formKey.currentState?.validate();
      return;
    }

    // 2. Validation globale du formulaire
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    // 3. Validation du niveau d'études
    final levelError = FormValidators.validateLevel(_selectedLevel, _levels);
    if (levelError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(levelError),
        ),
      );
      return;
    }

    // 4. Validation des membres (au moins 1 membre)
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Le groupe doit comporter au moins 1 membre.'),
        ),
      );
      return;
    }

    // 5. Validation de la capacité vs membres sélectionnés
    final capacityError = FormValidators.validateCapacity(
      maxMembers: _maxMembers.toInt(),
      selectedCount: _selectedMembers.length,
    );
    if (capacityError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(capacityError),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final success = await widget.viewModel.createGroup(
        name: name,
        description: description,
        level: _selectedLevel,
        isPublic: _isPublic,
        maxMembers: _maxMembers.toInt(),
        selectedMembers: _selectedMembers.toList(),
      );

      if (!mounted) return;

      if (success) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Groupe « $name » créé avec succès !'),
          ),
        );
        navigator.pop();
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(
              widget.viewModel.errorMessage ??
                  'Erreur lors de la création du groupe.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
