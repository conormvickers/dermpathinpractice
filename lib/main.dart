import 'dart:convert';
import 'dart:io';
import "package:universal_html/html.dart" as html;
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:transparent_image/transparent_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'dart:math' as math;
import 'package:clipboard/clipboard.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as imgLib;
import 'package:google_fonts/google_fonts.dart';
import 'package:mailto/mailto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dermpath in Practice',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: MyHomePage(
        title: 'Dermpath in Practice',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required this.title});
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  String reading = '';
  String chapterTitle = '';
  late AnimationController _animationController;
  late Animation _animation;
  bool showViewer = true;

  GlobalKey viewerKey = GlobalKey();

  asyncSetup() async {
    if (!kIsWeb) {
      directory = await getApplicationDocumentsDirectory();
    }
    updateDrawer();
    if (!kIsWeb) {
      Future.delayed(Duration(seconds: 2), () {
        Fluttertoast.showToast(
            msg: "Checking for Updates...",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.pinkAccent,
            textColor: Colors.white,
            fontSize: 16.0);

        checkForUpdates();
      });
    }
  }

  clearEVERYTHING() {
    Directory(directory.path).list().forEach((element) {
      if (element is Directory) {
        element.list().forEach((sub) {
          print('element:: ' + sub.path);
          sub.deleteSync();
        });
      } else {
        print('element:: ' + element.path);
        element.deleteSync();
      }
    });
  }

  void initState() {
    super.initState();
    asyncSetup();

    _animationController =
        AnimationController(duration: Duration(milliseconds: 300), vsync: this);
    _animation = CurvedAnimation(
        parent: _animationController,
        curve: Curves
            .easeOut); // IntTween(begin: 100, end: 0).animate(_animationController);
    _animation.addListener(() => setState(() {}));

    _controllerReset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    slideController = TransformationController();
    _image = Image.memory(kTransparentImage);
    _loading = false;
  }

  double tapdy = 0;
  double tapdx = 0;

  final TransformationController _transformationController =
      TransformationController();
  late Animation<Matrix4> _animationReset;
  late AnimationController _controllerReset;

  void _onAnimateReset() {
    _transformationController.value = _animationReset.value;
    if (!_controllerReset.isAnimating) {
      _animationReset.removeListener(_onAnimateReset);
      _controllerReset.reset();
    }
  }

  void _animateResetInitialize() {
    _controllerReset.reset();
    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(_controllerReset);
    _animationReset.addListener(_onAnimateReset);
    _controllerReset.forward();
  }

  void animateTo(Matrix4 go) {
    _controllerReset.reset();
    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: go,
    ).animate(_controllerReset);
    _animationReset.addListener(_onAnimateReset);
    _controllerReset.forward();
  }

  double xOffset = 0;

  @override
  void dispose() {
    _controllerReset.dispose();
    super.dispose();
  }

  late TransformationController slideController;
  late Image _image;
  bool _loading = true;
  String fetchResult = '';

  firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instance;
  late String url;
  late firebase_storage.Reference ref;
  late String status;
  double progress = 0;

  initApp() async {
    await Firebase.initializeApp();
    updateDrawer();
  }

  String currentImagePath = '';
  String pictureName = '';
  String trimUrlToName(String url) {
    if (url.contains('/') && url.contains('.')) {
      String t = url.substring(url.lastIndexOf('/') + 1, url.lastIndexOf('.'));
      t = t.replaceAll('_', ' ');
      return t;
    }
    return '';
  }

  initImage(String fullPath) async {
    currentImagePath = fullPath;

    pictureName = trimUrlToName(currentImagePath);

    _loading = true;
    setState(() {});

    if (kIsWeb) {
      print('looking on firebase for: ' + fullPath);
      ref = storage.ref('/').child(fullPath);
      print(fullPath);
      ref.getMetadata().then((value) => print(value.updated));
      url = await ref.getDownloadURL();

      print('got download url' + url);

      if (url.contains('.tif')) {
        print('tiff image');
        final response = await http.get(Uri.parse(url));
        imgLib.Decoder dec = imgLib.findDecoderForData(response.bodyBytes)!;
        print(dec);
        _image = Image.memory(Uint8List.fromList(
            imgLib.encodePng(dec.decodeImage(response.bodyBytes)!)));
      } else {
        _image = Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (BuildContext context, Widget child,
              ImageChunkEvent? loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                backgroundColor: Colors.pinkAccent.withOpacity(0.5),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        );
      }
    } else {
      _image = Image.file(File(fullPath));
    }

    setState(() {});
    _image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (info, call) {
          print('Networkimage is fully loaded and saved');
          setState(() {
            _loading = false;
          });
        },
      ),
    );
  }

  initText(String fullPath) async {
    ref = storage.ref('/').child(fullPath);
    print(fullPath);
    url = await ref.getDownloadURL();
    print('got download url' + url);
  }

  late String rawInfo;
  late List<String> caseSections;
  List<String> subChapters = [];
  List<String> entityParts = [
    'Clinical features:',
    'Histopathology:',
    'Clinicopathologic correlation:',
    'Histopathologic differential diagnosis:',
    'Example line diagnosis:',
    'For the clinician:',
  ];
  late Directory directory;

  updateMobileData(
    firebase_storage.Reference itemRef,
    SharedPreferences prefs,
  ) async {
    final res = await itemRef.listAll();
    List<firebase_storage.Reference> asdf = res.items;

    for (var element in asdf) {
      if (scafKey.currentState != null) {
        if (scafKey.currentState!.isDrawerOpen) {
          try {
            downUpdate(() {
              updateStatus = 'checking ' + element.fullPath;
            });
          } on Exception catch (e) {
            print(e);
          }
        }
      }

      await checkingAsync(element, prefs);
    }
  }

  checkingAsync(
      firebase_storage.Reference element, SharedPreferences prefs) async {
    final f = await element.getMetadata();
    String? a = f.updated != null ? f.updated!.toIso8601String() : null;
    String b;
    File file = File(remoteToLocal(element.fullPath));
    if (await file.exists()) {
      final test = prefs.getString(element.fullPath);
      if (test != null) {
        b = test;
      } else {
        b = 'file not found';
      }
    } else {
      b = 'file not found';
    }

    print('comparing for ' + element.fullPath + '\n');
    print(a);
    print(b);

    if (a != null && b != null) {
      if (a != b) {
        await addQueue(element, a);
      }
    } else {
      if (a != null) {
        await addQueue(element, a);
      }
    }
  }

  bool updates = false;
  addQueue(firebase_storage.Reference itemRef, String lastUpdate) {
    updates = true;
    references.add(itemRef);
    lastUpdates.add(lastUpdate);
    print('queue');
  }

  int key = 0;
  int deleteKey = 0;
  bool downloadPressed = false;
  downloadAll() async {
    if (downloadPressed) {
      return;
    }
    downloadPressed = true;
    doneDownload = false;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    key = 0;
    for (firebase_storage.Reference value in references) {
      await downloadMobile(value, prefs, lastUpdates[key]);
      updateDownloadGlobal(() {
        key++;
      });
    }
    deleteKey = 0;
    for (var delete in toDelete) {
      print('DELETING File: ' + delete.path);
      delete.deleteSync();
      deleteKey++;
    }
    doneDownload = true;
    startingUp = true;
    updateDrawer();
    Navigator.of(context).pop();
  }

  List<firebase_storage.Reference> references = [];
  List<String> lastUpdates = [];

  downloadMobile(firebase_storage.Reference itemRef, SharedPreferences prefs,
      String lastUpdate) async {
    print('updating... ' + itemRef.fullPath);

    updateStatus = 'updating... ' + itemRef.fullPath;

    File file = File(remoteToLocal(itemRef.fullPath));

    final Uint8List? a = await itemRef.getData();
    // reading = utf8.decode(a!);
    if (a != null) {
      String ff = remoteToLocal(itemRef.fullPath);
      print('checking directory:: ' + ff.substring(0, ff.lastIndexOf('/')));
      Directory check = Directory(ff.substring(0, ff.lastIndexOf('/')));
      if (await check.exists()) {
      } else {
        await check.create();
      }
      await file.writeAsBytes(a);
      prefs.setString(itemRef.fullPath, lastUpdate);
      print('updated ' + itemRef.fullPath);

      updateStatus = 'updated ' + itemRef.fullPath;
    }
  }

  updateInfo(String fullPath) async {
    subChapters = [];
    Uint8List? a;

    if (kIsWeb) {
      firebase_storage.Reference itemRef = storage.ref('/').child(fullPath);
      print('downloading text data' + itemRef.fullPath);
      final temp = await itemRef.getData();
      if (temp != null) {
        a = temp;
      }
    } else {
      print('reading data locally... ' + fullPath);
      File fileOfText = File(fullPath);
      a = await fileOfText.readAsBytes();
    }
    if (a == null) {
      return;
    }

    reading = utf8.decode(a);
    String questions = '';
    if (reading.contains('-Questions-')) {
      List<String> qsplit = reading.split('-Questions-');
      reading = qsplit[0];
      questions = qsplit[1];
    }

    List<String> markerSplit = reading.split('***');
    textBits = [];
    markerSplit.asMap().forEach((key, value) {
      if (key.isOdd) {
        String where = value;
        String previousWord = markerSplit[key - 1].split(' ').last;

        textBits.add(
          TextSpan(
              text: ' ' + previousWord,
              style: TextStyle(
                  color: Colors.deepPurple, fontWeight: FontWeight.bold),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  print('clicked ' + where);
                  goToMarker(where);
                }),
        );
        addMarker(where);
      } else {
        String chaptersRemoved = value;

        value.split('**').asMap().forEach((chap, element) {
          if (chap.isOdd) {
            subChapters.add(element);
            textBits.add(TextSpan(
                text: '\n' + element.replaceAll('**', ' ') + '\n',
                style:
                    GoogleFonts.montserrat(color: Colors.black, fontSize: 30)));

            chaptersRemoved = chaptersRemoved.replaceAll(element, ' ');
          } else {
            if (chap >= value.split('**').length - 1 &&
                key < markerSplit.length - 1) {
              String lastWord = element
                  .split(' ')
                  .sublist(0, element.split(' ').length - 1)
                  .join(' ');
              List<String> enterSplit = lastWord.split('\n');
              enterSplit.asMap().forEach((key, ee) {
                bool entityPartFound = false;
                entityParts.forEach((entityPart) {
                  if (ee.toUpperCase().contains(entityPart.toUpperCase())) {
                    entityPartFound = true;
                  }
                });
                if (entityPartFound) {
                  textBits.add(TextSpan(
                      text: ee + (key != enterSplit.length - 1 ? '\n' : ''),
                      style: GoogleFonts.montserrat(
                          color: Colors.black, fontSize: 20)));
                } else {
                  textBits.add(TextSpan(
                      text: ee + (key != enterSplit.length - 1 ? '\n' : ''),
                      style: GoogleFonts.montserrat(color: Colors.black)));
                }
              });
            } else {
              List<String> enterSplit = element.split('\n');
              enterSplit.forEach((ee) {
                bool entityPartFound = false;
                entityParts.forEach((entityPart) {
                  if (ee.toUpperCase().contains(entityPart.toUpperCase())) {
                    entityPartFound = true;
                  }
                });
                if (entityPartFound) {
                  textBits.add(TextSpan(
                      text: ee + (key != enterSplit.length - 1 ? '\n' : ''),
                      style: GoogleFonts.montserrat(
                          color: Colors.black, fontSize: 20)));
                } else {
                  textBits.add(TextSpan(
                      text: ee + (key != enterSplit.length - 1 ? '\n' : ''),
                      style: GoogleFonts.montserrat(color: Colors.black)));
                }
              });
            }
          }
        });
        chaptersRemoved = chaptersRemoved.replaceAll('**', '');
      }
    });

    questionCards = [];
    if (questions.length > 1) {
      List<String> qs = questions.split('\n');

      qs.asMap().forEach((key, value) {
        if (value.length < 2) {
          return;
        }

        String stem = value.substring(0, value.indexOf(':'));
        List<String> ansString = value.split(':').sublist(1);
        String trueAns = ansString.last.split(';')[1];
        ansString.last = ansString.last.split(';')[0];

        bool showAnswer = false;
        questionCards.add(StatefulBuilder(
            builder: (BuildContext context, StateSetter updateCard) {
          List<Widget> ans = [];
          ansString.asMap().forEach((answerNumber, answerValue) {
            Color showColor = Colors.grey;
            if (answerValue[0] == '*') {
              showColor = Colors.lightBlueAccent;
            }
            BoxDecoration decoration = BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.black, width: 1));
            if (showAnswer) {
              decoration = BoxDecoration(
                color: showColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.transparent, width: 1),
              );
            }
            ans.add(Padding(
              padding: EdgeInsets.all(10),
              child: GestureDetector(
                onTap: () {
                  showAnswer = !showAnswer;
                  updateCard(() {});
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  child: answerValue[0] == '*'
                      ? Text(answerValue.substring(1))
                      : Text(answerValue),
                  decoration: decoration,
                  padding: EdgeInsets.all(10),
                ),
              ),
            ));
          });

          return Padding(
            padding: EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("#" + key.toString() + "   " + stem),
                        Container(
                          height: 20,
                        ),
                        Wrap(
                          spacing: 10,
                          children: ans,
                        ),
                        Container(
                          height: 20,
                        ),
                        AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            height: showAnswer ? 100 : 0,
                            child: showAnswer ? Text(trueAns) : null)
                      ],
                    ))
                  ],
                ),
              ),
            ),
          );
        }));
      });
    }

    setState(() {});
  }

  List<Widget> questionCards = [];
  List<Widget> drawerItems = [];
  List<String> chapterImages = [];

  String remoteToLocal(String input) {
    return directory.path + '/' + input.toLowerCase().replaceAll(' ', '_');
  }

  changeChapter() async {
    markers = [];
    fullListMarkers = [];
    activeMarkerColorList = [];
    chapterImages = [];

    List<String> fileInFolder = [];
    if (!foundation.kIsWeb) {
      print('using local storage to get data...' + remoteToLocal(chapterTitle));
      Directory localChapter = Directory(remoteToLocal(chapterTitle));
      if (await localChapter.exists()) {
        localChapter.listSync().forEach((element) {
          fileInFolder.add(element.path);
        });
      } else {
        print('ERROR directory not found!');
      }
      // print('found locally: ' + fileInFolder.toString());
      // directory.list().forEach((element) {
      //   print(element.path);
      // });
    } else {
      print('not on mobile, using web retreaval...');
      var listRef = storage.ref().child(chapterTitle);
      final res = await listRef.listAll();
      print(res);
      for (firebase_storage.Reference element in res.items) {
        print(element.fullPath);
        fileInFolder.add(element.fullPath);
      }

      print('found remotely ' +
          fileInFolder.toString() +
          ' for chapter ' +
          chapterTitle);
    }

    bool firstImage = false;
    fileInFolder.forEach((element) {
      if (element.endsWith('.jpg') ||
          element.endsWith('.jpeg') ||
          element.endsWith('.png')) {
        if (!firstImage) {
          initImage(element);
          firstImage = true;
        }
        chapterImages.add(element);
      }
      if (element.endsWith('.txt')) {
        updateInfo(element);
      }
    });
  }

  bool startingUp = true;
  late Widget updateTile = ListTile(
    onTap: checkForUpdates,
    title: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Check for Updates'),
        Icon(
          Icons.cloud_download,
          color: Colors.deepPurple,
        )
      ],
    ),
  );
  late Widget creditTile = ListTile(
    onTap: openEndDrawer,
    title: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('About'),
        Icon(
          Icons.info_rounded,
          color: Colors.deepPurple,
        )
      ],
    ),
  );

  late Widget emailTile = ListTile(
    onTap: launchMailto,
    title: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Feedback'),
        Icon(
          Icons.email_outlined,
          color: Colors.deepPurple,
        )
      ],
    ),
  );
  late Widget creditWidget = Container(
    child: Column(
      children: [
        DrawerHeader(
            child: FittedBox(
                child: Text(
          'Contributors / Masterminds',
          style: GoogleFonts.montserrat(),
        ))),
        Card(
          elevation: 10,
          child: Column(
            children: [
              Container(
                  padding: EdgeInsets.all(10), child: Text('Jason Lee, MD')),
            ],
          ),
        ),
        Card(
          elevation: 10,
          child: Container(
              padding: EdgeInsets.all(10), child: Text('Conor Vickers, MD')),
        ),
        Card(
          elevation: 10,
          child: Container(
              padding: EdgeInsets.all(10), child: Text('Simo Huang, MD')),
        ),
      ],
    ),
  );
  openEndDrawer() {
    scafKey.currentState!.openEndDrawer();
  }

  String getLocalDirName(FileSystemEntity input) {
    return input.path.substring(input.path.lastIndexOf('/') + 1);
  }

  String getLocalDirNameFancy(FileSystemEntity input) {
    return input.path
        .substring(input.path.lastIndexOf('/') + 1)
        .replaceAll('_', ' ')
        .split(' ')
        .map((e) => e.capitalize())
        .toList()
        .join(' ');
  }

  updateDrawer() async {
    drawerItems = [];
    print('updating drawer');
    var listRef = storage.ref().child('/');
    String first = '';

    if (kIsWeb) {
      listRef.listAll().then((res) {
        if (res.prefixes.length > 0) {
          first = res.prefixes.first.name;
        }
        res.prefixes.forEach((itemRef) async {
          // Mobile update

          drawerItems.add(ListTile(
            title: Text(itemRef.name),
            onTap: () => {
              print('tapped'),
              setState(() => {
                    chapterTitle = itemRef.name,
                    changeChapter(),
                    _loading = true,
                  }),
              Navigator.pop(context),
            },
          ));
        });

        if (startingUp) {
          setState(() {
            startingUp = false;
            if (first != '') {
              chapterTitle = first;
              changeChapter();
              _loading = true;
            }
          });
        }

        drawerItems.add(creditTile);
        drawerItems.add(emailTile);
      }).onError((error, stackTrace) {});
    } else {
      List<FileSystemEntity> subs = directory
          .listSync()
          .where((element) => element is Directory)
          .toList();
      if (subs.length > 0) {
        first = getLocalDirName(subs.first);
      }

      subs.forEach((itemRef) {
        drawerItems.add(ListTile(
          title: Text(getLocalDirNameFancy(itemRef)),
          onTap: () => {
            print('tapped'),
            setState(() => {
                  chapterTitle = getLocalDirName(itemRef),
                  changeChapter(),
                  _loading = true,
                }),
            Navigator.pop(context),
          },
        ));
      });
      if (startingUp) {
        setState(() {
          startingUp = false;
          if (first != '') {
            chapterTitle = first;
            changeChapter();
            _loading = true;
          }
        });
      }

      drawerItems.add(creditTile);
      drawerItems.add(emailTile);
      drawerItems.add(updateTile);
    }
    setState(() {});
  }

  String updateStatus = 'checking for updates';
  List<FileSystemEntity> toDelete = [];
  late StateSetter downUpdate;
  checkForUpdates() async {
    references = [];
    lastUpdates = [];
    updates = false;
    try {
      setState(() {
        updateTile = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinKitChasingDots(color: Colors.purple),
            Expanded(
              child: StatefulBuilder(
                builder: (thisLowerContext, innerSetState) {
                  downUpdate = innerSetState;
                  print('updating ' + updateStatus);
                  return Text(
                    updateStatus,
                    overflow: TextOverflow.fade,
                  );
                },
              ),
            ),
          ],
        );
        updateDrawer();
      });

      var listRef = storage.ref().child('/');
      String first = '';
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final res = await listRef.listAll();

      List<firebase_storage.Reference> asdf = res.prefixes;
      print('checking ' + asdf.toString());

      List<String> checkPaths = [];
      for (var itemRef in asdf) {
        await updateMobileData(itemRef, prefs);
        final aaa = await itemRef.listAll();
        final bb = await aaa.items;
        for (var item in bb) {
          checkPaths.add(remoteToLocal(item.fullPath));
        }
      } //--------

      toDelete = [];
      List<FileSystemEntity> subs = directory
          .listSync()
          .where((element) => element is Directory)
          .toList();

      subs.forEach((itemRef) {
        Directory(itemRef.path).listSync().forEach((rr) {
          if (!checkPaths.contains(rr.path)) {
            print("to delete: " + rr.path);
            updates = true;
            toDelete.add(rr);
          }
        });
      });
      print('To DELETE: ' + toDelete.toString());
//--------
      print('should be DONE checking');
      updateTile = ListTile(
        onTap: checkForUpdates,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Check for Updates'),
            Icon(
              Icons.cloud_download,
              color: Colors.deepPurple,
            )
          ],
        ),
      );
      if (updates) {
        askToDownload();
      }
      updateDrawer();
    } on Exception catch (e) {
      print(e);
    }
  }

  late StateSetter updateDownloadGlobal;
  bool doneDownload = true;
  askToDownload() {
    showDialog(
        context: context,
        barrierDismissible: doneDownload,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Updates READY!'),
            content: StatefulBuilder(
                builder: (BuildContext context, StateSetter updateDownload) {
              updateDownloadGlobal = updateDownload;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('There are ' +
                      references.length.toString() +
                      ' downloads ready'),
                  Container(height: 20),
                  Text('There are ' +
                      toDelete.length.toString() +
                      ' files to delete'),
                  Container(height: 20),
                  LinearProgressIndicator(
                      value: (key + deleteKey) /
                          (references.length + toDelete.length))
                ],
              );
            }),
            actions: [
              OutlinedButton(
                onPressed: downloadPressed ? null : downloadAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sync ',
                      style: TextStyle(color: Colors.white),
                    ),
                    Icon(Icons.sync, color: Colors.white)
                  ],
                ),
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(Colors.purple),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                        side: BorderSide(color: Colors.purple)),
                  ),
                ),
              ),
            ],
          );
        });
  }

  IconData infoIcon = Icons.info;
  String currentCase = "";

  Widget loadingWidget = Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 70,
          width: 70,
          child: FittedBox(
            child: SpinKitFadingCube(
              color: Colors.deepPurple,
            ),
          ),
        ),
        Text('Loading...'),
      ],
    ),
  );

  bool showInformation = false;

  Widget nameViewer() {
    if (currentCase.length > 0) {
      return Positioned(
        left: -7,
        top: -7,
        child: Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.red,
              border: Border.all(color: Colors.red, width: 7),
              borderRadius:
                  BorderRadius.only(bottomRight: Radius.circular(15))),
          child: Text(
            currentCase,
            style: TextStyle(fontSize: 30, color: Colors.white),
          ),
        ),
      );
    }
    return Container();
  }

  List<Container> infoTiles = [];

  copyImage() async {
    openInANewTab(Uri.file('tt.png').path);
  }

  openInANewTab(url) {
    html.window.open(url, 'PlaceholderName');
  }

  printMarker() {
    print(viewerKey.currentContext!.size);
    double w = viewerKey.currentContext!.size!.width;
    double h = viewerKey.currentContext!.size!.height;
    double min = 0;
    if (w > h) {
      min = w;
    } else {
      min = h;
    }
    double zoom = _transformationController.value[0];
    double x = -1 * (_transformationController.value[12] / zoom) / min;
    double y = -1 * (_transformationController.value[13] / zoom) / min;
    print('***' +
        pictureName.replaceAll(' ', '_') +
        ',' +
        zoom.toStringAsFixed(2) +
        ',' +
        x.toStringAsFixed(2) +
        ',' +
        y.toStringAsFixed(2) +
        '***');
  }

  goToMarker(String where) async {
    if (!showViewer) {
      print('opening viewer');
      toggleViewer();
      await Future.delayed(Duration(seconds: 1));
      print('done');
    }

    List<String> whereSplit = where.split(',');
    // print(whereSplit);
    String targetImageName = whereSplit[0];

    double zoom = double.parse(whereSplit[1]);
    double x = double.parse(whereSplit[2]);
    double y = double.parse(whereSplit[3]);
    String targetImageFullPath = '';
    chapterImages.asMap().forEach((key, value) {
      print(value + ' | ' + targetImageName);
      if (value.toUpperCase().contains(targetImageName.toUpperCase())) {
        targetImageFullPath = value;
      }
    });

    if (currentImagePath != targetImageFullPath) {
      initImage(targetImageFullPath);
    }

    // print(viewerKey.currentContext!.size);
    if (viewerKey.currentContext != null) {
      double w = viewerKey.currentContext!.size!.width;
      double h = viewerKey.currentContext!.size!.height;
      double min = 0;
      if (w > h) {
        min = w;
      } else {
        min = h;
      }
      setState(() {
        print('changing decoration at: ' +
            fullListMarkers.indexOf(where).toString());
        coolColor = Colors.blue;
        hideAllMarkers();
        activeMarkerColorList[fullListMarkers.indexOf(where)] = markerOnBox;
        showingMarker = true;
      });
      animateTo(Matrix4.fromList([
        zoom,
        0,
        0,
        0,
        0,
        zoom,
        0,
        0,
        0,
        0,
        zoom,
        0,
        -zoom * x * (min),
        -zoom * y * (min),
        0,
        1
      ]));
    }
  }

  hideAllMarkers() {
    print('hiding markers');
    activeMarkerColorList =
        List.generate(activeMarkerColorList.length, (index) => BoxDecoration());
    showingMarker = false;
  }

  showAllMarkers() {
    print('showing markers');
    activeMarkerColorList =
        List.generate(activeMarkerColorList.length, (index) => BoxDecoration());
    fullListMarkers.asMap().forEach((key, value) {
      if (value
          .replaceAll('_', ' ')
          .toUpperCase()
          .contains(pictureName.toUpperCase())) {
        activeMarkerColorList[key] = markerOnBox;
      }
    });

    showingMarker = true;
  }

  BoxDecoration markerOnBox = BoxDecoration(
    color: Colors.transparent,
    border: Border.all(color: Colors.lightBlue, width: 4),
  );
  Color coolColor = Colors.red;
  List<String> fullListMarkers = [];
  List<BoxDecoration> activeMarkerColorList = [];
  int addingMarkerIndex = 0;
  bool showingMarker = false;
  addMarker(String where) {
    activeMarkerColorList.add(BoxDecoration());
    fullListMarkers.add(where);

    addingMarkerIndex++;
  }

  updateMarkers() {
    markers = [];
    int rack = 0;
    fullListMarkers.forEach((where) {
      List<String> whereSplit = where.split(',');
      // print('updating markers..' + whereSplit.toString());
      double zoom = double.parse(whereSplit[1]);
      double x = double.parse(whereSplit[2]);
      double y = double.parse(whereSplit[3]);
      markers.add(Positioned(
        child: AnimatedContainer(
          width: 500 * (1 / zoom),
          height: 500 * (1 / zoom),
//            color: coolColor,
          decoration: activeMarkerColorList[rack],
          duration: Duration(milliseconds: 700),
          curve: Curves.easeOut,
        ),
        top: 1000 * y + 250 * (1 / zoom),
        left: 1000 * x + 250 * (1 / zoom),
      ));
      rack++;
    });
  }

  List<TextSpan> textBits = [];
  toggleViewer() {
    if (_animationController.value == 0.0) {
      _animationController.forward();
      Future.delayed(Duration(milliseconds: 100), () {
        showViewer = false;
      });
    } else {
      _animationController.reverse();
      Future.delayed(Duration(milliseconds: 100), () {
        showViewer = true;
      });
    }
  }

  String fancyCapitalize(String input) {
    return input
        .replaceAll('_', ' ')
        .split(' ')
        .map((e) => e.capitalize())
        .toList()
        .join(' ');
  }

  Widget textScreen([bool bottom = false]) {
    if (textBits.length < 1) {
      return Center(
        child: Text("Select a chapter to get started!"),
      );
    }
    return Stack(
      children: [
        SingleChildScrollView(
            child: Column(children: [
          Container(
            padding: EdgeInsets.all(30),
            child: Text(
              fancyCapitalize(chapterTitle),
              style: TextStyle(fontSize: 30),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: RichText(
              text: TextSpan(
                children: textBits,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(30),
            child: Text(
              'Chapter Questions',
              style: TextStyle(fontSize: 30),
            ),
          ),
          ...questionCards
        ])),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              mainAxisAlignment:
                  bottom ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                popUp
                    ? Container()
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: bottom
                              ? BorderRadius.only(
                                  bottomLeft: Radius.circular(15))
                              : BorderRadius.only(topLeft: Radius.circular(15)),
                        ),
                        child: IconButton(
                          tooltip: !showViewer ? 'Show Viewer' : 'Hide Viewer',
                          icon: Icon(
                            !showViewer
                                ? Icons.pageview_rounded
                                : bottom
                                    ? Icons.keyboard_arrow_up_outlined
                                    : Icons.chevron_right,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            toggleViewer();
                          },
                        ),
                      ),
              ],
            ),
          ],
        )
      ],
    );
  }

  bool zoomed = false;
  List<Widget> markers = [];
  Widget viewer([bool top = false, bool drag = false]) {
    updateMarkers();
    if (!showViewer) {
      return Container();
    }
    Widget viewBuilder = StatefulBuilder(
      builder: (BuildContext context, StateSetter build) => Center(
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.black, width: 2)),
          child: InteractiveViewer(
            key: viewerKey,
            panEnabled: true, // Set it to false to prevent panning.
            boundaryMargin: EdgeInsets.all(80),
            minScale: 0.5,
            maxScale: 10,
            constrained: true,
            clipBehavior: Clip.hardEdge,
            transformationController: _transformationController,
            onInteractionUpdate: (details) {
              if (_transformationController.value[0] > 2) {
                if (!zoomed) {
                  print('zoomed');
                  zoomed = true;
                  build(() {});
                }
              } else {
                if (zoomed) {
                  print('out');
                  zoomed = false;
                  build(() {});
                }
              }
            },
            child: FittedBox(
              child: Stack(
                children: [
                  Container(
                    height: 1000,
                    width: 1000,
                    child: FittedBox(child: _image),
                  ),
                  ...markers,
                ],
              ),
            ),
          ),
        ),
      ),
    );

    List<Widget> navigator = [];
    Widget pictureNav = Container();
    if (!drag) {
      if (chapterImages.length > 0) {
        List<Widget> picThumbs = chapterImages
            .map((e) => Container(
                  padding: const EdgeInsets.all(8.0),
                  child: Tooltip(
                    message: trimUrlToName(e),
                    child: GestureDetector(
                        onTap: () {
                          initImage(e);
                        },
                        child: Container(
                          width: 10,
                          height: 10,
                          color: Colors.lightBlue,
                        )),
                  ),
                ))
            .toList();
        int index = chapterImages.indexOf(currentImagePath);
        picThumbs[index] = Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.lightBlue),
            child: Text(
              pictureName,
              style: TextStyle(color: Colors.white),
            ));
        navigator = [
          IconButton(
            onPressed: () => {
              previousImage(),
            },
            tooltip: "Previous Image",
            icon: Icon(
              Icons.arrow_left,
              color: Colors.lightBlue,
            ),
          ),
          ...picThumbs,
          IconButton(
            onPressed: () => {
              nextImage(),
            },
            tooltip: "Next Image",
            icon: Icon(
              Icons.arrow_right,
              color: Colors.lightBlue,
            ),
          ),
          PopupMenuButton(
            tooltip: 'Browse Images',
            child: Icon(
              Icons.image_search,
              color: Colors.lightBlue,
            ),
            onSelected: (value) {
              initImage(value as String);
            },
            itemBuilder: (BuildContext context) {
              return chapterImages
                  .map((e) => PopupMenuItem<String>(
                        child: Text(trimUrlToName(e)),
                        value: e,
                      ))
                  .toList();
            },
          )
        ];
        pictureNav = Container(
          alignment: Alignment.topRight,
          child: FittedBox(
            child: Row(
              children: navigator,
            ),
          ),
        );
      } else {
        _loading = false;
        pictureNav =
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            'no images for this chapter',
            textAlign: TextAlign.center,
          ),
        ]);
        _image = Image.asset("assets/none.png");
      }
    }

    Widget loadingW = _loading ? loadingWidget : Container();

    if (top) {
      return Container(
        color: Colors.white,
        child: Stack(
          children: [
            viewBuilder,
            loadingW,
            pictureNav,
            Positioned(bottom: 0, right: 0, child: viewerTools()),
          ],
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          viewBuilder,
          loadingW,
          pictureNav,
          Positioned(bottom: 0, right: 0, child: viewerTools()),
        ],
      ),
    );
  }

  launchMailto() async {
    final mailtoLink = Mailto(
      to: ['conormvickers@gmail.com'],
      subject: 'Dermpath In Practice Feedback',
      body:
          'Hey this app is awesome!\n\nI was on ' + chapterTitle + ' when...\n',
    );

    await launch('$mailtoLink');
  }

  Widget mag = Container();
  bool magUp = false;
  setupMag(Offset tap) {
    setState(() {
      magUp = true;
    });
    setState(() {
      tapdx = tap.dx;
      tapdy = MediaQuery.of(context).size.height - tap.dy;
      magW = 200;
      magH = 200;
      magDecoration = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black, width: 2));
    });
  }

  double magW = 0;
  double magH = 0;
  BoxDecoration magDecoration = BoxDecoration();

  Widget viewerTools() {
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                popUp
                    ? Container()
                    : FloatingActionButton(
                        onPressed: () {
                          setState(() {
                            popUp = !popUp;
                          });
                        },
                        tooltip: "Popup",
                        child: Icon(Icons.arrow_upward),
                      ),
                Container(width: 10),
                FloatingActionButton(
                  onPressed: () => {
                    showingMarker
                        ? setState(() {
                            hideAllMarkers();
                          })
                        : setState(() {
                            showAllMarkers();
                          }),
                  },
                  tooltip: showingMarker ? "Hide markers" : "Show all markers",
                  child: showingMarker
                      ? Icon(Icons.layers_clear)
                      : Icon(Icons.pin_drop),
                ),
                Container(width: 10),
                FloatingActionButton(
                  onPressed: () {
                    printMarker();
                    _animateResetInitialize();
                  },
                  tooltip: 'Reset Zoom',
                  child: Icon(Icons.fullscreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool popUp = true;
  bool dragging = false;
  bool left = true;
  bool top = true;
  Offset releaseOffset = Offset(0, 0);
  double popPadding = 10;
  double windowSize = 400;
  Widget popUpWidget() {
    if (!popUp) {
      return Container();
    }
    Size a = MediaQuery.of(context).size;
    double temp = a.width;
    if (a.height < a.width) {
      temp = a.height;
    }
    windowSize = temp * 2 / 3;
    if (windowSize > 400) {
      windowSize == 400;
    }
    Widget pop = Container(
      width: windowSize,
      height: windowSize + 20,
      child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 20,
              child: Draggable<Color>(
                  child: Container(
                    child: Row(
                      children: [
                        FittedBox(
                          child: IconButton(
                            icon: Icon(Icons.close),
                            tooltip: 'Dock',
                            onPressed: () {
                              setState(() {
                                popUp = false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    decoration: BoxDecoration(
                        color: dragging ? Colors.transparent : Colors.white,
                        border: dragging
                            ? null
                            : Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onDragStarted: () {
                    setState(() {
                      dragging = true;
                    });
                  },
                  onDragEnd: (details) {
                    releaseOffset = details.offset;
                    final x = details.offset.dx + (windowSize / 2);
                    final y = details.offset.dy + (windowSize / 2) + 10;
                    final fullx = MediaQuery.of(context).size.width;
                    final fully = MediaQuery.of(context).size.height;

                    if (x > fullx / 2) {
                      left = false;
                    } else {
                      left = true;
                    }

                    if (y > fully / 2) {
                      top = false;
                    } else {
                      top = true;
                    }

                    setState(() {
                      print(details.offset.dx);
                      dragging = false;
                    });
                  },
                  feedback: Container(
                      width: windowSize,
                      height: windowSize + 20,
                      child: Column(mainAxisSize: MainAxisSize.max, children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                              color: Colors.purple,
                              border: Border.all(color: Colors.black, width: 2),
                              borderRadius: BorderRadius.circular(5)),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                          ),
                        ),
                        Expanded(child: viewer(true, true))
                      ]))),
            ),
            Expanded(
              child: dragging ? Container() : viewer(),
            )
          ]),
    );

    return AnimatedPositioned(
        duration: Duration(milliseconds: 300),
        // top: releaseOffset.dy - MediaQuery.of(context).viewInsets.top,
        // left: releaseOffset.dx,
        bottom: top ? null : popPadding,
        top: top ? popPadding : null,
        left: left ? popPadding : null,
        right: left ? null : popPadding,
        child: pop);
  }

  Widget rowOrColumn() {
    if (popUp) {
      return textScreen(true);
    }
    if (MediaQuery.of(context).size.height >
        MediaQuery.of(context).size.width) {
      return Column(
        children: <Widget>[
          Expanded(
              flex: ((1 - _animation.value) * 100).toInt(),
              child: viewer(true)),
          Divider(
            height: 1,
          ),
          Expanded(
              flex: 100,
              child: Container(
                child: textScreen(true),
              )),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
            flex: 100,
            child: Container(
              child: textScreen(),
            )),
        VerticalDivider(
          width: 1,
        ),
        Expanded(flex: ((1 - _animation.value) * 100).toInt(), child: viewer()),
      ],
    );
  }

  nextImage() {
    if (chapterImages.contains(currentImagePath)) {
      if (chapterImages.indexOf(currentImagePath) + 1 < chapterImages.length) {
        hideAllMarkers();
        initImage(chapterImages[chapterImages.indexOf(currentImagePath) + 1]);
      }
    }
  }

  previousImage() {
    if (chapterImages.contains(currentImagePath)) {
      if (chapterImages.indexOf(currentImagePath) - 1 >= 0) {
        hideAllMarkers();
        initImage(chapterImages[chapterImages.indexOf(currentImagePath) - 1]);
      }
    }
  }

  GlobalKey<ScaffoldState> scafKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scafKey,
      appBar: AppBar(
        centerTitle: true,
        flexibleSpace: Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                ),
                Text(
                  "Dermpath",
                  style:
                      GoogleFonts.montserrat(fontSize: 20, color: Colors.white),
                ),
                Text(
                  "  -in-  ",
                  style:
                      GoogleFonts.montserrat(fontSize: 10, color: Colors.white),
                ),
                Text(
                  "Practice",
                  style:
                      GoogleFonts.montserrat(fontSize: 20, color: Colors.white),
                ),
                Container(width: 10),
              ],
            ),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.deepPurple, Colors.pinkAccent]))),
        leading: IconButton(
          icon: Icon(
            Icons.menu_book_outlined,
          ),
          tooltip: 'Chapters',
          onPressed: () => {
            scafKey.currentState!.openDrawer(),
          },
        ),
        actions: [Container()],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
                child: Center(
                    child: Text(
              'Chapters',
              style: TextStyle(fontSize: 30),
            ))),
            ...drawerItems
          ],
        ),
      ),
      endDrawer: Drawer(
        child: creditWidget,
      ),
      body: Stack(
        children: [rowOrColumn(), popUpWidget()],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (this.length < 1) {
      return this;
    }
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
