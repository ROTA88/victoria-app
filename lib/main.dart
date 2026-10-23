import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cole sua URL e sua chave anon public aqui dentro das aspas:
  await Supabase.initialize(
    url: 'https://msebzeioagpncicqyvjt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zZWJ6ZWlvYWdwbmNpY3F5dmp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2OTcyNDMsImV4cCI6MjEwODI3MzI0M30.FBip1B6co7Rl3dnDq7ZPuL36xIRGCA4hoE1LKcUfW3s',
  );

  runApp(const VictoriaApp());
}

class VictoriaApp extends StatelessWidget {
  const VictoriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Victoria Tugova',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const NavegacaoPrincipal(),
    );
  }
}

// --- Estrutura da Barra de Navegação ---
class NavegacaoPrincipal extends StatefulWidget {
  const NavegacaoPrincipal({super.key});

  @override
  State<NavegacaoPrincipal> createState() => _NavegacaoPrincipalState();
}

class _NavegacaoPrincipalState extends State<NavegacaoPrincipal> {
  int _indiceAtual = 0;

  // Aqui ficam as 3 abas principais do app
  final List<Widget> _telas = [
    const TelaDashboard(),
    const Center(child: Text('Linha do Tempo (Em breve)')),
    const Center(child: Text('Relatórios em PDF (Em breve)')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _telas[_indiceAtual],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (index) {
          setState(() {
            _indiceAtual = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'Histórico'),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }
}

// --- Tela Inicial (Dashboard) ---
class TelaDashboard extends StatelessWidget {
  const TelaDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          children: [
            // A foto da Victoria carregada da pasta assets
            const CircleAvatar(backgroundImage: AssetImage('assets/icone.png')),
            const SizedBox(width: 12),
            const Text(
              'Victoria Tugova',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quadro de Próximos Eventos (Avisos de Alarme)
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Atual',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.restaurant_menu,
                      color: Colors.orange,
                    ),
                    title: const Text('Próxima Alimentação'),
                    subtitle: const Text(
                      'Em 2h 15m (16:30)',
                    ), // Será dinâmico com o banco
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () {},
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.medication, color: Colors.red),
                    title: Text('Próximo Remédio'),
                    subtitle: Text('Nenhum alarme ativo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Registrar Evento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Grid de Botões para ações rápidas
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _BotaoAcao(
                context,
                icone: Icons.restaurant,
                cor: Colors.orange,
                titulo: 'Alimentar',
              ),
              _BotaoAcao(
                context,
                icone: Icons.baby_changing_station,
                cor: Colors.blue,
                titulo: 'Fralda',
              ),
              _BotaoAcao(
                context,
                icone: Icons.scale,
                cor: Colors.green,
                titulo: 'Peso/Altura',
              ),
              _BotaoAcao(
                context,
                icone: Icons.medical_services,
                cor: Colors.red,
                titulo: 'Remédio',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Construtor dos botões coloridos
  Widget _BotaoAcao(
    BuildContext context, {
    required IconData icone,
    required Color cor,
    required String titulo,
  }) {
    return InkWell(
      onTap: () {
        // Aqui chamaremos a tela específica de cada botão
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: cor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 40, color: cor),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
