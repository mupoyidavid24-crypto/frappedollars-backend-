import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';
import '../../core/services/supabase_service.dart';
import '../../models/trading_account_model.dart';
import '../../models/subscription_model.dart';
import '../auth/auth_provider.dart';
import '../subscription/payment_service.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _loginController = TextEditingController();
  final _serverController = TextEditingController();
  final _passwordController = TextEditingController();
  final PaymentService _paymentService = PaymentService();

  @override
  void dispose() {
    _loginController.dispose();
    _serverController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showConnectMT5Dialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connecter MT5'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _loginController,
                decoration: const InputDecoration(labelText: 'Numéro de compte (Login)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _serverController,
                decoration: const InputDecoration(labelText: 'Serveur (ex: IC Markets-Demo)'),
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mot de passe investisseur'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final success = await Provider.of<DashboardProvider>(context, listen: false).connectMT5(
                authProvider.userProfile!.id,
                _loginController.text,
                _serverController.text,
                _passwordController.text,
              );
              if (success && mounted) {
                Navigator.pop(context);
                _loginController.clear();
                _serverController.clear();
                _passwordController.clear();
              }
            },
            child: const Text('CONNECTER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final supabaseService = SupabaseService();
    final userId = authProvider.userProfile!.id;
    final profile = authProvider.userProfile!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FrappedDollars'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabaseService.getAccountStream(userId),
        builder: (context, accountSnapshot) {
          final accountData = accountSnapshot.data?.isNotEmpty == true ? accountSnapshot.data![0] : null;
          final account = accountData != null ? TradingAccount.fromJson(accountData) : null;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabaseService.getSubscriptionStream(userId),
            builder: (context, subSnapshot) {
              final subData = subSnapshot.data?.isNotEmpty == true ? subSnapshot.data![0] : null;
              final sub = subData != null ? Subscription.fromJson(subData) : null;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBalanceCard(account),
                    const SizedBox(height: 16),
                    _buildPerformanceGraph(userId),
                    const SizedBox(height: 16),
                    _buildReferralCard(profile.referralCode),
                    const SizedBox(height: 16),
                    _buildStatusCard(sub, profile.needsVps),
                    const SizedBox(height: 24),
                    if (account == null)
                      _buildConnectMT5Button()
                    else ...[
                      _buildAccountDetails(account, userId),
                      const SizedBox(height: 24),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: supabaseService.getTradesStream(account.id!),
                        builder: (context, tradesSnapshot) {
                          final trades = (tradesSnapshot.data ?? []).toList();
                          return _buildTradesList(trades);
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPerformanceGraph(String userId) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance (Profit)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 0),
                      const FlSpot(1, 10),
                      const FlSpot(2, 15),
                      const FlSpot(3, 40),
                      const FlSpot(4, 35),
                      const FlSpot(5, 60),
                    ],
                    isCurved: true,
                    color: const Color(AppConstants.primaryColor),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(AppConstants.primaryColor).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(String? code) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Programme Parrainage', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Gagnez 5% sur chaque filleul', style: TextStyle(fontSize: 12, color: Colors.white60)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(AppConstants.primaryColor)),
                  ),
                  child: Text(code ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code ?? ""));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copié !')));
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('COPIER'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share('Rejoins-moi sur FrappedDollars ! Utilise mon code : $code');
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('PARTAGER'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(TradingAccount? account) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF008E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Solde Total (MT5)', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '\$${account?.balance.toStringAsFixed(2) ?? "0.00"}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallInfo('Equity', '\$${account?.equity.toStringAsFixed(2) ?? "0.00"}'),
              _buildSmallInfo('Status', account?.isActive == true ? 'Connecté' : 'Inactif'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusCard(Subscription? sub, bool needsVps) {
    final isActive = sub?.status.name == 'active' || sub?.status.name == 'manual_active';
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isActive ? Icons.check_circle : Icons.warning,
                color: isActive ? Colors.green : Colors.orange,
              ),
              title: const Text('Abonnement Copy Trading'),
              subtitle: Text(isActive ? 'Actif' : (sub?.status.name == 'weekly_limit_reached' ? 'Limite 250\$ atteinte' : 'Inactif ou expiré')),
            ),
            if (!isActive && sub?.status.name != 'weekly_limit_reached')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: () => _paymentService.handlePayment(
                    context: context,
                    amount: 50.0,
                    type: "COPY_TRADING_WEEKLY",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.primaryColor),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: const Text('PAYER L\'ABONNEMENT TRADING (50\$)'),
                ),
              ),
            if (needsVps && !isActive)
               Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: () => _paymentService.handlePayment(
                    context: context,
                    amount: 35.0,
                    type: "VPS_MONTHLY",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: const Text('PAYER L\'HÉBERGEMENT VPS (35\$)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectMT5Button() {
    return ElevatedButton.icon(
      onPressed: _showConnectMT5Dialog,
      icon: const Icon(Icons.add),
      label: const Text('CONNECTER MON COMPTE MT5'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: const Color(AppConstants.primaryColor),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAccountDetails(TradingAccount account, String userId) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Détails du compte MT5', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(
              title: const Text('Login MT5'),
              trailing: Text(account.mt5Login),
            ),
            ListTile(
              title: const Text('Serveur'),
              trailing: Text(account.mt5Server),
            ),
            TextButton(
              onPressed: () {
                Provider.of<DashboardProvider>(context, listen: false).disconnectMT5(userId);
              },
              child: const Text('Déconnecter le compte', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Télécharger mon EA'),
              onPressed: () async {
                final url = await Provider.of<DashboardProvider>(context, listen: false)
                    .downloadEa(account.mt5Login, userId);
                if (url != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lien de téléchargement généré.')),
                  );
                  // Ouvre le lien dans le navigateur
                  await launchUrl(Uri.parse(url));
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erreur lors de la génération du lien EA.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradesList(List<Map<String, dynamic>> trades) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historique des Trades',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (trades.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Aucun trade copié pour le moment.')),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trades.length,
            itemBuilder: (context, index) {
              final trade = trades[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('Trade #${trade['client_ticket_id'] ?? 'Pending'}'),
                  subtitle: Text('Volume: ${trade['volume_executed']}'),
                  trailing: Text(
                    trade['execution_status'],
                    style: TextStyle(
                      color: trade['execution_status'] == 'SUCCESS' ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
