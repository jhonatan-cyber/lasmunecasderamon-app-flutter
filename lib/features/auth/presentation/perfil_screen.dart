import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/api_client.dart';
import '../../../core/haptic_service.dart';
import '../../../core/theme.dart';
import '../data/auth_notifier.dart';
import '../domain/user.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  final String roleLabel;
  final String avatarEmoji;

  const PerfilScreen({
    super.key,
    required this.roleLabel,
    required this.avatarEmoji,
  });

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nickController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedCivilStatus = 'Soltero/a';
  final List<String> _civilStatusOptions = [
    'Soltero/a',
    'Casado/a',
    'Unión Libre',
    'Divorciado/a',
    'Viudo/a',
    'Separado/a'
  ];

  bool _isLoading = true;
  bool _saving = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  String? _localImagePath;
  final ImagePicker _picker = ImagePicker();
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchProfileData());
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final authNotifier = ref.read(authProvider.notifier);
      final enabled = await authNotifier.isBiometricEnabled();

      if (mounted) {
        setState(() {
          _isBiometricAvailable = canCheck && isSupported;
          _isBiometricEnabled = enabled;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
          _isBiometricEnabled = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nickController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.get('/users/profile');
      
      if (res.data != null && res.data['success'] == true) {
        final profile = res.data['data'] ?? {};
        
        setState(() {
          _nickController.text = profile['nick']?.toString() ?? '';
          _phoneController.text = profile['telefono']?.toString() ?? profile['phone']?.toString() ?? '';
          _addressController.text = profile['direccion']?.toString() ?? profile['address']?.toString() ?? '';
          
          final status = profile['estado_civil']?.toString() ?? 'Soltero/a';
          if (_civilStatusOptions.contains(status)) {
            _selectedCivilStatus = status;
          }
        });
      }
    } catch (_) {
      // Fallback local en caso de error de red
      final user = ref.read(authProvider).user;
      if (user != null) {
        _nickController.text = user.nick;
        _phoneController.text = user.phone;
        _addressController.text = user.address;
        if (_civilStatusOptions.contains(user.estadoCivil)) {
          _selectedCivilStatus = user.estadoCivil;
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _localImagePath = pickedFile.path;
        });
      }
    } catch (_) {
      // Ignorar
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleccionar Foto de Perfil',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: Theme.of(context).colorScheme.primary),
                title: Text('Tomar Foto con Cámara', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: Theme.of(context).colorScheme.primary),
                title: Text('Elegir de Galería', style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    final messenger = ScaffoldMessenger.of(context);
    await HapticService.medium();
    final user = ref.read(authProvider).user;
    if (user == null || _saving) return;

    if (_passwordController.text.trim().isNotEmpty && _passwordController.text.trim().length < 4) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.errorColor,
          content: Text(
            'La contraseña debe tener al menos 4 caracteres',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final client = ref.read(apiClientProvider);
      
      final Map<String, dynamic> dataMap = {
        'id': user.id,
        'nick': _nickController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'maritalStatus': _selectedCivilStatus,
      };

      if (_passwordController.text.trim().isNotEmpty) {
        dataMap['password'] = _passwordController.text.trim();
      }

      if (_localImagePath != null) {
        final file = File(_localImagePath!);
        final fileName = _localImagePath!.split('/').last;
        dataMap['foto'] = await MultipartFile.fromFile(file.path, filename: fileName);
      }

      final formData = FormData.fromMap(dataMap);
      
      final res = await client.dio.put('/users', data: formData);

      if (res.data != null && res.data['success'] == true) {
        final updatedData = res.data['data'] ?? {};
        
        final updatedUser = User(
          id: user.id,
          email: user.email,
          nombre: user.nombre,
          role: user.role,
          nick: updatedData['nick']?.toString() ?? _nickController.text,
          phone: updatedData['phone']?.toString() ?? _phoneController.text,
          address: updatedData['address']?.toString() ?? _addressController.text,
          estadoCivil: updatedData['maritalStatus']?.toString() ?? _selectedCivilStatus,
          foto: updatedData['foto']?.toString() ?? user.foto,
        );

        await ref.read(authProvider.notifier).updateProfile(updatedUser);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.successColor,
              content: Text('Perfil actualizado correctamente',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final msg = res.data?['message'] ?? 'Error al guardar perfil';
        throw Exception(msg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text(e.toString().replaceAll('Exception:', ''), style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _handleLogout() {
    HapticService.medium();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurfaceColor,
        title: Text('Cerrar sesión', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro que deseas salir?', style: GoogleFonts.inter(color: AppTheme.darkTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: Text('Salir', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentTheme = ref.watch(accentColorProvider);

    final bg = isDark ? AppTheme.darkBgColor : const Color(0xFFF3F4F6);
    final cardBg = isDark ? AppTheme.darkSurfaceColor : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);
    final borderColor = isDark ? AppTheme.darkBorderColor : Colors.grey.shade200;

    final nameText = user != null ? '${user.nombre} ${user.nick.isNotEmpty ? "(${user.nick})" : ""}' : '';

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Premium Header with Gradient
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: accentTheme.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: accentTheme.color.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        Text(
                          'Mi Perfil',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Avatar and Edit Badge
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                          ),
                          child: _localImagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(9999),
                                  child: Image.file(
                                    File(_localImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : (user?.foto != null && user!.foto.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(9999),
                                      child: Image.network(
                                        user.foto.startsWith('http')
                                            ? user.foto
                                            : '${ApiClient.baseDomain}/img/users/${user.foto}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, err, st) => Center(
                                          child: Text(
                                            widget.avatarEmoji,
                                            style: const TextStyle(fontSize: 48),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        widget.avatarEmoji,
                                        style: const TextStyle(fontSize: 48),
                                      ),
                                    )),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accentTheme.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBg, width: 2.5),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      nameText,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.roleLabel.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(accentTheme.color),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Apariencia del Sistema
                          _buildInputLabel('Apariencia del Sistema', subColor),
                          const SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: appThemeOptions.map((option) {
                                final isSelected = accentTheme.color.toARGB32() == option.color.toARGB32();
                                return GestureDetector(
                                  onTap: () {
                                    ref.read(accentColorProvider.notifier).setAccentColor(option);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 44,
                                    height: 44,
                                    margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: option.gradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: textColor, width: 3)
                                          : Border.all(color: Colors.transparent, width: 0),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: option.gradient.first.withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(color: borderColor, height: 1, thickness: 1),
                          const SizedBox(height: 20),

                          // Scene Name / Nickname
                          _buildInputLabel('Nickname / Nombre de Escena', subColor),
                          _buildTextField(
                            controller: _nickController,
                            icon: Icons.stars_rounded,
                            hintText: 'Tu nick',
                            textColor: textColor,
                            borderColor: borderColor,
                            cardBg: cardBg,
            iconColor: accentTheme.color,
          ),
          const SizedBox(height: 20),

                          // Phone
                          _buildInputLabel('Teléfono', subColor),
                          _buildTextField(
                            controller: _phoneController,
                            icon: Icons.phone_rounded,
                            hintText: 'Teléfono',
                            keyboardType: TextInputType.phone,
                            textColor: textColor,
                            borderColor: borderColor,
                            cardBg: cardBg,
            iconColor: accentTheme.color,
          ),
          const SizedBox(height: 20),

                          // Address
                          _buildInputLabel('Dirección', subColor),
                          _buildTextField(
                            controller: _addressController,
                            icon: Icons.location_on_rounded,
                            hintText: 'Dirección',
                            textColor: textColor,
                            borderColor: borderColor,
                            cardBg: cardBg,
            iconColor: accentTheme.color,
          ),
          const SizedBox(height: 20),

                          // Marital Status (Estado Civil)
                          _buildInputLabel('Estado Civil', subColor),
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.favorite_rounded, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCivilStatus,
                                      dropdownColor: cardBg,
                                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                      items: _civilStatusOptions.map((opt) {
                                        return DropdownMenuItem<String>(
                                          value: opt,
                                          child: Text(opt),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedCivilStatus = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // New Password
                          _buildInputLabel('Nueva Contraseña (Opcional)', subColor),
                          _buildTextField(
                            controller: _passwordController,
                            icon: Icons.lock_rounded,
                            hintText: 'Nueva contraseña (mínimo 4 caracteres)',
                            obscureText: true,
                            textColor: textColor,
                            borderColor: borderColor,
                            cardBg: cardBg,
            iconColor: accentTheme.color,
          ),
          const SizedBox(height: 35),
                          
                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentTheme.color,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: _saving ? null : _saveChanges,
                              child: _saving
                                  ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                                  : Text(
                                      'GUARDAR CAMBIOS',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Biometric Auth Toggle
                          if (_isBiometricAvailable) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: borderColor, width: 1.5),
                              ),
                              child: SwitchListTile(
                                secondary: Icon(
                                  Icons.fingerprint_rounded,
                                  color: _isBiometricEnabled
                                      ? accentTheme.color
                                      : subColor,
                                ),
                                title: Text(
                                  'Inicio con huella / Face ID',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Text(
                                  'Inicia sesión sin escribir tu contraseña',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: subColor,
                                  ),
                                ),
                                value: _isBiometricEnabled,
                                activeThumbColor: accentTheme.color,
                                onChanged: (val) async {
                                  final notifier = ref.read(authProvider.notifier);
                                  final messenger = ScaffoldMessenger.of(context);
                                  if (val) {
                                    final authenticated = await _localAuth.authenticate(
                                      localizedReason: 'Confirma tu identidad para habilitar el ingreso biométrico',
                                      biometricOnly: true,
                                    );
                                    if (authenticated) {
                                      final creds = await notifier.getCredentials();
                                      if (creds != null) {
                                        await notifier.setBiometricEnabled(true);
                                        setState(() => _isBiometricEnabled = true);
                                      } else if (messenger.mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            backgroundColor: AppTheme.warningColor,
                                            content: Text(
                                              'Inicia sesión manualmente primero para guardar tus credenciales',
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    await notifier.setBiometricEnabled(false);
                                    setState(() => _isBiometricEnabled = false);
                                  }
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Logout button
                          Center(
                            child: TextButton.icon(
                              onPressed: _handleLogout,
                              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                              label: Text(
                                'Cerrar Sesión',
                                style: GoogleFonts.inter(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    required Color textColor,
    required Color borderColor,
    required Color cardBg,
    Color? iconColor,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
