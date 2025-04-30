import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:giffy_dialog/giffy_dialog.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

// partie 1
AudioPlayer audioPlayer = AudioPlayer(); // تعريف مشغل الصوت

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(
    NotificationResponse notificationResponse) async {
  // التعامل مع الضغط على الزر عندما يكون التطبيق في الخلفية أو مغلق
  if (notificationResponse.actionId == 'close_action') {
    await audioPlayer.stop();
    print('تم الضغط على زر إغلاق في الخلفية');
  }
}

// التحقق من حالة "تحسين البطارية"
class BatteryOptimizationHelper {
  static const platform = MethodChannel('com.example.adhane_officiel/battery');

  static Future<void> checkAndRequestDisableBatteryOptimization(
      BuildContext dialogContext) async {
    if (Platform.isAndroid) {
      try {
        final bool isIgnoring =
            await platform.invokeMethod('isIgnoringBatteryOptimizations');
        if (!isIgnoring) {
          await showDialog(
            context: dialogContext,
            builder: (BuildContext context) {
              return GiffyDialog.image(
                Image.asset(
                  "image/notification.png",
                  height: 200,
                  fit: BoxFit.contain,
                ),
                title: const Text(
                  'إذن تحسين البطارية',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                content: const Text(
                  '.لضمان تشغيل الأذان في وقته وعدم تفويت الإشعارات، يرجى استثناء التطبيق من تحسينات البطارية',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context); // الرجوع إلى الصفحة السابقة
                          } else {
                            SystemNavigator.pop(); // إغلاق التطبيق
                          } // إغلاق الحوار
                        }, // إغلاق الحوار
                        child: const Text(
                          'لاحقًا',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () async {
                          await platform
                              .invokeMethod('openBatteryOptimizationSettings');
                          Navigator.pop(context);
                        }, // إغلاق الحوار
                        child: const Text(
                          'فتح الإعدادات',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        }
      } on PlatformException catch (e) {
        print("Error checking battery optimization: ${e.message}");
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialiser le service de fond
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await notificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (response) {
      print('تم النقر على الإشعار: ${response.payload}');
      if (response.actionId == 'close_action') {
        audioPlayer.stop();
      }
    },
    onDidReceiveBackgroundNotificationResponse:
        onDidReceiveBackgroundNotificationResponse,
  );

  runApp(MyApp());
}

// Initialiser le service de fond
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

// Fonction exécutée dans le service de fond
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('playAdhan').listen((event) async {
      final prayerName = event?['prayerName'] ?? 'الصلاة';

      service.setForegroundNotificationInfo(
        title: 'أذان $prayerName',
        content: 'جاري تشغيل أذان $prayerName',
      );
      await audioPlayer.play(AssetSource('adhane/adhan.mp3'));
    });
  }
}

const myBackgroundJob = "myBackgroundJob";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final prayerName = inputData?['prayerName'] ?? 'الصلاة';
    print("🔔 الأذان لصلاة $prayerName ");

    // Play Adhan sound
    await audioPlayer.play(AssetSource('adhane/adhan.mp3'));

    // Show notification
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'adhan_channel',
      'أذان الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'close_action',
          'إغلاق',
          icon: DrawableResourceAndroidBitmap('stop_7826834'),
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await notificationsPlugin.show(
      0,
      'أذان $prayerName',
      'حان الآن وقت $prayerName',
      notificationDetails,
      payload: 'stop_7826834',
    );

    return Future.value(true);
  });
}

Future<void> _showPrayerNotification(String prayerName) async {
  audioPlayer.setReleaseMode(ReleaseMode.stop);

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'adhan_channel',
    'أذان الصلاة',
    importance: Importance.max,
    priority: Priority.high,
    playSound: false,
    enableVibration: true,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(
        'close_action',
        'إغلاق',
        icon: DrawableResourceAndroidBitmap('stop_7826834'),
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ],
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  notificationsPlugin.show(
    0,
    'أذان $prayerName',
    'حان الآن وقت $prayerName',
    notificationDetails,
    payload: 'stop_7826834',
  );
  await audioPlayer.play(AssetSource('adhane/adhan.mp3'));
}

Future<void> schedulePrayerNotifications(
    Map<String, dynamic> prayerTimes) async {
  final now = DateTime.now();
  for (var entry in prayerTimes.entries) {
    final prayerName = entry.key;
    final time = entry.value;
    DateTime prayerTime = DateFormat("HH:mm").parse(time);
    final delay = prayerTime.difference(now);
    if (delay.inSeconds > 0) {
      final uniqueTaskName =
          'adhan_${prayerName}_${prayerTime.toIso8601String()}';
      Workmanager().registerOneOffTask(
        uniqueTaskName,
        myBackgroundJob,
        inputData: {'prayerName': prayerName},
        initialDelay: delay,
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
        ),
      );
    }
  }
}

//

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(360, 690), // مقاسات التصميم
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.system,
          home: PrayerTimesScreen(),
        );
      },
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  @override
  _PrayerTimesScreenState createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  String hijriDate = "جاري التحميل...";
  String hijriDate2 = "جاري التحميل...";
  String hijriDate3 = "جاري التحميل...";
  String hijriDate4 = "جاري التحميل...";
  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  Set<String> activeNotifications = {};
  Map<String, dynamic> prayerTimes = {};
  String nextPrayer = "جاري الحساب...";
  String timeRemaining = "00:00:00";
  bool isLoadingo = true;
  bool isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    BatteryOptimizationHelper.checkAndRequestDisableBatteryOptimization(
        context);
    checkInternetConnection(context);
    loadSavedNotifications();
    fetchPrayerTimes();
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        isLoadingo = false;
      });
    });

    // ...
    _timer = Timer.periodic(Duration(days: 1), (timer) {
      fetchPrayerTimes();
    });
  }
  //

  //

  Future<void> checkInternetConnection(BuildContext dialogContext) async {
    bool isConnected = await isInternetAvailable();

    if (!isConnected && context.mounted) {
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return GiffyDialog.image(
            Image.asset(
              "image/freepik__retouch__78676.png",
              height: 200,
              fit: BoxFit.contain,
            ),
            title: Text(
              'اتصال الإنترنت مفقود',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك.',
              style: TextStyle(fontSize: 18.sp),
              textAlign: TextAlign.center,
            ),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () {
                            AppSettings.openAppSettings(
                              type: AppSettingsType.wifi,
                            );
                            Navigator.pop(dialogContext);
                          },
                          child: const Text(
                            'WiFi إعدادات',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      Flexible(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () {
                            AppSettings.openAppSettings(
                              type: AppSettingsType.dataRoaming,
                            );
                            Navigator.pop(dialogContext);
                          },
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'إعدادات\n',
                                  style: TextStyle(color: Colors.white),
                                ), // السطر الأول
                                TextSpan(
                                  text: 'Mobile DATA',
                                  style: TextStyle(color: Colors.white),
                                ), // السطر الثاني
                              ],
                            ),
                            textAlign: TextAlign.center, // جعل النص في المنتصف
                          ),
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      child: const Text(
                        'رجوع',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    }
  }

  /// **دالة للتحقق من الإنترنت الفعلي**
  Future<bool> isInternetAvailable() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }

    // اختبار فعلي للإنترنت عن طريق محاولة الوصول إلى Google
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  //
  //
  Future<void> _refreshData() async {
    await Future.delayed(Duration(seconds: 2)); // محاكاة تحميل البيانات
    setState(() {
      loadSavedNotifications();
      fetchPrayerTimes();
      checkInternetConnection(context);
    });
  }

  //
  Future<void> showAdhanNotification(String prayerName) async {
    await audioPlayer.play(AssetSource('adhane/adhan.mp3'));

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'adhan_channel',
      'أذان الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'close_action',
          'إغلاق',
          icon: DrawableResourceAndroidBitmap(
              'stop_7826834'), // Nom de la ressource drawable
          showsUserInterface: true,
          cancelNotification: true,

          // Pas de paramètre 'color' direct - la couleur est gérée par le système
        ),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    notificationsPlugin.show(
      0,
      'أذان $prayerName',
      'حان الآن وقت $prayerName',
      notificationDetails,
      payload: 'stop_7826834',
    );
  }

  //

  //

  Future<void> fetchPrayerTimes() async {
    try {
      Map<String, dynamic> data = await _prayerTimesService.getPrayerTimes(
        context,
      );

      if (data.isNotEmpty) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("prayerTimes", jsonEncode(data['timings']));
        await prefs.setString("hijriDate", data['hijri']); // حفظ التاريخ الهجري
        await prefs.setString("hijriDate2", data['day']); // حفظ التاريخ الهجري
        await prefs.setString(
          "hijriDate3",
          data['month'],
        ); // حفظ التاريخ الهجري
        await prefs.setString("hijriDate4", data['year']); // حفظ التاريخ الهجري
        await prefs.setString("lastUpdate", DateTime.now().toIso8601String());
        schedulePrayerNotifications(prayerTimes);

        setState(() {
          prayerTimes = data['timings'];
          hijriDate = data['hijri']; // تخزين التاريخ الهجري في المتغير
          hijriDate2 = data['day']; // تخزين التاريخ الهجري في المتغير
          hijriDate3 = data['month']; // تخزين التاريخ الهجري في المتغير
          hijriDate4 = data['year']; // تخزين التاريخ الهجري في المتغير
          isLoading = false;
        });

        updateNextPrayer();
        _timer = Timer.periodic(Duration(seconds: 1), (timer) {
          updateNextPrayer();
        });
      } else {
        loadSavedPrayerTimes();
      }
    } catch (e) {
      print("حدث خطأ أثناء جلب أوقات الصلاة: $e");
      loadSavedPrayerTimes();
    }
  }

  Future<void> loadSavedPrayerTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString("prayerTimes");
    String? savedHijriDate = prefs.getString("hijriDate");
    String? savedHijriDate2 = prefs.getString("hijriDate2");
    String? savedHijriDate3 = prefs.getString("hijriDate3");
    String? savedHijriDate4 = prefs.getString("hijriDate4");

    if (savedData != null) {
      setState(() {
        prayerTimes = jsonDecode(savedData);
        hijriDate = savedHijriDate ?? "غير متوفر"; // تحميل التاريخ الهجري
        hijriDate2 = savedHijriDate2 ?? "غير متوفر"; // تحميل التاريخ الهجري
        hijriDate3 = savedHijriDate3 ?? "غير متوفر"; // تحميل التاريخ الهجري
        hijriDate4 = savedHijriDate4 ?? "غير متوفر"; // تحميل التاريخ الهجري
        isLoading = false;
      });

      updateNextPrayer();
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        updateNextPrayer();
      });
    } else {
      setState(() => isLoading = false);
      print("لا توجد بيانات مخزنة محليًا.");
    }
  }

  void updateNextPrayer() {
    if (prayerTimes.isEmpty) return;

    DateTime now = DateTime.now();
    DateTime? nextPrayerTime;
    String? nextPrayerName;

    Map<String, String?> sortedTimes = {
      "الفجر": prayerTimes['Fajr'],
      "الشروق": prayerTimes['Sunrise'],
      "الظهر": prayerTimes['Dhuhr'],
      "العصر": prayerTimes['Asr'],
      "المغرب": prayerTimes['Maghrib'],
      "العشاء": prayerTimes['Isha'],
    };

    for (var entry in sortedTimes.entries) {
      if (entry.value != null) {
        DateTime prayerTime = parseTime(entry.value!);
        if (prayerTime.isAfter(now)) {
          nextPrayerTime = prayerTime;
          nextPrayerName = entry.key;
          break;
        }
      }
    }

    // إذا لم يتم العثور على صلاة قادمة في اليوم، يتم تعيين الفجر لليوم التالي
    if (nextPrayerTime == null) {
      nextPrayerTime = parseTime(prayerTimes['Fajr']!).add(Duration(days: 1));
      nextPrayerName = "الفجر";
    }

    // if (nextPrayerTime != null) {
    setState(() {
      nextPrayer = nextPrayerName!;
      timeRemaining = formatDuration(nextPrayerTime!.difference(now));
    });

    if (nextPrayerTime.difference(now).inSeconds == 0 &&
        activeNotifications.contains(nextPrayerName)) {
      // _playAdhan();
      showAdhanNotification(nextPrayerName!);
    }
    // }
  }

  DateTime parseTime(String time) {
    List<String> parts = time.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String formatDuration(Duration duration) {
    String hours = duration.inHours.toString().padLeft(2, '0');
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> loadSavedNotifications() async {
    SharedPreferences shared = await SharedPreferences.getInstance();

    setState(() {
      activeNotifications = shared.getKeys().where((key) {
        var value = shared.get(key);
        return value is bool && value; // التأكد من أن القيمة نوعها bool
      }).toSet();
    });
  }

  /// تشغيل الأذان
  // Future<void> _playAdhan() async {
  //   final AudioPlayer audioPlayer = AudioPlayer();

  //   try {
  //     await audioPlayer.play(AssetSource('adhane/adhan.mp3'));
  //   } catch (e) {
  //     print("خطأ في تشغيل الأذان: $e");
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("أوقات الصلاة"),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 30.sp,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: isLoading
          ? Center(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 200), // مدة الانتقال
                transitionBuilder: (
                  Widget child,
                  Animation<double> animation,
                ) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: isLoadingo
                    ? SizedBox(
                        key: ValueKey(1), // مفتاح فريد للعنصر الأول
                        width: 100.w,
                        height: 100.h,
                        child: CircularProgressIndicator(
                          color: Colors.indigoAccent,
                          strokeWidth: 8.w,
                        ),
                      )
                    : Icon(
                        Icons.check_circle,
                        key: ValueKey(2), // مفتاح فريد للعنصر الثاني
                        size: 80.w,
                        color: Colors.green.shade800,
                      ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics:
                        AlwaysScrollableScrollPhysics(), // يسمح بالتحديث بدون تمرير فعلي
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 30.w),
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                              "image/photo.jpg",
                            ), // ضع صورة الخلفية هنا
                            fit: BoxFit
                                .cover, // لضبط حجم الصورة لتغطية الشاشة بالكامل
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.16,
                            ),
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                    255,
                                    104,
                                    248,
                                    217,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  "التاريخ الهجري: $hijriDate2 $hijriDate3 $hijriDate4",
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLoading)
                              Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      255,
                                      230,
                                      84,
                                      205,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      text: "الصلاة القادمة: ",
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black, // لون النص الأساسي
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              nextPrayer, // المتغير الذي نريد تلوينه
                                          style: TextStyle(
                                            fontSize: 25.sp,
                                            color: Color.fromARGB(
                                              255,
                                              200,
                                              220,
                                              255,
                                            ), // لون المتغير بالأبيض
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Center(
                              child: Text(
                                "بعد $timeRemaining",
                                style: TextStyle(
                                  fontSize: 25.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            prayerItem(
                              "الفجر",
                              prayerTimes['Fajr'],
                              FaIcon(
                                FontAwesomeIcons.moon,
                                size: 24.sp,
                                color: Colors.blueGrey,
                              ),
                            ),
                            prayerItem(
                              "الشروق",
                              prayerTimes['Sunrise'],
                              FaIcon(
                                FontAwesomeIcons.solidSun,
                                size: 24.sp,
                                color: Colors.orangeAccent,
                              ),
                            ),
                            prayerItem(
                              "الظهر",
                              prayerTimes['Dhuhr'],
                              FaIcon(
                                FontAwesomeIcons.sun,
                                size: 24.sp,
                                color: Colors.yellow,
                              ),
                            ),
                            prayerItem(
                              "العصر",
                              prayerTimes['Asr'],
                              FaIcon(
                                FontAwesomeIcons.cloudSun,
                                size: 24.sp,
                                color: Colors.purple[200] ?? Colors.orange,
                              ),
                            ),
                            prayerItem(
                              "المغرب",
                              prayerTimes['Maghrib'],
                              FaIcon(
                                FontAwesomeIcons.solidSun,
                                size: 24.sp,
                                color: Colors.orange,
                              ),
                            ),
                            prayerItem(
                              "العشاء",
                              prayerTimes['Isha'],
                              FaIcon(
                                FontAwesomeIcons.solidMoon,
                                size: 24.sp,
                                color: const Color.fromARGB(255, 0, 32, 87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ), // jj
    );
  }

  Widget prayerItem(String name, String? time, FaIcon icon) {
    bool isActive = activeNotifications.contains(name);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.r), // الشكل الدائري
      ),
      elevation: 5,
      color: Colors.grey.withOpacity(0.3),
      margin: EdgeInsets.symmetric(vertical: 5.h),
      child: Container(
        height: 55.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(202, 255, 255, 255),
              blurRadius: 12.w,
              spreadRadius: 3.w,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: Center(
          child: ListTile(
            title: Row(
              children: [
                IconButton(
                  onPressed: () async {
                    SharedPreferences shared =
                        await SharedPreferences.getInstance();

                    setState(() {
                      if (!isActive) {
                        shared.setBool(name, true); // حفظ الإشعار في التخزين
                        activeNotifications.add(name);
                      } else {
                        shared.remove(name); // حذف الإشعار من التخزين
                        activeNotifications.remove(name);
                      }
                      isActive = !isActive; // تحديث حالة الزر
                    });
                  },
                  icon: Icon(
                    Icons.notifications,
                    color: isActive ? Colors.amber : Colors.grey,
                  ),
                ),
                SizedBox(width: 11.w),
                Text(
                  time ?? "غير متوفر",
                  style: TextStyle(
                    fontSize: 20.sp,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
                SizedBox(width: 20.w),
                icon,
                SizedBox(width: 11.w),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrayerTimesService {
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> getPrayerTimes(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print(
        "🔍 حالة خدمة الموقع: $serviceEnabled",
      ); // تحقق من القيمة في وحدة التحكم

      if (!serviceEnabled) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return GiffyDialog.image(
              Image.asset(
                "image/ezgif.com-crop (1).gif",
                height: 200,
                fit: BoxFit.contain,
              ),
              title: const Text(
                'GPS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                '.خدمة تحديد الموقع غير مفعّلة',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context); // الرجوع إلى الصفحة السابقة
                        } else {
                          SystemNavigator.pop(); // إغلاق التطبيق
                        } // إغلاق الحوار
                      }, // إغلاق الحوار
                      child: const Text(
                        'رجوع',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                        Navigator.pop(context);
                      }, // إغلاق الحوار
                      child: const Text(
                        'تفعيل',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
        return Future.value({});
      }
      //
      //
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          throw Exception("تم رفض إذن تحديد الموقع نهائيًا.");
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double latitude = position.latitude;
      double longitude = position.longitude;

      String date = DateFormat('dd-MM-yyyy').format(DateTime.now());

      final response = await _dio.get(
        'http://api.aladhan.com/v1/timings',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'method': 3,
          'date': date,
        },
      );

      return {
        'timings': response.data['data']['timings'],
        'hijri': response.data['data']['date']['hijri']['date'],
        'day': response.data['data']['date']['hijri']['day'],
        'month': response.data['data']['date']['hijri']['month']['ar'],
        'year': response.data['data']['date']['hijri']['year'],
      };
    } catch (e) {
      print("حدث خطأ أثناء جلب أوقات الصلاة: $e");
      return {}; // إرجاع خريطة فارغة في حالة الفشل
    }
  }
}
