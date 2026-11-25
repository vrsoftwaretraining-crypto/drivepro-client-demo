// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/school_service.dart';
import '../../schedule/presentation/public_slots_section.dart';
import 'forgot_password_dialog.dart';
import '../../../core/services/backend.dart';

/// Public-facing DrivePro website. Authentication is presented in a centred
/// modal, following the interaction pattern used by the Nari Shakthi website.
class PublicLandingPage extends StatefulWidget {
  const PublicLandingPage({super.key});

  @override
  State<PublicLandingPage> createState() => _PublicLandingPageState();
}

class _PublicLandingPageState extends State<PublicLandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _storiesKey = GlobalKey();
  final GlobalKey _slotsKey = GlobalKey();
  bool _scrolled = false;

  static const _plum = Color(0xFF5C1738);
  static const _plumLight = Color(0xFF8D315B);
  static const _gold = Color(0xFFE4AE45);
  static const _cream = Color(0xFFFFF8EF);
  static const _ink = Color(0xFF2C2430);

  @override
  void initState() {
    super.initState();
    _ensureDefaultAdmin();
    _scrollController.addListener(() {
      final value = _scrollController.offset > 35;
      if (value != _scrolled && mounted) setState(() => _scrolled = value);
    });
  }

  /// Creates the default admin (admin / Admin@12345) once, if none exists.
  Future<void> _ensureDefaultAdmin() async {
    try {
      await SchoolService.ensureDefaultAdmin();
    } catch (_) {
      // Non-fatal: the public site must still load.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _go(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,);
    }
  }

  /// "Book" buttons scroll to the live slot list (slots the admin created in the Schedule module).
  void _openBooking() => _go(_slotsKey);

  void _openLogin(String role) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: .58),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470, maxHeight: 680),
          child: _DriveProLoginDialog(
            role: role,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                _hero(),
                Container(key: _slotsKey, child: const PublicSlotsSection()),
                Container(key: _aboutKey, child: _about()),
                Container(key: _storiesKey, child: _trainingHighlights()),
                _footer(),
              ],
            ),
          ),
          _navigation(),
        ],
      ),
    );
  }

  Widget _navigation() {
    final solid = _scrolled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: solid ? Colors.white.withValues(alpha: .97) : _plum.withValues(alpha: .18),
        border: solid
            ? const Border(bottom: BorderSide(color: _gold, width: 1.5))
            : null,
        boxShadow: solid
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: .10),
                    blurRadius: 18,
                    offset: const Offset(0, 5),),
              ]
            : null,
      ),
      child: Row(children: [
        InkWell(
          onTap: () => _go(_homeKey),
          child: Row(children: [
            Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_gold, _plumLight]),),
                child: const Icon(Icons.directions_car_filled_rounded,
                    color: Colors.white, size: 25,),),
            const SizedBox(width: 11),
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DrivePro',
                      style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: solid ? _plum : Colors.white,),),
                  Text('DRIVING SCHOOL',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 3.2,
                          fontWeight: FontWeight.w800,
                          color: solid ? _plumLight : _gold,),),
                ],),
          ],),
        ),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width > 760) ...[
          _navText('Home', solid, () => _go(_homeKey)),
          _navText('About us', solid, () => _go(_aboutKey)),
          _navText('Success stories', solid, () => _go(_storiesKey)),
          _navText('Book a lesson', solid, _openBooking),
          const SizedBox(width: 12),
          _navLogin(solid),
        ] else
          PopupMenuButton<String>(
            icon: Icon(Icons.menu, color: solid ? _plum : Colors.white),
            onSelected: (value) {
              if (value == 'home') _go(_homeKey);
              if (value == 'about') _go(_aboutKey);
              if (value == 'stories') _go(_storiesKey);
              if (value == 'booking') _openBooking();
              if (value == 'login') _openLogin('student');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'home', child: Text('Home')),
              PopupMenuItem(value: 'about', child: Text('About us')),
              PopupMenuItem(value: 'stories', child: Text('Success stories')),
              PopupMenuItem(value: 'booking', child: Text('Book a lesson')),
              PopupMenuItem(value: 'login', child: Text('Login')),
            ],
          ),
      ],),
    );
  }

  Widget _navText(String text, bool solid, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Text(text,
            style: TextStyle(
                color: solid ? _plum : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,),),
      );

  Widget _navLogin(bool solid) => ElevatedButton.icon(
        onPressed: () => _openLogin('student'),
        icon: const Icon(Icons.login, size: 18),
        label: const Text('Login'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _plum,
          padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 15),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );

  Widget _hero() => SizedBox(
        key: _homeKey,
        height: MediaQuery.sizeOf(context).width < 700 ? 720 : 760,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          const _NetworkPhoto(
              'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?auto=format&fit=crop&w=2000&q=85',),
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                _plum.withValues(alpha: .96),
                _plum.withValues(alpha: .78),
                _plum.withValues(alpha: .24),
              ],),),),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 110, 34, 36),
                child: LayoutBuilder(builder: (context, box) {
                  final compact = box.maxWidth < 760;
                  final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('LEARN • PRACTISE • DRIVE WITH CONFIDENCE',
                            style: TextStyle(
                                color: _gold,
                                fontSize: 12,
                                letterSpacing: 2.8,
                                fontWeight: FontWeight.w800,),),
                        const SizedBox(height: 22),
                        Text('Your journey to confident driving starts here.',
                            style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: compact ? 42 : 58,
                                fontWeight: FontWeight.bold,
                                height: 1.12,
                                color: Colors.white,),),
                        const SizedBox(height: 20),
                        Text(
                            'Professional driving instruction, practical road experience and a learning plan designed around you.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .9),
                                fontSize: 17,
                                height: 1.7,),),
                        const SizedBox(height: 30),
                        Wrap(spacing: 14, runSpacing: 12, children: [
                          _goldButton(
                              'Explore our school', () => _go(_aboutKey),),
                          OutlinedButton.icon(
                            onPressed: _openBooking,
                            icon: const Icon(Icons.event_available_outlined),
                            label: const Text('Book a lesson'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white, width: 1.4),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
                            ),
                          ),
                          OutlinedButton.icon(
                              onPressed: () => _openLogin('student'),
                              icon: const Icon(Icons.school_outlined),
                              label: const Text('Student login'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                      color: Colors.white, width: 1.4,),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22, vertical: 17,),),),
                        ],),
                      ],);
                  if (compact) return copy;
                  return Row(children: [
                    Expanded(flex: 6, child: copy),
                    const Spacer(flex: 4),
                  ],);
                },),
              ),
            ),
          ),
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                  height: 105,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                        Colors.transparent,
                        _cream.withValues(alpha: .96),
                      ],),),),),
        ],),
      );

  Widget _about() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 86),
        color: _cream,
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(children: [
                  _sectionHeading(
                      'ABOUT DRIVEPRO',
                      'A better way to learn driving',
                      'A welcoming learning environment with clear instruction, patient guidance and practical driving experience.',),
                  const SizedBox(height: 46),
                  LayoutBuilder(builder: (context, c) {
                    final narrow = c.maxWidth < 760;
                    final photo = ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: SizedBox(
                            height: narrow ? 260 : 390,
                            width: narrow ? double.infinity : 500,
                            child: const _NetworkPhoto(
                                'https://images.unsplash.com/photo-1489824904134-891ab64532f1?auto=format&fit=crop&w=1200&q=85',),),);
                    final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'Training built around real roads and real confidence',
                              style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: _plum,
                                  height: 1.2,),),
                          const SizedBox(height: 16),
                          const Text(
                              'DrivePro helps new and improving drivers build safe habits step by step. Learn vehicle controls, road awareness, parking, traffic rules and defensive driving with structured lessons.',
                              style: TextStyle(
                                  fontSize: 16, height: 1.75, color: _ink,),),
                          const SizedBox(height: 24),
                          _featureLine(Icons.verified_user_outlined,
                              'Safety-first training and road awareness',),
                          _featureLine(Icons.event_available_outlined,
                              'Structured lessons and progress tracking',),
                          _featureLine(Icons.support_agent_outlined,
                              'Guidance from experienced instructors',),
                          _featureLine(Icons.directions_car_outlined,
                              'Practical vehicle handling and parking practice',),
                        ],);
                    return narrow
                        ? Column(children: [
                            photo,
                            const SizedBox(height: 30),
                            details,
                          ],)
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                photo,
                                const SizedBox(width: 54),
                                Expanded(child: details),
                              ],);
                  },),
                  const SizedBox(height: 58),
                  Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      alignment: WrapAlignment.center,
                      children: [
                        _featureCard(Icons.school_outlined, 'Student focused',
                            'Lessons and progress designed around each learner.',),
                        _featureCard(Icons.route_outlined, 'Practical learning',
                            'Build confidence through guided driving practice.',),
                        _featureCard(
                            Icons.admin_panel_settings_outlined,
                            'Organised support',
                            'A connected system for students, instructors and admins.',),
                      ],),
                ],),),),
      );

  Widget _trainingHighlights() => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 86),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(children: [
                  _sectionHeading(
                      'SUCCESS STORIES',
                      'Every confident driver starts with a lesson',
                      'A glimpse of the skills learners work towards during their DrivePro training journey.',),
                  const SizedBox(height: 42),
                  LayoutBuilder(builder: (context, c) {
                    final width =
                        c.maxWidth < 650 ? c.maxWidth : (c.maxWidth - 36) / 3;
                    return Wrap(spacing: 18, runSpacing: 18, children: [
                      _storyCard(
                          width,
                          '01',
                          'First time behind the wheel',
                          'Get comfortable with the controls, mirrors, steering and smooth starts.',
                          'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=900&q=85',),
                      _storyCard(
                          width,
                          '02',
                          'Building road confidence',
                          'Practise lane discipline, turns, traffic awareness and safe decision-making.',
                          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=900&q=85',),
                      _storyCard(
                          width,
                          '03',
                          'Ready for the road',
                          'Develop parking skills, defensive driving habits and confidence on everyday routes.',
                          'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=900&q=85',),
                    ],);
                  },),
                  const SizedBox(height: 42),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _goldButton('Request a lesson', _openBooking),
                      OutlinedButton(
                        onPressed: () => _openLogin('student'),
                        child: const Text('Student login'),
                      ),
                    ],
                  ),
                ],),),),
      );

  Future<void> _openExternal(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _footer() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: Backend.firestore.collection('public_info').doc('school').snapshots(),
        builder: (context, snapshot) {
          final school = snapshot.data?.data() ?? <String, dynamic>{};
          final schoolName = (school['name'] as String?)?.trim().isNotEmpty == true
              ? school['name'] as String
              : 'DrivePro Driving School';
          final phone = (school['phone'] as String? ?? '').trim();
          final alternate = (school['alternatePhone'] as String? ?? '').trim();
          final email = (school['email'] as String? ?? '').trim();
          final address = (school['address'] as String? ?? '').trim();
          final location = (school['location'] as String? ?? '').trim();
          final mapUrl = (school['mapUrl'] as String? ?? '').trim();
          final facebook = (school['facebookUrl'] as String? ?? '').trim();
          final instagram = (school['instagramUrl'] as String? ?? '').trim();
          final website = (school['websiteUrl'] as String? ?? '').trim();
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 52, 28, 30),
            color: _plum,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Column(children: [
                    const Icon(Icons.directions_car_filled_rounded, color: _gold, size: 40),
                    const SizedBox(height: 12),
                    Text(schoolName, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Georgia', color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 7),
                    const Text('Learn safely. Drive confidently.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  ])),
                  const SizedBox(height: 34),
                  LayoutBuilder(builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    final contact = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('CONTACT US', style: TextStyle(color: _gold, fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 18),
                      if (address.isNotEmpty) _contactLine(Icons.location_on_outlined, address),
                      if (location.isNotEmpty) _contactLine(Icons.place_outlined, location),
                      if (phone.isNotEmpty) _contactAction(Icons.phone_outlined, phone, () => _openExternal('tel:$phone')),
                      if (alternate.isNotEmpty) _contactAction(Icons.phone_in_talk_outlined, alternate, () => _openExternal('tel:$alternate')),
                      if (email.isNotEmpty) _contactAction(Icons.email_outlined, email, () => _openExternal('mailto:$email')),
                      if (mapUrl.isNotEmpty) _contactAction(Icons.directions_outlined, 'View route on Google Maps', () => _openExternal(mapUrl)),
                      if (facebook.isNotEmpty || instagram.isNotEmpty || website.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 10, runSpacing: 8, children: [
                          if (facebook.isNotEmpty) _socialButton('Facebook', Icons.facebook, () => _openExternal(facebook)),
                          if (instagram.isNotEmpty) _socialButton('Instagram', Icons.camera_alt_outlined, () => _openExternal(instagram)),
                          if (website.isNotEmpty) _socialButton('Website', Icons.language, () => _openExternal(website)),
                        ]),
                      ],
                      if (address.isEmpty && phone.isEmpty && email.isEmpty && mapUrl.isEmpty) const Text('School contact details will appear here after the administrator saves them.', style: TextStyle(color: Colors.white60, height: 1.5)),
                    ]);
                    final logins = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('QUICK ACCESS', style: TextStyle(color: _gold, fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _footerLogin('Admin login', 'admin'),
                      _footerLogin('Instructor login', 'instructor'),
                      _footerLogin('Student login', 'student'),
                    ]);
                    if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [contact, const SizedBox(height: 30), logins]);
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: contact), const SizedBox(width: 50), Expanded(child: logins)]);
                  }),
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  const Center(child: Text('© DrivePro. All rights reserved.', style: TextStyle(color: Colors.white60, fontSize: 12))),
                ]),
              ),
            ),
          );
        },
      );

  Widget _contactLine(IconData icon, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _gold, size: 19), const SizedBox(width: 12), Expanded(child: Text(value, style: const TextStyle(color: Colors.white, height: 1.5)))]),
      );

  Widget _contactAction(IconData icon, String value, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: InkWell(onTap: onTap, child: Row(children: [Icon(icon, color: _gold, size: 19), const SizedBox(width: 12), Expanded(child: Text(value, style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white54)))])),
      );

  Widget _socialButton(String label, IconData icon, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
      );

  Widget _footerLogin(String label, String role) => TextButton(
      onPressed: () => _openLogin(role),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600,),),);

  Widget _sectionHeading(String eyebrow, String title, String subtitle) =>
      Column(children: [
        Text(eyebrow,
            style: const TextStyle(
                color: _plumLight,
                letterSpacing: 3.2,
                fontSize: 12,
                fontWeight: FontWeight.w800,),),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: _plum,
                height: 1.2,),),
        const SizedBox(height: 12),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, color: Colors.black54, height: 1.65,),),),
      ],);

  Widget _featureLine(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: _gold.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(12),),
            child: Icon(icon, color: _plum),),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _ink,),),),
      ],),);

  Widget _featureCard(IconData icon, String title, String text) => SizedBox(
      width: 350,
      child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withValues(alpha: .45)),
              boxShadow: [
                BoxShadow(
                    color: _plum.withValues(alpha: .06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),),
              ],),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 50,
                height: 50,
                decoration:
                    const BoxDecoration(color: _plum, shape: BoxShape.circle),
                child: Icon(icon, color: _gold, size: 25),),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: _plum, fontWeight: FontWeight.w800, fontSize: 18,),),
            const SizedBox(height: 8),
            Text(text,
                style: const TextStyle(color: Colors.black54, height: 1.5),),
          ],),),);

  Widget _storyCard(double width, String number, String title, String text,
          String image,) =>
      SizedBox(
          width: width,
          child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _gold.withValues(alpha: .4)),),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        height: 205,
                        width: double.infinity,
                        child: _NetworkPhoto(image),),
                    Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TRAINING MILESTONE $number',
                                  style: const TextStyle(
                                      color: _plumLight,
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w800,),),
                              const SizedBox(height: 9),
                              Text(title,
                                  style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      color: _plum,
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,),),
                              const SizedBox(height: 9),
                              Text(text,
                                  style: const TextStyle(
                                      color: Colors.black54, height: 1.55,),),
                            ],),),
                  ],),),);

  Widget _goldButton(String label, VoidCallback onTap) => ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _plum,
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 18),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          elevation: 0,),
      child: Text(label),);
}

class _NetworkPhoto extends StatelessWidget {
  const _NetworkPhoto(this.url);
  final String url;
  @override
  Widget build(BuildContext context) => Image.network(url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: const Color(0xFFE9E0D8),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),),
      errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF6D2948),
          alignment: Alignment.center,
          child: const Icon(Icons.directions_car_filled_rounded,
              color: Colors.white70, size: 64,),),);
}

class _DriveProLoginDialog extends ConsumerStatefulWidget {
  const _DriveProLoginDialog({required this.role, required this.onClose});
  final String role;
  final VoidCallback onClose;
  @override
  ConsumerState<_DriveProLoginDialog> createState() =>
      _DriveProLoginDialogState();
}

class _DriveProLoginDialogState extends ConsumerState<_DriveProLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  late String _selectedRole;
  String? _error;

  static const _plum = Color(0xFF5C1738);
  static const _gold = Color(0xFFE4AE45);

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.role;
  }

  String get _roleLabel => switch (_selectedRole) {
        'admin' => 'Administrator',
        'instructor' => 'Instructor',
        _ => 'Student',
      };

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var loginEmail = _email.text.trim();
      loginEmail = await SchoolService.resolveEmail(loginEmail);
      final credential = await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(
              email: loginEmail, password: _password.text,);
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase did not return a signed-in user.');
      }
      final snapshot = await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .get();
      if (!snapshot.exists || snapshot.data() == null) {
        await ref.read(firebaseAuthProvider).signOut();
        throw StateError(
            'Your user profile was not found. Please contact the school administrator.',);
      }
      final data = snapshot.data()!;
      final actualRole = (data['role'] as String? ?? 'student').toLowerCase();
      if (actualRole != _selectedRole) {
        await ref.read(firebaseAuthProvider).signOut();
        throw StateError(
            'This account is registered as ${actualRole.toUpperCase()}. Please choose the correct login option.',);
      }
      if (data['active'] != true) {
        await ref.read(firebaseAuthProvider).signOut();
        throw StateError(
            'Your account is inactive. Please contact the school administrator.',);
      }
      widget.onClose();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'invalid-email' => 'Please enter a valid email address.',
            'user-not-found' ||
            'wrong-password' ||
            'invalid-credential' =>
              'Email or password is incorrect.',
            'user-disabled' => 'This account has been disabled.',
            'too-many-requests' => 'Too many attempts. Please try again later.',
            _ => e.message ?? 'Unable to sign in. Please try again.',
          },);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFFFF9F2),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
              child: Form(
                  key: _formKey,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.directions_car_filled_rounded,
                            color: _plum, size: 42,),
                        const SizedBox(height: 8),
                        const Text('DrivePro',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: _plum,),),
                        const Text('DRIVING SCHOOL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _gold,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,),),
                        const SizedBox(height: 20),
                        Text('$_roleLabel Login',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 21,
                                color: _plum,
                                fontWeight: FontWeight.w800,),),
                        const SizedBox(height: 7),
                        const Text('Welcome back. Sign in to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                              labelText: 'Login as',
                              prefixIcon: Icon(Icons.badge_outlined),),
                          items: const [
                            DropdownMenuItem(
                                value: 'admin', child: Text('Administrator'),),
                            DropdownMenuItem(
                                value: 'instructor', child: Text('Instructor'),),
                            DropdownMenuItem(
                                value: 'student', child: Text('Student'),),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                    if (value != null) _selectedRole = value;
                                    _error = null;
                                  }),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                                labelText: 'Username or email',
                                prefixIcon: Icon(Icons.person_outline),),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter your username or email.'
                                : null,),
                        const SizedBox(height: 15),
                        TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(_obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,),),),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Password is required.'
                                : null,),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(12),),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13,),),),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                                onPressed: _busy ? null : _signIn,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,),)
                                    : const Icon(Icons.login),
                                label:
                                    Text(_busy ? 'Signing in...' : 'Sign in'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _plum,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.w800,),),),),
                        const SizedBox(height: 6),
                        TextButton(
                            onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => const ForgotPasswordDialog(),),
                            child: const Text('Forgot password?',
                                style: TextStyle(
                                    color: _plum,
                                    fontWeight: FontWeight.w700,),),),
                        TextButton(
                            onPressed: widget.onClose,
                            child: const Text('Back to website',
                                style: TextStyle(
                                    color: _plum,
                                    fontWeight: FontWeight.w700,),),),
                      ],),),),
          Positioned(
              top: 5,
              right: 5,
              child: IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: _plum),),),
        ],),
      );
}
