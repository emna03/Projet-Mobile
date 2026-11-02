import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sm_widgets.dart';
import '../../../core/utils/profile_photo.dart';
import '../../../core/services/biometric_service.dart';

import '../models/user.dart';
import '../repositories/user_repository.dart';

import 'EditProfileScreen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const scores = [
    ('Spring Boot', .82),
    ('Docker', .64),
    ('Microservices', .71),
    ('REST', .90),
  ];

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserRepository _userRepository = UserRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BiometricService _biometricService = BiometricService();

  AppUser? _user;
  bool _isLoadingProfile = true;

  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isUpdatingBiometric = false;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // ========================================
  // CHARGER LE PROFIL DEPUIS SQLITE
  // ========================================
  Future<void> _loadProfile() async {
    try {
      final email = _auth.currentUser?.email;

      if (email == null || email.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _user = null;
          _isLoadingProfile = false;
        });
      } else {
        final user = await _userRepository.getUserByEmail(email);
        if (!mounted) return;

        setState(() {
          _user = user;
          _isLoadingProfile = false;
        });

        if (user != null) {
          profilePhotoPath.value = user.photoPath;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
      _showMessage('Erreur de chargement du profil : $e');
    }

    // Toujours charger l'état biométrique, même si le profil a échoué.
    await _loadBiometricStatus();
  }

  // ========================================
  // CHARGER L'ÉTAT DE L'EMPREINTE
  // ========================================
  Future<void> _loadBiometricStatus() async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isBiometricAvailable = false;
        _isBiometricEnabled = false;
      });
      return;
    }

    try {
      final available = await _biometricService.isBiometricAvailable();
      final enabled = await _biometricService.isEnabledForAccount(uid);

      if (!mounted) return;
      setState(() {
        _isBiometricAvailable = available;
        _isBiometricEnabled = available && enabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBiometricAvailable = false;
        _isBiometricEnabled = false;
      });
    }
  }

  // ========================================
  // ACTIVER / DÉSACTIVER L'EMPREINTE
  // ========================================
  Future<void> _toggleBiometric(bool enable) async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      _showMessage('Impossible d’identifier le compte actuellement connecté.');
      return;
    }

    if (_isUpdatingBiometric) return;

    setState(() => _isUpdatingBiometric = true);

    try {
      if (enable) {
        final available = await _biometricService.isBiometricAvailable();

        if (!available) {
          _showMessage('Biométrie non supportée sur ce téléphone.');
          return;
        }

        // Vérification réelle : renvoie la vraie cause en cas d'échec.
        final result = await _biometricService.authenticateWithResult();

        if (!result.success) {
          _showMessage(result.message ?? 'Vérification échouée.');
          return;
        }

        await _biometricService.enableForAccount(uid);

        if (!mounted) return;
        setState(() {
          _isBiometricAvailable = true;
          _isBiometricEnabled = true;
        });

        _showMessage('Connexion par empreinte activée pour ce compte.');
      } else {
        await _biometricService.disableForAccount(uid);

        if (!mounted) return;
        setState(() => _isBiometricEnabled = false);

        _showMessage('Connexion par empreinte désactivée.');
      }
    } catch (e) {
      _showMessage('Erreur lors de la configuration de l’empreinte : $e');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingBiometric = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ========================================
  // RAFRAÎCHIR APRÈS MODIFICATION
  // ========================================
  Future<void> _editProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() => _isLoadingProfile = true);
      await _loadProfile();
    }
  }

  // ========================================
  // INTERFACE PRINCIPALE
  // ========================================
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        130 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _Reveal(index: 0, child: _buildHeader()),

        // JUSTIFICATIF ENSEIGNANT
        if (_user?.role == 'teacher') ...[
          const SizedBox(height: 20),
          _Reveal(index: 1, child: _buildTeacherDocument()),
        ],

        const SizedBox(height: 20),

        // STATISTIQUES
        _Reveal(
          index: 2,
          child: Row(
            children: const [
              _Mini(
                icon: LucideIcons.flame,
                color: SM.accent,
                value: 24,
                suffix: '',
                label: 'Jours de suite',
              ),
              SizedBox(width: 10),
              _Mini(
                icon: LucideIcons.trophy,
                color: SM.success,
                value: 8,
                suffix: '',
                label: 'Quiz réussis',
              ),
              SizedBox(width: 10),
              _Mini(
                icon: LucideIcons.clock,
                color: SM.primary,
                value: 14,
                suffix: ' h',
                label: 'Révisées',
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // SCORES
        _Reveal(
          index: 3,
          child: SMCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SM.primarySoft,
                        borderRadius: BorderRadius.circular(SM.rBadge),
                      ),
                      child: const Icon(
                        LucideIcons.chartColumn,
                        size: 18,
                        color: SM.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Score par matière', style: SM.h(17)),
                  ],
                ),
                const SizedBox(height: 18),
                for (final (i, (name, value)) in ProfileScreen.scores.indexed)
                  _buildScore(i, name, value),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // SÉCURITÉ : EMPREINTE DIGITALE
        _Reveal(index: 4, child: Text('Sécurité', style: SM.h(17))),

        const SizedBox(height: 12),

        _Reveal(index: 5, child: _buildBiometricCard()),

        const SizedBox(height: 28),

        // COMPTE
        _Reveal(index: 6, child: Text('Compte', style: SM.h(17))),

        const SizedBox(height: 12),

        _Reveal(
          index: 7,
          child: SMCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _ActionTile(
                  icon: LucideIcons.userPen,
                  color: SM.primary,
                  title: 'Modifier mon profil',
                  subtitle: 'Nom, filière, photo',
                  onTap: _editProfile,
                ),
                const Divider(
                  height: 1,
                  indent: 74,
                  endIndent: 16,
                  color: SM.primarySoft,
                ),
                _ActionTile(
                  icon: LucideIcons.logOut,
                  color: SM.danger,
                  title: 'Se déconnecter',
                  subtitle: 'Quitter ton compte',
                  danger: true,
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Center(child: Text('StudyMate', style: SM.b(12, color: SM.muted))),
      ],
    );
  }

  // ========================================
  // CARTE EMPREINTE
  // ========================================
  Widget _buildBiometricCard() {
    return SMCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: SM.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fingerprint, size: 27, color: SM.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connexion par empreinte',
                  style: SM.b(14, w: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  !_isBiometricAvailable
                      ? 'Biométrie non disponible sur cet appareil'
                      : _isBiometricEnabled
                          ? 'Activée pour ce compte'
                          : 'Désactivée',
                  style: SM.b(
                    12,
                    color: _isBiometricEnabled ? SM.success : SM.muted,
                  ),
                ),
              ],
            ),
          ),
          if (_isUpdatingBiometric)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: _isBiometricEnabled,
              activeTrackColor: SM.primary,
              onChanged: _isBiometricAvailable ? _toggleBiometric : null,
            ),
        ],
      ),
    );
  }

  // ========================================
  // JUSTIFICATIF ENSEIGNANT (IMGBB)
  // ========================================
  Widget _buildTeacherDocument() {
    final documentUrl = _user?.documentUrl;
    final hasDocument = documentUrl != null && documentUrl.trim().isNotEmpty;

    return SMCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SM.primarySoft,
                  borderRadius: BorderRadius.circular(SM.rBadge),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: SM.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Justificatif enseignant', style: SM.h(17)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasDocument)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SM.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 36,
                    color: SM.muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun justificatif disponible.',
                    style: SM.b(13, color: SM.muted),
                  ),
                ],
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                documentUrl,
                width: double.infinity,
                height: 240,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return Container(
                    height: 240,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 240,
                    width: double.infinity,
                    color: SM.primarySoft,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: SM.muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Impossible de charger le justificatif.',
                          style: SM.b(13, color: SM.muted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (hasDocument) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.cloud_done_outlined,
                  color: SM.success,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  'Justificatif enregistré',
                  style: SM.b(12, color: SM.success, w: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ========================================
  // AVATAR (construit une seule fois, hors animation)
  // ========================================
  Widget _buildAvatarCore() {
    return CircleAvatar(
      radius: 46,
      backgroundColor: Colors.white,
      child: ValueListenableBuilder<String?>(
        valueListenable: profilePhotoPath,
        builder: (_, path, __) {
          final hasPhoto =
              path != null && path.isNotEmpty && File(path).existsSync();

          return CircleAvatar(
            radius: 42,
            backgroundColor: SM.primary,
            backgroundImage: hasPhoto ? FileImage(File(path)) : null,
            child: !hasPhoto
                ? Text(
                    _initials,
                    style: SM.h(26).copyWith(color: Colors.white),
                  )
                : null,
          );
        },
      ),
    );
  }

  // ========================================
  // EN-TÊTE DU PROFIL
  // ========================================
  Widget _buildHeader() {
    final userName =
        _user == null ? '' : '${_user!.prenom} ${_user!.nom}'.trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SM.primary, SM.ai],
        ),
        borderRadius: BorderRadius.circular(SM.rCard + 4),
        boxShadow: SM.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SM.rCard + 4),
        child: Stack(
          children: [
            Positioned(top: -40, right: -30, child: _circle(140)),
            Positioned(bottom: -50, left: -30, child: _circle(150)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                children: [
                  // AVATAR ANIMÉ : seul l'anneau est reconstruit à chaque frame.
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _c,
                      child: _buildAvatarCore(),
                      builder: (_, avatar) {
                        final t = _c.value * 2 * math.pi;
                        final glow = 12 + math.sin(t * 2) * 6;

                        return Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.25),
                                blurRadius: glow,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.rotate(
                                angle: t,
                                child: Container(
                                  width: 104,
                                  height: 104,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        SM.accent,
                                        Colors.white,
                                        SM.accent,
                                        Colors.white24,
                                        SM.accent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              avatar!,
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isLoadingProfile
                        ? 'Chargement...'
                        : userName.isNotEmpty
                            ? userName
                            : 'Profil indisponible',
                    textAlign: TextAlign.center,
                    style: SM.h(22).copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user?.role ?? 'Étudiant',
                    style: SM.b(14, color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(SM.rBadge),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.award,
                          size: 16,
                          color: Color(0xFF065F46),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _user?.statut == 'active'
                              ? 'Compte actif'
                              : 'Compte inactif',
                          style: SM.b(
                            13,
                            color: const Color(0xFF065F46),
                            w: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _initials {
    final prenom = _user?.prenom.trim() ?? '';
    final nom = _user?.nom.trim() ?? '';

    final first = prenom.isNotEmpty ? prenom[0] : '';
    final second = nom.isNotEmpty ? nom[0] : '';

    final result = (first + second).toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }

  // ========================================
  // LIGNE DE SCORE
  // ========================================
  Widget _buildScore(int i, String name, double value) {
    final high = value >= .8;
    final duration = Duration(milliseconds: 900 + i * 150);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: SM.b(14, w: FontWeight.w600)),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => Text(
                  '${(val * 100).round()}%',
                  style: SM.b(
                    14,
                    color: high ? SM.success : SM.muted,
                    w: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (_, val, __) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 10,
                  color: SM.primarySoft,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: val,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: high
                              ? const [SM.success, Color(0xFF34D399)]
                              : const [SM.primary, SM.ai],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ========================================
  // DIALOGUE DE DÉCONNEXION
  // ========================================
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Se déconnecter ?', style: SM.h(20)),
          content: Text(
            'Voulez-vous vraiment vous déconnecter de votre compte ?',
            style: SM.b(14, color: SM.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  await _auth.signOut();
                  if (!mounted) return;

                  Navigator.of(this.context, rootNavigator: true)
                      .pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (e) {
                  _showMessage('Erreur de déconnexion : $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SM.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Déconnexion'),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// APPARITION ÉCHELONNÉE
// ============================================================
class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _Reveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + index * 110),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 24),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ============================================================
// MINI CARTE STATISTIQUE
// ============================================================
class _Mini extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String suffix;
  final String label;

  const _Mini({
    required this.icon,
    required this.color,
    required this.value,
    required this.suffix,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SMCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(SM.rBadge),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(
                '${v.round()}$suffix',
                style: SM.h(20),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: SM.b(12, color: SM.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LIGNE D'ACTION
// ============================================================
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SM.rButton),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SM.b(
                        15,
                        color: danger ? SM.danger : SM.text,
                        w: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: SM.b(12, color: SM.muted)),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: danger ? SM.danger.withValues(alpha: 0.6) : SM.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}