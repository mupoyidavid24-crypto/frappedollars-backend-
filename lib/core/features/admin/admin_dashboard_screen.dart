import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import 'admin_auth.dart';
import 'admin_users_service.dart';
import 'error_admin_service.dart';
import 'copytrading_admin_service.dart';
import 'logs_admin_service.dart';
import 'notification_admin_service.dart';
import 'payment_admin_service.dart';
import 'vip_admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<_AdminDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();
  }

  Future<_AdminDashboardData> _loadDashboardData() async {
    final results = await Future.wait<dynamic>([
      _safeFetch(PaymentAdminService.fetchPayments),
      _safeFetch(NotificationAdminService.fetchNotifications),
      _safeFetch(VIPAdminService.fetchVIPUsers),
      _safeFetch(LogsAdminService.fetchLogs),
      _safeFetch(CopyTradingAdminService.fetchHistory),
      _safeFetch(ErrorAdminService.fetchErrors),
      _safeFetch(AdminUsersService.fetchUsers),
      _safeFetchMap(_fetchDashboardSummary),
    ]);

    final payments = List<Map<String, dynamic>>.from(results[0] as List);
    final notifications = List<Map<String, dynamic>>.from(results[1] as List);
    final vipUsers = List<Map<String, dynamic>>.from(results[2] as List);
    final logs = List<Map<String, dynamic>>.from(results[3] as List);
    final copytradingHistory = List<Map<String, dynamic>>.from(results[4] as List);
    final errorsLogs = List<Map<String, dynamic>>.from(results[5] as List);
    final adminUsers = List<Map<String, dynamic>>.from(results[6] as List);
    final summary = Map<String, dynamic>.from(results[7] as Map);

    final usersSummary = Map<String, dynamic>.from(summary['users'] as Map? ?? {});
    final accountsSummary = Map<String, dynamic>.from(summary['accounts'] as Map? ?? {});
    final paymentsSummary = Map<String, dynamic>.from(summary['payments'] as Map? ?? {});
    final copytradingSummary = Map<String, dynamic>.from(summary['copytrading'] as Map? ?? {});
    final activitySummary = Map<String, dynamic>.from(summary['activity'] as Map? ?? {});
    final recentUsers = adminUsers;
    final recentCopytrades = List<Map<String, dynamic>>.from(summary['recent_copytrades'] as List? ?? const []);

    final pendingPayments = payments.where((item) => _statusOf(item) == 'EN_ATTENTE').length;
    final validatedPayments = payments.where((item) => _statusOf(item) == 'VALIDATED').length;
    final refusedPayments = payments.where((item) => _statusOf(item) == 'REFUSED').length;

    return _AdminDashboardData(
      payments: payments,
      notifications: notifications,
      vipUsers: vipUsers,
      logs: logs,
      copytradingHistory: copytradingHistory,
      errorsLogs: errorsLogs,
      pendingPayments: pendingPayments,
      validatedPayments: validatedPayments,
      refusedPayments: refusedPayments,
      totalUsers: _asInt(usersSummary['total']),
      activeUsers: _asInt(usersSummary['active']),
      suspendedUsers: _asInt(usersSummary['suspended']),
      vipUsersCount: _asInt(usersSummary['vip']),
      usersWithMt5: _asInt(usersSummary['with_mt5']),
      totalAccounts: _asInt(accountsSummary['total']),
      activeAccounts: _asInt(accountsSummary['active']),
      inactiveAccounts: _asInt(accountsSummary['inactive']),
      masterAccounts: _asInt(accountsSummary['master']),
      clientAccounts: _asInt(accountsSummary['client']),
      totalPayments: _asInt(paymentsSummary['total']),
      pendingPaymentsSummary: _asInt(paymentsSummary['pending']),
      validatedPaymentsSummary: _asInt(paymentsSummary['validated']),
      refusedPaymentsSummary: _asInt(paymentsSummary['refused']),
      totalPaymentAmount: _asDouble(paymentsSummary['amount_total']),
      signalsTotal: _asInt(copytradingSummary['signals_total']),
      copiedTradesTotal: _asInt(copytradingSummary['copied_total']),
      copyExecutedTrades: _asInt(copytradingSummary['executed']),
      copyFailedTrades: _asInt(copytradingSummary['failed']),
      copyPendingTrades: _asInt(copytradingSummary['pending']),
      copyRetryTrades: _asInt(copytradingSummary['retry']),
      averageCopyLatencyMs: _asDouble(copytradingSummary['average_latency_ms']),
      dispatchCounts: Map<String, dynamic>.from(copytradingSummary['dispatch_pipeline'] as Map? ?? {}),
      notificationsCount: _asInt(activitySummary['notifications']),
      supportTicketsCount: _asInt(activitySummary['support_tickets']),
      openTicketsCount: _asInt(activitySummary['open_tickets']),
      activitySignalsCount: _asInt(activitySummary['signals']),
      recentUsers: recentUsers,
      recentCopytrades: recentCopytrades,
    );
  }

  Future<Map<String, dynamic>> _fetchDashboardSummary() async {
    final response = await http.get(
      Uri.parse('${AppConstants.adminBaseUrl}/dashboard/summary'),
      headers: AdminAuth.headers(),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return Map<String, dynamic>.from(decoded as Map);
    }
    throw Exception('Erreur chargement synthèse admin');
  }

  Future<List<Map<String, dynamic>>> _safeFetch(Future<List<Map<String, dynamic>>> Function() fetcher) async {
    try {
      return await fetcher();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> _safeFetchMap(Future<Map<String, dynamic>> Function() fetcher) async {
    try {
      return await fetcher();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _statusOf(Map<String, dynamic> item) {
    return (item['status']?.toString().toUpperCase() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      drawer: MediaQuery.sizeOf(context).width < 1024 ? const _AdminSidebar() : null,
      body: FutureBuilder<_AdminDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _AdminDashboardData.empty();

          return SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF071116), Color(0xFF0C161B), Color(0xFF05080B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1100;
                  return Row(
                    children: [
                      if (isWide) const SizedBox(width: 300, child: _AdminSidebar()),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 24 : 16,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AdminTopBar(
                                isWide: isWide,
                                isLoading: snapshot.connectionState == ConnectionState.waiting,
                                onRefresh: () {
                                  setState(() {
                                    _dashboardFuture = _loadDashboardData();
                                  });
                                },
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildHeroSection(context, data, isWide),
                                      const SizedBox(height: 20),
                                      _buildStatsRow(data, isWide),
                                      const SizedBox(height: 20),
                                      _buildBottomGrid(context, data, isWide),
                                      const SizedBox(height: 20),
                                      _buildGoalOverview(data, isWide),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, _AdminDashboardData data, bool isWide) {
    final totalSignals = data.signalsTotal + data.copiedTradesTotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1C22), Color(0xFF0A1115), Color(0xFF0D1B1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 40,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildBalanceChart(totalSignals, data)),
                const SizedBox(width: 16),
                SizedBox(width: 320, child: _buildInsightPanel(data)),
              ],
            )
          : Column(
              children: [
                _buildBalanceChart(totalSignals, data),
                const SizedBox(height: 16),
                _buildInsightPanel(data),
              ],
            ),
    );
  }

  Widget _buildBalanceChart(int totalSignals, _AdminDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'FrappedDollars Admin Center',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              _StatusChip(label: '${data.validatedPayments} validés'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Vue d’ensemble des flux paiements, notifications et copy trading.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Base active', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    Uri.parse(AppConstants.backendBaseUrl).host,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              _MetricPill(label: 'MT5', value: '${data.activeAccounts}'),
              const SizedBox(width: 8),
              _MetricPill(label: 'Users', value: '${data.activeUsers}'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 7,
                minY: 0,
                maxY: 10,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Color(0xFF101A1F),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 2.2),
                      FlSpot(1, 2.8),
                      FlSpot(2, 3.1),
                      FlSpot(3, 4.7),
                      FlSpot(4, 5.2),
                      FlSpot(5, 4.8),
                      FlSpot(6, 7.1),
                      FlSpot(7, 6.9),
                    ],
                    isCurved: true,
                    color: const Color(0xFF3EE7B6),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3EE7B6).withOpacity(0.10),
                    ),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 1.7),
                      FlSpot(1, 2.1),
                      FlSpot(2, 2.0),
                      FlSpot(3, 2.6),
                      FlSpot(4, 3.3),
                      FlSpot(5, 4.0),
                      FlSpot(6, 4.5),
                      FlSpot(7, 5.3),
                    ],
                    isCurved: true,
                    color: const Color(0xFF2A7F6E).withOpacity(0.65),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightPanel(_AdminDashboardData data) {
    return Column(
      children: [
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(title: 'Account Loss Analysis'),
              const SizedBox(height: 12),
              _AnalysisRow(label: 'Paiements en attente', value: '${data.pendingPaymentsSummary}', valueColor: const Color(0xFFFFD66B)),
              const SizedBox(height: 10),
              _AnalysisRow(label: 'Trades exécutés', value: '${data.copyExecutedTrades}', valueColor: const Color(0xFF3EE7B6)),
              const SizedBox(height: 10),
              _AnalysisRow(label: 'Trades échoués', value: '${data.copyFailedTrades}', valueColor: const Color(0xFFFF7C7C)),
              const SizedBox(height: 10),
              _AnalysisRow(label: 'Notifications', value: '${data.notificationsCount}', valueColor: const Color(0xFF9AD7FF)),
              const SizedBox(height: 10),
              _AnalysisRow(label: 'Erreurs centralisées', value: '${data.errorsLogs.length}', valueColor: const Color(0xFFFF9A9A)),
              const SizedBox(height: 10),
              _AnalysisRow(
                label: 'Latence copie',
                value: data.averageCopyLatencyMs == 0 ? 'n/a' : '${data.averageCopyLatencyMs.toStringAsFixed(0)} ms',
                valueColor: const Color(0xFFB9F6E8),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _progressValue(data),
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3EE7B6)),
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 8),
              const Text('Taux d’activité estimé', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(title: 'Next steps'),
              const SizedBox(height: 12),
              _ActionLine(title: 'Valider les paiements', subtitle: '${data.pendingPayments} en attente', icon: Icons.payments_outlined, onTap: () => Navigator.pushNamed(context, '/admin/payments')),
              const SizedBox(height: 8),
              _ActionLine(title: 'Synchroniser copy trading', subtitle: '${data.copytradingHistory.length} historiques', icon: Icons.sync_alt, onTap: () => Navigator.pushNamed(context, '/admin/copytrading')),
            ],
          ),
        ),
      ],
    );
  }

  double _progressValue(_AdminDashboardData data) {
    final score = data.validatedPaymentsSummary + data.activeUsers + data.copyExecutedTrades;
    if (score == 0) return 0.15;
    final normalized = (score / 50).clamp(0.15, 0.95);
    return normalized.toDouble();
  }

  Widget _buildStatsRow(_AdminDashboardData data, bool isWide) {
    final stats = [
      _StatCard(
            label: 'Utilisateurs actifs',
            value: '${data.activeUsers}',
            subtitle: '${data.totalUsers} comptes suivis',
        icon: Icons.people_outline,
        gradient: const [Color(0xFF123C38), Color(0xFF0B2423)],
      ),
      _StatCard(
            label: 'Paiements validés',
            value: '${data.validatedPaymentsSummary}',
            subtitle: '${data.pendingPaymentsSummary} en attente',
        icon: Icons.phonelink,
        gradient: const [Color(0xFF2E263E), Color(0xFF15111F)],
      ),
      _StatCard(
            label: 'Volume paiements',
            value: '\$${data.totalPaymentAmount.toStringAsFixed(2)}',
            subtitle: '${data.notificationsCount} notifications envoyées',
        icon: Icons.check_circle_outline,
        gradient: const [Color(0xFF182D3C), Color(0xFF0E1720)],
      ),
      _StatCard(
        label: 'Latence copie',
        value: data.averageCopyLatencyMs == 0 ? 'n/a' : '${data.averageCopyLatencyMs.toStringAsFixed(0)} ms',
        subtitle: '${data.copyPendingTrades} en file',
        icon: Icons.speed_outlined,
        gradient: const [Color(0xFF332C1E), Color(0xFF19140F)],
      ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: stats
          .map(
            (stat) => SizedBox(
              width: isWide ? 250 : (MediaQuery.sizeOf(context).width - 44) / 2,
              child: stat,
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomGrid(BuildContext context, _AdminDashboardData data, bool isWide) {
    final quickActions = [
      _QuickActionCard(
        icon: Icons.payment,
        title: 'Paiements',
        subtitle: 'Listing, validation et refus',
        onTap: () => Navigator.pushNamed(context, '/admin/payments'),
      ),
      _QuickActionCard(
        icon: Icons.notifications,
        title: 'Notifications',
        subtitle: 'Push vers les clients',
        onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
      ),
      _QuickActionCard(
        icon: Icons.star,
        title: 'Gestion VIP',
        subtitle: 'Basculer un client en VIP',
        onTap: () => Navigator.pushNamed(context, '/admin/vip'),
      ),
      _QuickActionCard(
        icon: Icons.sync_alt,
        title: 'Copy Trading',
        subtitle: 'Statut, historique et latence',
        onTap: () => Navigator.pushNamed(context, '/admin/copytrading'),
      ),
      _QuickActionCard(
        icon: Icons.list_alt,
        title: 'Logs',
        subtitle: 'Journal des accès',
        onTap: () => Navigator.pushNamed(context, '/admin/logs'),
      ),
      _QuickActionCard(
        icon: Icons.key,
        title: 'Clés API',
        subtitle: 'Master et client MT5',
        onTap: () => Navigator.pushNamed(context, '/admin/api-keys'),
      ),
    ];

    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(title: 'Quick Actions'),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        children: quickActions,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _GlassCard(
                      child: _RecentUsersList(
                        users: data.recentUsers,
                        onActivate: _activateUser,
                        onSuspend: _suspendUser,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _GlassCard(
                      child: _RecentActivityList(items: _recentActivitiesFrom(data)),
                    ),
                    const SizedBox(height: 16),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle(title: 'Raccourcis techniques'),
                          const SizedBox(height: 12),
                          const _InfoRow(label: 'Backend', value: AppConstants.backendBaseUrl),
                          const SizedBox(height: 8),
                          const _InfoRow(label: 'Admin API', value: AppConstants.adminBaseUrl),
                          const SizedBox(height: 8),
                          _InfoRow(label: 'Admin connecté', value: AdminAuth.adminUsername ?? 'non connecté'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : Column(
            children: [
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(title: 'Quick Actions'),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: MediaQuery.sizeOf(context).width > 640 ? 2 : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.6,
                      children: quickActions,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _GlassCard(
                child: _RecentUsersList(
                  users: data.recentUsers,
                  onActivate: _activateUser,
                  onSuspend: _suspendUser,
                ),
              ),
              const SizedBox(height: 16),
              _GlassCard(
                child: _RecentActivityList(items: _recentActivitiesFrom(data)),
              ),
            ],
          );
  }

  Widget _buildGoalOverview(_AdminDashboardData data, bool isWide) {
    final goalCards = [
      _StatCard(
        label: 'Utilisateurs actifs',
        value: '${data.activeUsers}',
        subtitle: '${data.totalUsers} comptes suivis',
        icon: Icons.calendar_month_outlined,
        gradient: const [Color(0xFF17313A), Color(0xFF0E1E22)],
      ),
      _StatCard(
        label: 'Paiements validés',
        value: '${data.validatedPaymentsSummary}',
        subtitle: '${data.pendingPaymentsSummary} en attente',
        icon: Icons.emoji_events_outlined,
        gradient: const [Color(0xFF2A203F), Color(0xFF15101F)],
      ),
      _StatCard(
        label: 'Volume paiements',
        value: '\$${data.totalPaymentAmount.toStringAsFixed(2)}',
        subtitle: '${data.notificationsCount} notifications envoyées',
        icon: Icons.shield_outlined,
        gradient: const [Color(0xFF242B33), Color(0xFF12171C)],
      ),
    ];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Goal Overview'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: goalCards
                .map(
                  (card) => SizedBox(
                    width: isWide ? 250 : (MediaQuery.sizeOf(context).width - 44) / 1,
                    child: card,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  List<_ActivityItem> _recentActivitiesFrom(_AdminDashboardData data) {
    final activities = <_ActivityItem>[];

    if (data.payments.isNotEmpty) {
      activities.add(_ActivityItem(
        title: 'Paiements chargés',
        subtitle: '${data.payments.length} enregistrements',
        icon: Icons.receipt_long,
        accent: const Color(0xFF3EE7B6),
      ));
    }
    if (data.recentUsers.isNotEmpty) {
      activities.add(_ActivityItem(
        title: 'Utilisateurs suivis',
        subtitle: '${data.recentUsers.length} comptes liés MT5 dans le résumé',
        icon: Icons.people_outline,
        accent: const Color(0xFF9AD7FF),
      ));
    }
    if (data.copytradingHistory.isNotEmpty) {
      activities.add(_ActivityItem(
        title: 'Copy trading',
        subtitle: '${data.copytradingHistory.length} événements historiques',
        icon: Icons.sync_alt,
        accent: const Color(0xFF9AD7FF),
      ));
    }
    if (data.notifications.isNotEmpty) {
      activities.add(_ActivityItem(
        title: 'Notifications',
        subtitle: '${data.notifications.length} messages envoyés',
        icon: Icons.notifications_active_outlined,
        accent: const Color(0xFFFFD66B),
      ));
    }
    if (data.errorsLogs.isNotEmpty) {
      activities.add(_ActivityItem(
        title: 'Erreurs centralisées',
        subtitle: '${data.errorsLogs.length} incidents récents',
        icon: Icons.error_outline,
        accent: const Color(0xFFFF9A9A),
      ));
    }
    if (data.copyFailedTrades > 0) {
      activities.add(_ActivityItem(
        title: 'Échecs copy trading',
        subtitle: '${data.copyFailedTrades} trades en erreur',
        icon: Icons.error_outline,
        accent: const Color(0xFFFF7C7C),
      ));
    }

    if (activities.isEmpty) {
      activities.add(_ActivityItem(
        title: 'Aucune donnée',
        subtitle: 'Le backend répond mais n’a pas encore renvoyé d’activité.',
        icon: Icons.hourglass_empty,
        accent: Colors.white54,
      ));
    }

    return activities.take(4).toList();
  }

  Future<void> _updateUserStatus(String userId, bool activate) async {
    final path = activate ? '/users/activate/$userId' : '/users/suspend/$userId';
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}$path'),
      headers: AdminAuth.headers(),
    );

    if (response.statusCode >= 400) {
      throw Exception('Statut utilisateur non mis à jour');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
  }

  Future<void> _activateUser(String userId) async {
    await _updateUserStatus(userId, true);
  }

  Future<void> _suspendUser(String userId) async {
    await _updateUserStatus(userId, false);
  }

}

class _AdminDashboardData {
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> vipUsers;
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> copytradingHistory;
  final List<Map<String, dynamic>> errorsLogs;
  final List<Map<String, dynamic>> recentUsers;
  final List<Map<String, dynamic>> recentCopytrades;
  final Map<String, dynamic> dispatchCounts;
  final int pendingPayments;
  final int validatedPayments;
  final int refusedPayments;
  final int totalUsers;
  final int activeUsers;
  final int suspendedUsers;
  final int vipUsersCount;
  final int usersWithMt5;
  final int totalAccounts;
  final int activeAccounts;
  final int inactiveAccounts;
  final int masterAccounts;
  final int clientAccounts;
  final int totalPayments;
  final int pendingPaymentsSummary;
  final int validatedPaymentsSummary;
  final int refusedPaymentsSummary;
  final double totalPaymentAmount;
  final int signalsTotal;
  final int copiedTradesTotal;
  final int copyExecutedTrades;
  final int copyFailedTrades;
  final int copyPendingTrades;
  final int copyRetryTrades;
  final double averageCopyLatencyMs;
  final int notificationsCount;
  final int supportTicketsCount;
  final int openTicketsCount;
  final int activitySignalsCount;

  const _AdminDashboardData({
    required this.payments,
    required this.notifications,
    required this.vipUsers,
    required this.logs,
    required this.copytradingHistory,
    required this.errorsLogs,
    required this.recentUsers,
    required this.recentCopytrades,
    required this.dispatchCounts,
    required this.pendingPayments,
    required this.validatedPayments,
    required this.refusedPayments,
    required this.totalUsers,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.vipUsersCount,
    required this.usersWithMt5,
    required this.totalAccounts,
    required this.activeAccounts,
    required this.inactiveAccounts,
    required this.masterAccounts,
    required this.clientAccounts,
    required this.totalPayments,
    required this.pendingPaymentsSummary,
    required this.validatedPaymentsSummary,
    required this.refusedPaymentsSummary,
    required this.totalPaymentAmount,
    required this.signalsTotal,
    required this.copiedTradesTotal,
    required this.copyExecutedTrades,
    required this.copyFailedTrades,
    required this.copyPendingTrades,
    required this.copyRetryTrades,
    required this.averageCopyLatencyMs,
    required this.notificationsCount,
    required this.supportTicketsCount,
    required this.openTicketsCount,
    required this.activitySignalsCount,
  });

  factory _AdminDashboardData.empty() {
    return const _AdminDashboardData(
      payments: [],
      notifications: [],
      vipUsers: [],
      logs: [],
      copytradingHistory: [],
      errorsLogs: [],
      recentUsers: [],
      recentCopytrades: [],
      dispatchCounts: {},
      pendingPayments: 0,
      validatedPayments: 0,
      refusedPayments: 0,
      totalUsers: 0,
      activeUsers: 0,
      suspendedUsers: 0,
      vipUsersCount: 0,
      usersWithMt5: 0,
      totalAccounts: 0,
      activeAccounts: 0,
      inactiveAccounts: 0,
      masterAccounts: 0,
      clientAccounts: 0,
      totalPayments: 0,
      pendingPaymentsSummary: 0,
      validatedPaymentsSummary: 0,
      refusedPaymentsSummary: 0,
      totalPaymentAmount: 0,
      signalsTotal: 0,
      copiedTradesTotal: 0,
      copyExecutedTrades: 0,
      copyFailedTrades: 0,
      copyPendingTrades: 0,
      copyRetryTrades: 0,
      averageCopyLatencyMs: 0,
      notificationsCount: 0,
      supportTicketsCount: 0,
      openTicketsCount: 0,
      activitySignalsCount: 0,
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar();

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItemData(icon: Icons.dashboard, label: 'Dashboard', onTap: () => Navigator.pushReplacementNamed(context, '/admin/dashboard')),
      _SidebarItemData(icon: Icons.payment, label: 'Paiements', onTap: () => Navigator.pushNamed(context, '/admin/payments')),
      _SidebarItemData(icon: Icons.notifications, label: 'Notifications', onTap: () => Navigator.pushNamed(context, '/admin/notifications')),
      _SidebarItemData(icon: Icons.star, label: 'Gestion VIP', onTap: () => Navigator.pushNamed(context, '/admin/vip')),
      _SidebarItemData(icon: Icons.sync_alt, label: 'Copy Trading', onTap: () => Navigator.pushNamed(context, '/admin/copytrading')),
      _SidebarItemData(icon: Icons.key, label: 'Clés API', onTap: () => Navigator.pushNamed(context, '/admin/api-keys')),
      _SidebarItemData(icon: Icons.list_alt, label: 'Logs', onTap: () => Navigator.pushNamed(context, '/admin/logs')),
      _SidebarItemData(icon: Icons.help_outline, label: 'Help Center', onTap: () {}),
      _SidebarItemData(icon: Icons.public, label: 'Back to Website', onTap: () => Navigator.pushReplacementNamed(context, '/')),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF0D141A).withOpacity(0.92),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [const Color(AppConstants.primaryColor), const Color(AppConstants.primaryColor).withOpacity(0.4)],
                  ),
                ),
                child: const Icon(Icons.show_chart, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FrappedDollars', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('Admin Control', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SidebarSectionTitle('Navigation'),
          const SizedBox(height: 10),
          ...items.map((item) => _SidebarTile(data: item)),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.03),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                const Icon(Icons.dark_mode_outlined, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Dark Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                Container(
                  width: 34,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(AppConstants.primaryColor).withOpacity(0.55),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SidebarSectionTitle('Session'),
          const SizedBox(height: 10),
          _SidebarTile(
            data: _SidebarItemData(
              icon: Icons.logout,
              label: 'Déconnexion',
              onTap: () => AdminAuth.logout().then((_) => Navigator.pushReplacementNamed(context, '/admin/login')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _SidebarItemData({required this.icon, required this.label, required this.onTap});
}

class _SidebarTile extends StatelessWidget {
  final _SidebarItemData data;

  const _SidebarTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: data.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.03),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Icon(data.icon, color: Colors.white70, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  final bool isWide;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _AdminTopBar({required this.isWide, required this.isLoading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!isWide)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        if (!isWide) const SizedBox(width: 4),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Supervision du paiement, copy trading, VIP et logs', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
        if (isWide)
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Colors.white54, size: 18),
                  SizedBox(width: 10),
                  Text('Search', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          ),
        if (isWide) ...[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: const Icon(Icons.notifications_none, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 10),
        ],
        IconButton(
          onPressed: onRefresh,
          icon: Icon(isLoading ? Icons.sync : Icons.refresh, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(AppConstants.primaryColor),
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AdminAuth.adminUsername ?? 'Admin',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Admin Account',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: gradient),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              const Icon(Icons.trending_up, color: Colors.white54, size: 18),
            ],
          ),
          const Spacer(),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(AppConstants.primaryColor).withOpacity(0.12),
                ),
                child: Icon(icon, color: const Color(AppConstants.primaryColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<_ActivityItem> items;

  const _RecentActivityList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Recent Activity'),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ActivityTile(item: item),
          ),
        ),
      ],
    );
  }
}

class _RecentUsersList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final Future<void> Function(String userId) onActivate;
  final Future<void> Function(String userId) onSuspend;

  const _RecentUsersList({
    required this.users,
    required this.onActivate,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Utilisateurs enregistrés'),
        const SizedBox(height: 12),
        if (users.isEmpty)
          const Text(
            'Aucun utilisateur trouvé dans le dashboard admin.',
            style: TextStyle(color: Colors.white54),
          )
        else
          ...users.map(
            (user) {
              final userId = user['id']?.toString() ?? '';
              final mt5Logins = List<String>.from(user['mt5_logins'] as List? ?? const []);
              final isSuspended = (user['role']?.toString().toUpperCase() ?? '') == 'SUSPENDED';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withOpacity(0.03),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(AppConstants.primaryColor).withOpacity(0.12),
                            ),
                            child: const Icon(Icons.person, color: Color(AppConstants.primaryColor)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['full_name']?.toString().isNotEmpty == true ? user['full_name'].toString() : user['email']?.toString() ?? 'Utilisateur',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${user['email'] ?? ''}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(label: isSuspended ? 'SUSPENDED' : 'ACTIVE'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        mt5Logins.isEmpty ? 'Aucun login MT5 lié' : 'MT5: ${mt5Logins.join(' • ')}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MetricPill(label: 'Accounts', value: '${user['active_trading_accounts'] ?? 0}'),
                          const SizedBox(width: 8),
                          _MetricPill(label: 'VIP', value: '${user['is_vip'] == true ? 1 : 0}'),
                          const Spacer(),
                          TextButton(
                            onPressed: userId.isEmpty
                                ? null
                                : () => isSuspended ? onActivate(userId) : onSuspend(userId),
                            child: Text(isSuspended ? 'Activer' : 'Suspendre'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  _ActivityItem({required this.title, required this.subtitle, required this.icon, required this.accent});
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.accent.withOpacity(0.15),
            ),
            child: Icon(item.icon, color: item.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700));
  }
}

class _SidebarSectionTitle extends StatelessWidget {
  final String title;

  const _SidebarSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.1)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white54))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _AnalysisRow({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ActionLine extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionLine({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.03),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3EE7B6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF3EE7B6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(AppConstants.primaryColor).withOpacity(0.12),
        border: Border.all(color: const Color(AppConstants.primaryColor).withOpacity(0.35)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
