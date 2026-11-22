// Developed by @Ramana Code Softwares

class AppStrings {
  const AppStrings(this.isTelugu);

  final bool isTelugu;

  String get appName => 'DrivePro';
  String get dashboard => isTelugu ? 'డాష్‌బోర్డ్' : 'Dashboard';
  String get students => isTelugu ? 'విద్యార్థులు' : 'Students';
  String get instructors => isTelugu ? 'శిక్షకులు' : 'Instructors';
  String get schedule => isTelugu ? 'షెడ్యూల్' : 'Schedule';
  String get payments => isTelugu ? 'చెల్లింపులు' : 'Payments';

  String get totalStudents =>
      isTelugu ? 'మొత్తం విద్యార్థులు' : 'Total Students';

  String get activeInstructors =>
      isTelugu ? 'యాక్టివ్ శిక్షకులు' : 'Active Instructors';

  String get todayLessons => isTelugu ? 'నేటి క్లాసులు' : "Today's Lessons";

  String get pendingFees => isTelugu ? 'పెండింగ్ ఫీజులు' : 'Pending Fees';

  String get recentActivity =>
      isTelugu ? 'ఇటీవలి కార్యకలాపాలు' : 'Recent Activity';

  String get welcome => isTelugu ? 'స్వాగతం!' : 'Welcome!';

  String get overview => isTelugu
      ? 'మీ డ్రైవింగ్ స్కూల్ వివరాలు ఇక్కడ చూడండి.'
      : 'Here is your driving school overview.';

  String get searchStudents =>
      isTelugu ? 'విద్యార్థులను వెతకండి' : 'Search students';

  String get addStudent => isTelugu ? 'విద్యార్థిని చేర్చండి' : 'Add student';

  String get save => isTelugu ? 'సేవ్ చేయండి' : 'Save';
  String get cancel => isTelugu ? 'రద్దు చేయండి' : 'Cancel';
  String get name => isTelugu ? 'పూర్తి పేరు' : 'Full name';
  String get phone => isTelugu ? 'ఫోన్ నంబర్' : 'Phone number';
  String get email => isTelugu ? 'ఈమెయిల్' : 'Email';
  String get course => isTelugu ? 'కోర్సు' : 'Course';
  String get totalFee => isTelugu ? 'మొత్తం ఫీజు' : 'Total fee';
  String get paidFee => isTelugu ? 'చెల్లించిన ఫీజు' : 'Paid fee';
  String get status => isTelugu ? 'స్థితి' : 'Status';
  String get active => isTelugu ? 'యాక్టివ్' : 'Active';
  String get archived => isTelugu ? 'ఆర్కైవ్' : 'Archived';
  String get language => isTelugu ? 'తెలుగు' : 'English';
  String get signIn => isTelugu ? 'లాగిన్' : 'Sign in';
  String get password => isTelugu ? 'పాస్‌వర్డ్' : 'Password';
  String get signOut => isTelugu ? 'లాగ్ అవుట్' : 'Sign out';
}
