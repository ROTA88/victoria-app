import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Imports dos Relatórios (Gráfico e PDF)
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ==========================================
// IMPORTS DAS NOTIFICAÇÕES (Isso resolve as linhas vermelhas!)
// ==========================================
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ==========================================
// CONFIGURAÇÃO GLOBAL DAS NOTIFICAÇÕES
// ==========================================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> inicializarNotificacoes() async {
  tz.initializeTimeZones(); // Prepara os fusos horários

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      ); // Usa seu ícone da Victoria

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> agendarLembrete(
  int id,
  String titulo,
  String corpo,
  int horas,
) async {
  final agora = tz.TZDateTime.now(tz.local);
  final dataAgendada = agora.add(
    Duration(hours: horas),
  ); // Agenda para X horas no futuro

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'lembretes_bebe',
        'Lembretes da Victoria',
        channelDescription: 'Avisa quando é hora de alimentar ou dar remédio',
        importance: Importance.max,
        priority: Priority.high,
        color: Color(0xFFF48FB1), // Cor rosa da notificação
      );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    titulo,
    corpo,
    dataAgendada,
    platformChannelSpecifics,
    androidScheduleMode: AndroidScheduleMode
        .exactAllowWhileIdle, // Permite tocar mesmo com celular bloqueado
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

// ==========================================
// VARIÁVEIS GLOBAIS E INICIALIZAÇÃO
// ==========================================
String? globalBebeId;
int globalIntervaloMamada = 3;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Liga o motor de notificações
  await inicializarNotificacoes();

  // ATENÇÃO: Coloque sua URL e Chave reais do Supabase aqui
  await Supabase.initialize(
    url: 'https://SEU_PROJETO.supabase.co',
    anonKey: 'SUA_CHAVE',
  );

  runApp(const VictoriaApp());
}

final supabase = Supabase.instance.client;

class VictoriaApp extends StatelessWidget {
  const VictoriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diário da Victoria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF48FB1),
          background: const Color(0xFFFAFAFA),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

// ==========================================
// 1. GERENCIAMENTO DE SESSÃO E CARREGAMENTO
// ==========================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const DataLoaderScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

class DataLoaderScreen extends StatefulWidget {
  const DataLoaderScreen({super.key});

  @override
  State<DataLoaderScreen> createState() => _DataLoaderScreenState();
}

class _DataLoaderScreenState extends State<DataLoaderScreen> {
  @override
  void initState() {
    super.initState();
    _sincronizarBanco();
  }

  Future<void> _sincronizarBanco() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userDb = await supabase
          .from('usuarios')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (userDb == null) {
        await supabase.from('usuarios').insert({
          'id': user.id,
          'email': user.email ?? '',
        });
      }

      var bebeDb = await supabase
          .from('bebes')
          .select()
          .eq('usuario_id', user.id)
          .maybeSingle();
      if (bebeDb == null) {
        final inserido = await supabase
            .from('bebes')
            .insert({
              'usuario_id': user.id,
              'nome': 'Victoria Tugova',
              'intervalo_padrao_mamada': 3,
            })
            .select()
            .single();
        bebeDb = inserido;
      }

      globalBebeId = bebeDb['id'];
      globalIntervaloMamada = bebeDb['intervalo_padrao_mamada'] ?? 3;

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigator()),
        );
      }
    } catch (e) {
      debugPrint('Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.child_care_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. NAVEGAÇÃO E TELAS PRINCIPAIS
// ==========================================

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const TimelineScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline_rounded),
            label: 'Linha do Tempo',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HeaderSection(),
                const SizedBox(height: 32),
                const SummarySection(), // Onde a mágica dos cálculos acontece
                const SizedBox(height: 32),
                Text(
                  'Ações Rápidas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                const QuickActionsSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bom dia,',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            Text(
              'Victoria Tugova',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/icone.png',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.child_care_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// MATEMÁTICA E CÁLCULOS DO DASHBOARD
// ==========================================

class SummarySection extends StatefulWidget {
  const SummarySection({super.key});

  @override
  State<SummarySection> createState() => _SummarySectionState();
}

class _SummarySectionState extends State<SummarySection> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Atualiza a tela a cada 1 minuto para o cronômetro funcionar
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // Ouve todos os eventos para calcular os resumos
      stream: supabase
          .from('eventos')
          .stream(primaryKey: ['id'])
          .eq('bebe_id', globalBebeId!)
          .order('criado_em', ascending: false),
      builder: (context, snapshot) {
        final eventos = snapshot.data ?? [];

        // Filtra os últimos eventos de cada tipo
        final ultimaMamada = eventos.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['tipo'] == 'alimentacao',
          orElse: () => null,
        );
        final ultimoPeso = eventos.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['tipo'] == 'peso',
          orElse: () => null,
        );
        final ultimoRemedio = eventos.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['tipo'] == 'remedio',
          orElse: () => null,
        );

        // Lógica da Mamada
        String tempoFaltando = "Nenhuma mamada registrada";
        String resumoUltima = "";
        Color heroColor = Theme.of(context).colorScheme.primary;

        if (ultimaMamada != null) {
          final dataUltima = DateTime.parse(ultimaMamada['criado_em'])
              .toLocal();
          final dataProxima = dataUltima.add(
            Duration(hours: globalIntervaloMamada),
          );
          final agora = DateTime.now();
          final diff = dataProxima.difference(agora);

          if (diff.isNegative) {
            tempoFaltando = "Atrasado ${diff.abs().inMinutes} min";
            heroColor = Colors.red.shade400; // Fica vermelho se atrasar!
          } else {
            tempoFaltando =
                "Em ${diff.inHours}h e ${diff.inMinutes.remainder(60)}m";
          }

          final horaStr =
              '${dataUltima.hour.toString().padLeft(2, '0')}:${dataUltima.minute.toString().padLeft(2, '0')}';
          resumoUltima = "Última vez às $horaStr";
        }

        // Lógica do Peso
        String pesoStr = "-- kg";
        String dataPesoStr = "Registre hoje";
        if (ultimoPeso != null) {
          final dados = ultimoPeso['dados'];
          pesoStr = "${dados['peso']} kg";
          dataPesoStr = "Atualizado recentemente";
        }

        // Lógica do Remédio
        String remedioStr = "Nenhum";
        String horaRemedioStr = "--:--";
        if (ultimoRemedio != null) {
          final dados = ultimoRemedio['dados'];
          final dataRem = DateTime.parse(ultimoRemedio['criado_em']).toLocal();
          remedioStr = dados['nome'] ?? "Remédio";
          horaRemedioStr =
              '${dataRem.hour.toString().padLeft(2, '0')}:${dataRem.minute.toString().padLeft(2, '0')}';
        }

        return Column(
          children: [
            // Card Principal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [heroColor, heroColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: heroColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.water_drop_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Próxima Mamada',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tempoFaltando,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    resumoUltima,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Cards Secundários
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryCard(
                    context,
                    title: 'Últ. Remédio',
                    value: horaRemedioStr,
                    subtitle: remedioStr,
                    icon: Icons.medication_rounded,
                    color: Colors.orange.shade100,
                    iconColor: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSecondaryCard(
                    context,
                    title: 'Peso Atual',
                    value: pesoStr,
                    subtitle: dataPesoStr,
                    icon: Icons.monitor_weight_rounded,
                    color: Colors.green.shade100,
                    iconColor: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: [
        _QuickActionCard(
          title: 'Alimentar',
          icon: Icons.local_drink_rounded,
          color: Colors.pink.shade50,
          iconColor: Colors.pink.shade300,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ModalAlimentacao(),
          ),
        ),
        _QuickActionCard(
          title: 'Fralda',
          icon: Icons.baby_changing_station_rounded,
          color: Colors.blue.shade50,
          iconColor: Colors.blue.shade300,
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => const ModalFralda(),
          ),
        ),
        _QuickActionCard(
          title: 'Peso/Altura',
          icon: Icons.straighten_rounded,
          color: Colors.purple.shade50,
          iconColor: Colors.purple.shade300,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ModalPeso(),
          ),
        ),
        _QuickActionCard(
          title: 'Remédio',
          icon: Icons.medical_services_rounded,
          color: Colors.teal.shade50,
          iconColor: Colors.teal.shade300,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ModalRemedio(),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. TELAS SECUNDÁRIAS (TIMELINE & REPORTS)
// ==========================================

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  DateTime _dataSelecionada = DateTime.now();

  // Função para mudar o dia pelas setinhas
  void _mudarData(int dias) {
    setState(() {
      _dataSelecionada = _dataSelecionada.add(Duration(days: dias));
    });
  }

  // Função para abrir o Calendário nativo
  Future<void> _escolherData() async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2023), // Ano mínimo
      lastDate: DateTime.now(), // Não permite selecionar dias no futuro
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context)
                  .colorScheme
                  .primary, // Cor do calendário
            ),
          ),
          child: child!,
        );
      },
    );

    if (escolhida != null && escolhida != _dataSelecionada) {
      setState(() {
        _dataSelecionada = escolhida;
      });
    }
  }

  // Formata a data para ficar amigável
  String _formatarData(DateTime data) {
    final hoje = DateTime.now();
    final ontem = hoje.subtract(const Duration(days: 1));

    if (data.year == hoje.year &&
        data.month == hoje.month &&
        data.day == hoje.day) {
      return 'Hoje';
    } else if (data.year == ontem.year &&
        data.month == ontem.month &&
        data.day == ontem.day) {
      return 'Ontem';
    }
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Calcula o Início e o Fim do dia selecionado para filtrar no banco
    final inicioDoDia = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
    );
    final fimDoDia = inicioDoDia.add(const Duration(days: 1, milliseconds: -1));

    // Verifica se a data selecionada é hoje para desativar a setinha de avançar
    final hoje = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final podeAvancar = _dataSelecionada.isBefore(hoje);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Linha do Tempo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ==============================
          // 1. HEADER DO FILTRO DE DATA
          // ==============================
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Setinha para voltar (ontem, anteontem)
                IconButton(
                  onPressed: () => _mudarData(-1),
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 30,
                  ),
                ),

                // Botão de Data (Abre calendário)
                InkWell(
                  onTap: _escolherData,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatarData(_dataSelecionada),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Setinha para avançar (só funciona se não for hoje)
                IconButton(
                  onPressed: podeAvancar ? () => _mudarData(1) : null,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: podeAvancar
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // ==============================
          // 2. LISTA DE EVENTOS DO DIA
          // ==============================
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Filtro Mágico do Supabase: gte (maior ou igual) e lte (menor ou igual)
              stream: supabase
                  .from('eventos')
                  .stream(primaryKey: ['id'])
                  .eq('bebe_id', globalBebeId!)
                  .gte('criado_em', inicioDoDia.toUtc().toIso8601String())
                  .lte('criado_em', fimDoDia.toUtc().toIso8601String())
                  .order('criado_em', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                final eventos = snapshot.data ?? [];

                // Se não tiver eventos neste dia
                if (eventos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum registro para este dia.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Se tiver eventos, mostra a lista
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: eventos.length,
                  itemBuilder: (context, index) =>
                      _EventCard(evento: eventos[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> evento;
  const _EventCard({required this.evento});

  @override
  Widget build(BuildContext context) {
    final tipo = evento['tipo'] as String? ?? 'Outro';
    final dados = evento['dados'] as Map<String, dynamic>? ?? {};
    IconData icone = Icons.star_rounded;
    Color cor = Colors.orange;
    String descricao = '';

    switch (tipo.toLowerCase()) {
      case 'alimentacao':
        icone = Icons.local_drink_rounded;
        cor = Colors.pink;
        List<String> partes = [];
        if (dados['peito_esq_min'] != null && dados['peito_esq_min'] > 0)
          partes.add('Esq: ${dados['peito_esq_min']}m');
        if (dados['peito_dir_min'] != null && dados['peito_dir_min'] > 0)
          partes.add('Dir: ${dados['peito_dir_min']}m');
        if (dados['formula_ml'] != null && dados['formula_ml'] > 0)
          partes.add('Fórmula: ${dados['formula_ml']}ml');
        descricao = partes.join(' + ');
        break;
      case 'fralda':
        icone = Icons.baby_changing_station_rounded;
        cor = Colors.blue;
        descricao = dados['estado'] ?? 'Trocada';
        break;
      case 'peso':
        icone = Icons.monitor_weight_rounded;
        cor = Colors.green;
        descricao = '${dados['peso']}kg - ${dados['altura']}cm';
        break;
      case 'remedio':
        icone = Icons.medical_services_rounded;
        cor = Colors.teal;
        descricao = '${dados['nome']} (${dados['dose']})';
        break;
    }

    final dataHora = DateTime.tryParse(evento['criado_em'] ?? '')?.toLocal();
    final horaFormatada = dataHora != null
        ? '${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: cor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descricao,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            horaFormatada,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. ABA DE RELATÓRIOS E GRÁFICOS (COMPLETA)
// ==========================================

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  // Função mágica que gera e compartilha o PDF
  Future<void> _gerarECompartilharPDF(
    BuildContext context,
    List<Map<String, dynamic>> eventos,
  ) async {
    final pdf = pw.Document();

    // Filtra apenas eventos da última semana para o relatório
    final umaSemanaAtras = DateTime.now().subtract(const Duration(days: 7));
    final eventosRecentes = eventos.where((e) {
      final data = DateTime.parse(e['criado_em']);
      return data.isAfter(umaSemanaAtras);
    }).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // Usamos pwContext aqui para não dar conflito com o context da tela do Flutter
        build: (pw.Context pwContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Relatório de Saúde: Victoria Tugova',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                'Últimos 7 dias',
                style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 20),

              // Tabela do Relatório
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.pink,
                ), // Corrigido para pink
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Data/Hora', 'Tipo', 'Detalhes'],
                data: eventosRecentes.map((e) {
                  final dataHora = DateTime.parse(e['criado_em']).toLocal();
                  final formato = DateFormat('dd/MM/yyyy HH:mm')
                      .format(dataHora);
                  final tipo = e['tipo'].toString().toUpperCase();

                  String detalhes = '';
                  final dados = e['dados'] as Map<String, dynamic>;
                  if (tipo == 'ALIMENTACAO') {
                    if (dados['formula_ml'] != null && dados['formula_ml'] > 0)
                      detalhes += 'Fórmula: ${dados['formula_ml']}ml ';
                    if (dados['peito_esq_min'] != null &&
                        dados['peito_esq_min'] > 0)
                      detalhes += 'Esq: ${dados['peito_esq_min']}m ';
                    if (dados['peito_dir_min'] != null &&
                        dados['peito_dir_min'] > 0)
                      detalhes += 'Dir: ${dados['peito_dir_min']}m';
                  } else if (tipo == 'FRALDA') {
                    detalhes = dados['estado'] ?? 'Trocada';
                  } else if (tipo == 'PESO') {
                    detalhes = '${dados['peso']}kg - ${dados['altura']}cm';
                  } else if (tipo == 'REMEDIO') {
                    detalhes = '${dados['nome']} (${dados['dose']})';
                  }

                  return [formato, tipo, detalhes];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // Usa a biblioteca 'printing' para abrir a tela de compartilhar/imprimir
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_Victoria.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context)
          .colorScheme
          .surface, // Corrigido: background mudou para surface
      appBar: AppBar(
        title: const Text(
          'Evolução',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('eventos')
            .stream(primaryKey: ['id'])
            .eq('bebe_id', globalBebeId!)
            .order('criado_em', ascending: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final eventos = snapshot.data ?? [];
          final eventosPeso = eventos
              .where((e) => e['tipo'] == 'peso')
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===============================
                // CARTÃO DO GRÁFICO (CURVA DE PESO)
                // ===============================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_graph_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Curva de Peso',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Evolução em Quilogramas (Kg)',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 200,
                        child: eventosPeso.isEmpty
                            ? Center(
                                child: Text(
                                  'Insira dados de peso\npara gerar o gráfico.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              )
                            : LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: Colors.grey.shade200,
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        getTitlesWidget: (value, meta) {
                                          if (value.toInt() < 0 ||
                                              value.toInt() >=
                                                  eventosPeso.length)
                                            return const SizedBox.shrink();
                                          final data = DateTime.parse(
                                            eventosPeso[value
                                                .toInt()]['criado_em'],
                                          ).toLocal();
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Text(
                                              '${data.day}/${data.month}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: eventosPeso.asMap().entries.map((
                                        entry,
                                      ) {
                                        final peso =
                                            (entry.value['dados']['peso']
                                                    as num)
                                                .toDouble();
                                        return FlSpot(
                                          entry.key.toDouble(),
                                          peso,
                                        );
                                      }).toList(),
                                      isCurved: true,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      barWidth: 4,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ===============================
                // BOTÃO DE EXPORTAR PDF
                // ===============================
                Text(
                  'Exportar Relatório',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () {
                      if (eventos.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Não há dados para exportar!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      _gerarECompartilharPDF(context, eventos);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Colors.red.shade400,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gerar PDF para o Pediatra',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Histórico completo dos últimos 7 dias',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
// ==========================================
// 4. MODAIS E AÇÕES (SALVANDO NO BANCO)
// ==========================================

Future<void> _salvarEvento(
  BuildContext context,
  String tipo,
  Map<String, dynamic> dados,
) async {
  if (globalBebeId == null) return;
  try {
    await supabase.from('eventos').insert({
      'bebe_id': globalBebeId,
      'tipo': tipo,
      'dados': dados,
    });

    // ======== LÓGICA DO ALARME ========
    if (tipo == 'alimentacao') {
      // Agenda para o intervalo padrão (ex: 3 horas)
      await agendarLembrete(
        1, // ID da notificação (substitui a anterior para não encher o celular)
        'Hora de papar! 🍼',
        'Já se passaram $globalIntervaloMamada horas desde a última mamada da Victoria.',
        globalIntervaloMamada,
      );
    }
    // ==================================

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro salvo! Lembrete programado. ⏰'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
  }
}

class ModalFralda extends StatelessWidget {
  const ModalFralda({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Como estava a fralda?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _OpcaoFralda(
                icone: Icons.water_drop_rounded,
                cor: Colors.blue,
                titulo: 'Xixi',
                onTap: () =>
                    _salvarEvento(context, 'fralda', {'estado': 'Xixi'}),
              ),
              _OpcaoFralda(
                icone: Icons.cookie_rounded,
                cor: Colors.brown,
                titulo: 'Cocô',
                onTap: () =>
                    _salvarEvento(context, 'fralda', {'estado': 'Cocô'}),
              ),
              _OpcaoFralda(
                icone: Icons.cached_rounded,
                cor: Colors.orange,
                titulo: 'Ambos',
                onTap: () =>
                    _salvarEvento(context, 'fralda', {'estado': 'Xixi e Cocô'}),
              ),
              _OpcaoFralda(
                icone: Icons.wb_sunny_rounded,
                cor: Colors.green,
                titulo: 'Seca',
                onTap: () =>
                    _salvarEvento(context, 'fralda', {'estado': 'Seca'}),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _OpcaoFralda extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String titulo;
  final VoidCallback onTap;
  const _OpcaoFralda({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: cor, size: 32),
          ),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ModalAlimentacao extends StatefulWidget {
  const ModalAlimentacao({super.key});
  @override
  State<ModalAlimentacao> createState() => _ModalAlimentacaoState();
}

class _ModalAlimentacaoState extends State<ModalAlimentacao> {
  int peitoEsqMin = 0;
  int peitoDirMin = 0;
  final _mlController = TextEditingController();

  void _salvar() {
    int ml = int.tryParse(_mlController.text) ?? 0;
    if (peitoEsqMin == 0 && peitoDirMin == 0 && ml == 0) return;
    _salvarEvento(context, 'alimentacao', {
      'peito_esq_min': peitoEsqMin,
      'peito_dir_min': peitoDirMin,
      'formula_ml': ml,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Alimentação',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ContadorPeito(
                titulo: 'Esquerdo (min)',
                valor: peitoEsqMin,
                onAdd: () => setState(() => peitoEsqMin += 5),
                onSub: () => setState(
                  () => peitoEsqMin = peitoEsqMin > 0 ? peitoEsqMin - 5 : 0,
                ),
              ),
              _ContadorPeito(
                titulo: 'Direito (min)',
                valor: peitoDirMin,
                onAdd: () => setState(() => peitoDirMin += 5),
                onSub: () => setState(
                  () => peitoDirMin = peitoDirMin > 0 ? peitoDirMin - 5 : 0,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'E / OU',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
          TextField(
            controller: _mlController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Fórmula (ML)',
              prefixIcon: const Icon(Icons.local_drink_rounded),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Salvar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContadorPeito extends StatelessWidget {
  final String titulo;
  final int valor;
  final VoidCallback onAdd;
  final VoidCallback onSub;
  const _ContadorPeito({
    required this.titulo,
    required this.valor,
    required this.onAdd,
    required this.onSub,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: onSub,
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.pink,
            ),
            Text(
              '$valor',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
              color: Colors.pink,
            ),
          ],
        ),
      ],
    );
  }
}

/// Novo Modal de Peso e Altura
class ModalPeso extends StatefulWidget {
  const ModalPeso({super.key});
  @override
  State<ModalPeso> createState() => _ModalPesoState();
}

class _ModalPesoState extends State<ModalPeso> {
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();

  void _salvar() {
    double? peso = double.tryParse(_pesoController.text.replaceAll(',', '.'));
    double? altura = double.tryParse(
      _alturaController.text.replaceAll(',', '.'),
    );
    if (peso == null && altura == null) return;
    _salvarEvento(context, 'peso', {
      'peso': peso ?? 0.0,
      'altura': altura ?? 0.0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Peso e Altura',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pesoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Peso (Kg)',
                    prefixIcon: const Icon(Icons.monitor_weight_rounded),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _alturaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Altura (cm)',
                    prefixIcon: const Icon(Icons.straighten_rounded),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Salvar Medidas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Novo Modal de Remédio
class ModalRemedio extends StatefulWidget {
  const ModalRemedio({super.key});
  @override
  State<ModalRemedio> createState() => _ModalRemedioState();
}

class _ModalRemedioState extends State<ModalRemedio> {
  final _nomeController = TextEditingController();
  final _doseController = TextEditingController();

  void _salvar() {
    if (_nomeController.text.isEmpty) return;
    _salvarEvento(context, 'remedio', {
      'nome': _nomeController.text,
      'dose': _doseController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Medicamento',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nomeController,
            decoration: InputDecoration(
              labelText: 'Nome do Remédio (ex: Tylenol)',
              prefixIcon: const Icon(Icons.medical_services_rounded),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _doseController,
            decoration: InputDecoration(
              labelText: 'Dosagem (ex: 2 gotas, 5ml)',
              prefixIcon: const Icon(Icons.vaccines_rounded),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Salvar Remédio',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. TELA DE AUTENTICAÇÃO
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        await supabase.auth.signUp(email: email, password: password);
        if (mounted) setState(() => _isLogin = true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.child_care_rounded,
                  size: 80,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? 'Bem-vindo' : 'Criar Conta',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLogin ? 'Entrar' : 'Cadastrar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? 'Não tem conta? Cadastre-se'
                        : 'Já tem conta? Entre aqui',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
