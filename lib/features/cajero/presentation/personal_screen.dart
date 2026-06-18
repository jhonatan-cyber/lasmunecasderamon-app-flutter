import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../auth/data/auth_notifier.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/skeleton_loader.dart';

class UserStaff {
  final String id;
  final String name;
  final String lastName;
  final String nick;
  final String role;
  final String? foto;
  final int status;
  final String? qrToken;

  UserStaff({
    required this.id,
    required this.name,
    required this.lastName,
    required this.nick,
    required this.role,
    this.foto,
    required this.status,
    this.qrToken,
  });

  factory UserStaff.fromJson(Map<String, dynamic> json) {
    return UserStaff(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['nombre'] ?? '',
      lastName: json['lastName'] ?? json['apellido'] ?? '',
      nick: json['nick'] ?? json['username'] ?? '',
      role: json['role'] is Map ? (json['role']['name'] ?? '') : (json['role'] ?? ''),
      foto: json['foto'],
      status: json['status'] is int ? json['status'] : 1,
      qrToken: json['qr_token'],
    );
  }

  UserStaff copyWith({String? qrToken}) {
    return UserStaff(
      id: id,
      name: name,
      lastName: lastName,
      nick: nick,
      role: role,
      foto: foto,
      status: status,
      qrToken: qrToken ?? this.qrToken,
    );
  }
}

class CajeroPersonalScreen extends ConsumerStatefulWidget {
  const CajeroPersonalScreen({super.key});

  @override
  ConsumerState<CajeroPersonalScreen> createState() => _CajeroPersonalScreenState();
}

class _CajeroPersonalScreenState extends ConsumerState<CajeroPersonalScreen> {
  List<UserStaff> _users = [];
  String _searchTerm = '';
  UserStaff? _selectedUser;
  bool _isGenerating = false;
  String _codigoAsistencia = '';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _fetchUsers();
      _fetchCodigoAsistencia();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('personal').notifier);
    if (!isManual && _users.isEmpty) {
      notifier.startRefresh(isManual: false);
    } else if (isManual) {
      notifier.startRefresh(isManual: true);
    }
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/users?status=active');
      
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> allUsersRaw = response.data['data'] ?? [];
        final List<UserStaff> staff = allUsersRaw
            .map((u) => UserStaff.fromJson(u))
            .where((u) {
              final r = u.role.toLowerCase();
              if (r.contains('admin') || r.contains('administrador')) return false;
              return r.contains('garzon') ||
                  r.contains('garzÃ³n') ||
                  r.contains('mesero') ||
                  r.contains('cajero') ||
                  r.contains('anfitriona');
            })
            .toList();

        if (!mounted) return;
        setState(() => _users = staff);
        notifier.endRefresh();

        // Actualizar el usuario seleccionado en caso de que estÃ© abierto para reflejar cambios
        if (_selectedUser != null) {
          final updatedSelected = staff.firstWhere(
            (u) => u.id == _selectedUser!.id,
            orElse: () => _selectedUser!,
          );
          if (updatedSelected.qrToken != _selectedUser!.qrToken) {
            final oldToken = _selectedUser!.qrToken;
            setState(() {
              _selectedUser = updatedSelected;
            });
            // Si el QR ya no estÃ¡ o cambiÃ³ a null, significa que fue usado
            if (oldToken != null && updatedSelected.qrToken == null) {
              _closeQrModal();
              if (mounted) AppSnackBar.showSuccess(context, 'Asistencia registrada correctamente.');
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      notifier.endRefresh(error: 'No se pudo cargar el personal');
    }
  }

  Future<void> _fetchCodigoAsistencia() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/codigo/actual');
      if (response.data != null && response.data['success'] == true) {
        setState(() {
          _codigoAsistencia = response.data['codigo']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _handleGenerateQR(String userId) async {
    setState(() => _isGenerating = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post(
        '/users/generate-qr',
        data: {'userId': userId},
      );

      if (response.data != null && response.data['success'] == true) {
        final String newQrToken = response.data['qr_token']?.toString() ?? '';
        
        setState(() {
          _users = _users.map((u) => u.id == userId ? u.copyWith(qrToken: newQrToken) : u).toList();
          if (_selectedUser?.id == userId) {
            _selectedUser = _selectedUser!.copyWith(qrToken: newQrToken);
          }
          _isGenerating = false;
        });
        if (mounted) AppSnackBar.showSuccess(context, 'CÃ³digo QR generado con Ã©xito');
        _startPolling(userId);
      } else {
        setState(() => _isGenerating = false);
        if (mounted) AppSnackBar.showError(context, response.data['message'] ?? 'Error al generar QR');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) AppSnackBar.showError(context, 'Error de red al generar el token QR');
    }
  }

  void _startPolling(String userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final client = ref.read(apiClientProvider);
        final response = await client.dio.get('/users/$userId');
        if (response.data != null && response.data['success'] == true) {
          final updatedRaw = response.data['user'];
          if (updatedRaw != null) {
            final updatedUser = UserStaff.fromJson(updatedRaw);
            
            // Si el token QR se limpiÃ³ en el servidor, significa que fue escaneado/usado
            if (_selectedUser?.id == userId && _selectedUser?.qrToken != null && updatedUser.qrToken == null) {
              _pollingTimer?.cancel();
              setState(() {
                _users = _users.map((u) => u.id == userId ? updatedUser : u).toList();
                _selectedUser = null;
              });
              if (mounted) AppSnackBar.showSuccess(context, 'Asistencia registrada correctamente.');
            }
          }
        }
      } catch (_) {}
    });
  }

  void _openQrModal(UserStaff user) {
    setState(() {
      _selectedUser = user;
    });
    _fetchCodigoAsistencia();
    if (user.qrToken != null) {
      _startPolling(user.id);
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final userLocal = _users.firstWhere((u) => u.id == _selectedUser?.id, orElse: () => user);
            final hasQR = userLocal.qrToken != null;
            final photoUrl = userLocal.foto != null && userLocal.foto!.isNotEmpty
                ? 'https://dashboard.xn--lasmuecasderamon-bub.com/img/users/${userLocal.foto}'
                : null;

            return Dialog(
              backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header del modal con botÃ³n de cierre
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              _pollingTimer?.cancel();
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Avatar y datos
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 2),
                        ),
                        child: ClipOval(
                          child: photoUrl != null
                              ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(userLocal))
                              : _buildAvatarPlaceholder(userLocal),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${userLocal.name} ${userLocal.lastName}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${userLocal.nick}',
                        style: GoogleFonts.inter(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          userLocal.role.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Cuerpo dinÃ¡mico (CÃ³digo QR o botÃ³n de generar)
                      if (hasQR) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.network(
                            'https://api.qrserver.com/v1/create-qr-code/?size=250x250&color=e11d48&data=${userLocal.qrToken}',
                            width: 180,
                            height: 180,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                width: 180,
                                height: 180,
                                child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_outlined, size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              'Token de seguridad activo',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (_codigoAsistencia.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('CÃ³digo: ', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                                Text(_codigoAsistencia, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // BotÃ³n regenerar
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isGenerating
                                ? null
                                : () async {
                                    setModalState(() => _isGenerating = true);
                                    await _handleGenerateQR(userLocal.id);
                                    setModalState(() => _isGenerating = false);
                                  },
                            child: _isGenerating
                                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text('Regenerar QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                    ],
                                  ),
                          ),
                        ),
                      ] else ...[
                        // Vista sin QR
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.qr_code_scanner_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sin CÃ³digo QR',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Este usuario no tiene un cÃ³digo de asistencia asignado.',
                          style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: AppTheme.getPrimaryButtonStyle(context),
                            onPressed: _isGenerating
                                ? null
                                : () async {
                                    setModalState(() => _isGenerating = true);
                                    await _handleGenerateQR(userLocal.id);
                                    setModalState(() => _isGenerating = false);
                                  },
                            child: _isGenerating
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.qr_code_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Generar QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _closeQrModal();
    });
  }

  void _closeQrModal() {
    _pollingTimer?.cancel();
    if (_selectedUser != null) {
      setState(() {
        _selectedUser = null;
      });
      // Si el dialogo sigue abierto por el Navigator, lo cerramos
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildAvatarPlaceholder(UserStaff u) {
    final initials = '${u.name.isNotEmpty ? u.name[0] : ''}${u.lastName.isNotEmpty ? u.lastName[0] : ''}'.toUpperCase();
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'U',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 22),
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return ShimmerWrapper(child: GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const SkeletonCard(showAvatar: true, lines: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredUsers = _users.where((u) {
      final search = _searchTerm.toLowerCase();
      return u.name.toLowerCase().contains(search) ||
          u.lastName.toLowerCase().contains(search) ||
          u.nick.toLowerCase().contains(search);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          // Shared gradient header
          PremiumHeader(
            title: 'Personal',
            showBackButton: true,
            onBack: () => Navigator.pop(context),
            showRefreshButton: true,
            isRefreshing: ref.watch(refreshProvider('personal')).isRefreshing,
            onRefresh: () {
              _fetchUsers(isManual: true);
              _fetchCodigoAsistencia();
            },

          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o nick...',
                        hintStyle: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchTerm = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido principal (Listado)
          Expanded(
            child: FadeLoadingSwitcher(
              isLoading: ref.watch(refreshProvider('personal')).isLoading,
              skeleton: _buildSkeletonGrid(),
              content: RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: () => _fetchUsers(isManual: true),
                    child: filteredUsers.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline_rounded, size: 64, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchTerm.isEmpty ? 'No hay personal registrado' : 'No se encontraron resultados',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.95,
                            ),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final u = filteredUsers[index];
                              final hasQR = u.qrToken != null;
                              final photoUrl = u.foto != null && u.foto!.isNotEmpty
                                  ? 'https://dashboard.xn--lasmuecasderamon-bub.com/img/users/${u.foto}'
                                  : null;

                              return Card(
                                elevation: 4,
                                color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _openQrModal(u),
                                  child: Column(
                                    children: [
                                      // Header de Rol
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(19),
                                            topRight: Radius.circular(19),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            u.role.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Avatar con indicador de estado QR
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), width: 1.5),
                                            ),
                                            child: ClipOval(
                                              child: photoUrl != null
                                                  ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(u))
                                                  : _buildAvatarPlaceholder(u),
                                            ),
                                          ),
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: hasQR ? Colors.green : Colors.redAccent,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, width: 1.5),
                                              ),
                                              child: Icon(
                                                hasQR ? Icons.check : Icons.close,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Datos del trabajador
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                        child: Text(
                                          u.name,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '@${u.nick}',
                                        style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),

                                      // Estado QR
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: hasQR ? Colors.green.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              hasQR ? Icons.qr_code_rounded : Icons.qr_code_outlined,
                                              size: 11,
                                              color: hasQR ? Colors.green : Colors.redAccent,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              hasQR ? 'QR Activo' : 'Sin QR',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: hasQR ? Colors.green : Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
              ),
          ),
        ],
      ),
    );
  }
}
