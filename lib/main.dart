
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://bnfyhpdlfwwvtkybxoax.supabase.co';
const supabaseKey = 'sb_publishable__Cv-taUolxlD2GAbjP549Q_idAf_ark';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  bool connected = false;
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
    connected = true;
  } catch (_) {}

  runApp(KimApp(prefs: prefs, connected: connected));
}

class KimApp extends StatefulWidget {
  final SharedPreferences prefs;
  final bool connected;

  const KimApp({
    super.key,
    required this.prefs,
    required this.connected,
  });

  @override
  State<KimApp> createState() => _KimAppState();
}

class _KimAppState extends State<KimApp> {
  late bool dark;
  late bool arabic;
  late String accent;

  @override
  void initState() {
    super.initState();
    dark = widget.prefs.getBool('dark') ?? true;
    arabic = widget.prefs.getBool('arabic') ?? true;
    accent = widget.prefs.getString('accent') ?? 'blue';
  }

  Color get primary => switch (accent) {
        'purple' => const Color(0xFF9B5CFF),
        'green' => const Color(0xFF00D6A0),
        _ => const Color(0xFF168BFF),
      };

  String tr(String ar, String en) => arabic ? ar : en;

  Future<void> save(String key, Object value) async {
    if (value is bool) await widget.prefs.setBool(key, value);
    if (value is String) await widget.prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF090D16) : const Color(0xFFF3F6FC);
    final panel = dark ? const Color(0xFF151C2B) : Colors.white;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KIM ADDONS',
      theme: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          foregroundColor: dark ? Colors.white : Colors.black87,
        ),
        cardTheme: CardThemeData(
          color: panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: primary.withValues(alpha: .18)),
          ),
        ),
      ),
      home: Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: HomeScreen(
          tr: tr,
          dark: dark,
          arabic: arabic,
          accent: accent,
          primary: primary,
          connected: widget.connected,
          onDark: (v) {
            setState(() => dark = v);
            save('dark', v);
          },
          onLanguage: (v) {
            setState(() => arabic = v);
            save('arabic', v);
          },
          onAccent: (v) {
            setState(() => accent = v);
            save('accent', v);
          },
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String Function(String, String) tr;
  final bool dark, arabic, connected;
  final String accent;
  final Color primary;
  final ValueChanged<bool> onDark, onLanguage;
  final ValueChanged<String> onAccent;

  const HomeScreen({
    super.key,
    required this.tr,
    required this.dark,
    required this.arabic,
    required this.accent,
    required this.primary,
    required this.connected,
    required this.onDark,
    required this.onLanguage,
    required this.onAccent,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String search = '';

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> authDialog(bool signup) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool busy = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(widget.tr(
            signup ? 'إنشاء حساب' : 'تسجيل الدخول',
            signup ? 'Create account' : 'Sign in',
          )),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: widget.tr('البريد الإلكتروني', 'Email'),
                  ),
                  validator: (v) => v != null && v.contains('@')
                      ? null
                      : widget.tr('أدخل بريدًا صحيحًا', 'Enter a valid email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: widget.tr('كلمة المرور', 'Password'),
                  ),
                  validator: (v) => v != null && v.length >= 6
                      ? null
                      : widget.tr('6 أحرف على الأقل', 'At least 6 characters'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text(widget.tr('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      if (!widget.connected) {
                        message(widget.tr(
                          'خدمة الحسابات غير متاحة حاليًا.',
                          'Account service is unavailable.',
                        ));
                        return;
                      }
                      setDialog(() => busy = true);
                      try {
                        if (signup) {
                          await Supabase.instance.client.auth.signUp(
                            email: email.text.trim(),
                            password: password.text,
                          );
                        } else {
                          await Supabase.instance.client.auth.signInWithPassword(
                            email: email.text.trim(),
                            password: password.text,
                          );
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        message(widget.tr(
                          signup
                              ? 'تم إرسال طلب إنشاء الحساب.'
                              : 'تم تسجيل الدخول بنجاح',
                          signup
                              ? 'Sign-up request submitted.'
                              : 'Signed in successfully',
                        ));
                        setState(() {});
                      } on AuthException catch (e) {
                        message(e.message);
                      } catch (_) {
                        message(widget.tr(
                          'حدث خطأ في الاتصال',
                          'Connection error',
                        ));
                      } finally {
                        if (dialogContext.mounted) {
                          setDialog(() => busy = false);
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.tr('متابعة', 'Continue')),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
  }

  Widget settingTile(
    IconData icon,
    String title,
    Widget trailing, {
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: widget.primary),
        title: Text(title),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget settingsPage() {
    final user = widget.connected
        ? Supabase.instance.client.auth.currentUser
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.tr('الإعدادات', 'Settings'),
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        settingTile(
          Icons.dark_mode_outlined,
          widget.tr('الوضع الداكن', 'Dark mode'),
          Switch(
            value: widget.dark,
            activeColor: widget.primary,
            onChanged: widget.onDark,
          ),
        ),
        settingTile(
          Icons.language,
          widget.tr('لغة التطبيق', 'App language'),
          DropdownButton<bool>(
            value: widget.arabic,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: true, child: Text('العربية')),
              DropdownMenuItem(value: false, child: Text('English')),
            ],
            onChanged: (v) {
              if (v != null) widget.onLanguage(v);
            },
          ),
        ),
        settingTile(
          Icons.palette_outlined,
          widget.tr('لون الثيم', 'Theme color'),
          DropdownButton<String>(
            value: widget.accent,
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(
                value: 'blue',
                child: Text(widget.tr('أزرق', 'Blue')),
              ),
              DropdownMenuItem(
                value: 'purple',
                child: Text(widget.tr('بنفسجي', 'Purple')),
              ),
              DropdownMenuItem(
                value: 'green',
                child: Text(widget.tr('أخضر', 'Green')),
              ),
            ],
            onChanged: (v) {
              if (v != null) widget.onAccent(v);
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.tr('الحساب', 'Account'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.account_circle_outlined,
                    size: 52, color: widget.primary),
                const SizedBox(height: 8),
                Text(
                  user?.email ??
                      widget.tr('أنت غير مسجّل الدخول', 'You are signed out'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                if (user == null) ...[
                  FilledButton.icon(
                    onPressed: () => authDialog(false),
                    icon: const Icon(Icons.login),
                    label: Text(widget.tr('تسجيل الدخول', 'Sign in')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => authDialog(true),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(widget.tr('إنشاء حساب جديد', 'Create account')),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await Supabase.instance.client.auth.signOut();
                        setState(() {});
                        message(widget.tr('تم تسجيل الخروج', 'Signed out'));
                      } catch (_) {
                        message(widget.tr(
                          'تعذّر تسجيل الخروج',
                          'Could not sign out',
                        ));
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(widget.tr('تسجيل الخروج', 'Sign out')),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.connected
              ? widget.tr(
                  'تم تهيئة خدمة الحسابات',
                  'Account service initialized',
                )
              : widget.tr(
                  'خدمة الحسابات غير متاحة حاليًا',
                  'Account service unavailable',
                ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: widget.connected ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final cats = [
      (Icons.construction, tr('أسلحة وأدوات', 'Weapons & tools')),
      (Icons.pets, tr('مخلوقات', 'Mobs')),
      (Icons.map_outlined, tr('خرائط ومغامرات', 'Maps & adventures')),
      (Icons.directions_car, tr('مركبات', 'Vehicles')),
      (Icons.chair_alt, tr('أثاث وديكور', 'Furniture & decor')),
      (Icons.texture, tr('حزم موارد', 'Resource packs')),
    ];

    final filtered = cats
        .where((c) => c.$2.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KIM ADDONS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            tooltip: tr('الإعدادات', 'Settings'),
            onPressed: () => setState(() => tab = 1),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: tab == 1
          ? settingsPage()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        widget.primary.withValues(alpha: .85),
                        const Color(0xFF111827),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('عالمك، إضافاتك!', 'Your world. Your addons!'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          'اكتشف إضافات ماين كرافت',
                          'Discover Minecraft addons',
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (v) => setState(() => search = v),
                        decoration: InputDecoration(
                          hintText: tr('ابحث عن تصنيف...', 'Search categories...'),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: .12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  tr('التصنيفات', 'Categories'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final cat = filtered[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => message(tr(
                          'سنربط هذا التصنيف بمكتبة الإضافات في الخطوة التالية.',
                          'This category will be connected to the addon library next.',
                        )),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(cat.$1, size: 34, color: widget.primary),
                              const SizedBox(height: 10),
                              Text(
                                cat.$2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  tr(
                    'هذه النسخة الأولى. سنضيف مكتبة التنزيلات الحقيقية ولوحة الإدارة لاحقًا.',
                    'This is the first version. Real downloads and the admin panel will be added next.',
                  ),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: tr('الرئيسية', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: tr('الإعدادات', 'Settings'),
          ),
        ],
      ),
    );
  }
}
