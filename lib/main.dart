import 'dart:convert';
import 'dart:html' as html;
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
import 'package:photo_view/photo_view.dart';
import 'package:image/image.dart' as imgLib;
import 'package:google_fonts/google_fonts.dart';

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
  void initState() {
    super.initState();

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
    updateDrawer();
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

  updateInfo(firebase_storage.Reference itemRef) async {
    subChapters = [];
    print('downloading text data' + itemRef.fullPath);
    final Uint8List? a = await itemRef.getData();
    reading = utf8.decode(a!);
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
                    GoogleFonts.montserrat(color: Colors.black, fontSize: 40)));

            chaptersRemoved = chaptersRemoved.replaceAll(element, ' ');
            print(chaptersRemoved);
          } else {
            if (chap >= value.split('**').length - 1 &&
                key < markerSplit.length - 1) {
              String lastWord = element
                  .split(' ')
                  .sublist(0, element.split(' ').length - 1)
                  .join(' ');
              textBits.add(TextSpan(
                  text: lastWord,
                  style: GoogleFonts.montserrat(color: Colors.black)));
            } else {
              textBits.add(TextSpan(
                  text: element,
                  style: GoogleFonts.montserrat(color: Colors.black)));
            }
          }
        });
        chaptersRemoved = chaptersRemoved.replaceAll('**', '');
      }
    });

    questionCards = [];
    if (questions.length > 1) {
      List<String> qs = questions.split('\n');
      print(questions);
      print(qs);
      qs.asMap().forEach((key, value) {
        if (value.length < 2) {
          return;
        }
        print('asdfasdf ' + value);
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

  changeChapter() {
    markers = [];
    fullListMarkers = [];
    activeMarkerColorList = [];
    chapterImages = [];
    var listRef = storage.ref().child('/' + chapterTitle);
    bool firstImage = false;
    listRef.listAll().then((res) => {
          res.items.forEach((element) {
            if (element.fullPath.endsWith('.jpg') ||
                element.fullPath.endsWith('.jpeg') ||
                element.fullPath.endsWith('.png')) {
              if (!firstImage) {
                initImage(element.fullPath);
                firstImage = true;
              }
              chapterImages.add(element.fullPath);
            }
            if (element.fullPath.endsWith('.txt')) {
              updateInfo(element);
            }
          }),
        });
  }

  late Image a;
  late Image b;
  late Image c;
  late Image d;
  late Image e;
  late Image f;
  bool tiled = false;

  startTiled() async {
    var listRef = storage.ref().child('/dermpathinpractice/' + chapterTitle);
    listRef.listAll().then((res) => {
          res.items.forEach((element) async {
            if (element.fullPath.contains('full')) {
              initImage(element.fullPath);
            } else {
              if (element.fullPath.contains('00')) {
                a = Image.network(await element.getDownloadURL());
              } else if (element.fullPath.contains('01')) {
                b = Image.network(await element.getDownloadURL());
              } else if (element.fullPath.contains('10')) {
                c = Image.network(await element.getDownloadURL());
              } else if (element.fullPath.contains('11')) {
                d = Image.network(await element.getDownloadURL());
              } else if (element.fullPath.contains('20')) {
                e = Image.network(await element.getDownloadURL());
              } else if (element.fullPath.contains('21')) {
                f = Image.network(await element.getDownloadURL());
              }
            }
          }),
        });
  }

  bool startingUp = true;
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

  updateDrawer() {
    var listRef = storage.ref().child('/');
    String first = '';
    listRef.listAll().then((res) {
      if (res.prefixes.length > 0) {
        first = res.prefixes.first.name;
      }
      ;
      res.prefixes.forEach((itemRef) {
        // All the items under listRef.
        print(itemRef);
        if (itemRef.name.contains(',')) {
          List<String> csplit = itemRef.name.split(',');
          String top = csplit[0];
          List<List<String>> subs = [
            ['', '']
          ];
          int index = 0;
          csplit.sublist(1).forEach((element) {
            if (element.substring(0, element.indexOf(' ')).contains('i') ||
                element.substring(0, element.indexOf(' ')).contains('v')) {
              subs[index][1] = subs[index][1] + ':' + element;
              print(element + 'sub');
            } else {
              if (element[0] == 'A') {
              } else {
                print('iterate');
                subs.add(['', '']);
                index++;
              }
              subs[index][0] = element;
            }
          });
          print(subs);
          List<Widget> subWid = [];
          subs.asMap().forEach((key, e) {
            if (e[1].length > 1) {
              subWid.add(ExpansionTile(
                title: Text('    ' + e[0]),
                children: e[1]
                    .split(':')
                    .sublist(1)
                    .map((e) => ListTile(title: Text('        ' + e)))
                    .toList(),
              ));
            } else {
              subWid.add(ListTile(
                horizontalTitleGap: 20,
                title: Text(
                  '    ' + e[0],
                ),
              ));
            }
          });

          drawerItems.add(ExpansionTile(
            title: Text(top),
            children: subWid,
          ));
        } else {
          drawerItems.add(ListTile(
            title: Text(itemRef.name),
            onTap: () => {
              print('tapped'),
              setState(() => {
                    chapterTitle = itemRef.name,
                    if (chapterTitle.contains('Tiled'))
                      {
                        tiled = true,
                        startTiled(),
                      }
                    else
                      {
                        tiled = false,
                        print('turning off tiled'),
                        changeChapter(),
                      },
                    _loading = true,
                  }),
              Navigator.pop(context),
            },
          ));
        }
      });
      res.items.forEach((itemRef) {
        drawerItems.add(ListTile(
          title: Text(itemRef.name),
          onTap: () => {
            setState(() => {
                  tiled = false,
                  print('turning off tiled'),
                  initImage(itemRef.fullPath),
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
      ;
      drawerItems.add(creditTile);
    }).onError((error, stackTrace) {});
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
    print(' see marker ' +
        pictureName.replaceAll(' ', '_') +
        ',' +
        zoom.toStringAsFixed(2) +
        ',' +
        x.toStringAsFixed(2) +
        ',' +
        y.toStringAsFixed(2) +
        ' ');
  }

  goToMarker(String where) {
    if (!showViewer) {
      print('opening viewer');
      toggleViewer();
      print('done');
    }

    List<String> whereSplit = where.split(',');
    print(whereSplit);
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

    print(viewerKey.currentContext!.size);
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
      if (value.replaceAll('_', ' ').contains(pictureName)) {
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
      print(whereSplit);
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

  Widget textScreen([bool bottom = false]) {
    return Stack(
      children: [
        SingleChildScrollView(
            child: Column(children: [
          Container(
            padding: EdgeInsets.all(30),
            child: Text(
              chapterTitle,
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
                Container(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: bottom
                        ? BorderRadius.only(bottomLeft: Radius.circular(15))
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
  Widget viewer([bool top = false]) {
    updateMarkers();
    if (!showViewer) {
      return Container();
    }
    Widget viewBuilder = StatefulBuilder(
      builder: (BuildContext context, StateSetter build) => Center(
        child: Container(
          decoration:
              BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
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
                  print('zoomed' + tiled.toString());
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
    Widget loadingW = _loading ? loadingWidget : Container();
    List<Widget> navigator = [];
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
                        color: Colors.pinkAccent,
                      )),
                ),
              ))
          .toList();
      int index = chapterImages.indexOf(currentImagePath);
      picThumbs[index] = Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.pinkAccent),
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
          icon: Icon(Icons.arrow_left),
        ),
        ...picThumbs,
        IconButton(
          onPressed: () => {
            nextImage(),
          },
          tooltip: "Next Image",
          icon: Icon(Icons.arrow_right),
        ),
      ];
    }

    Widget pictureNav = Container(
      alignment: Alignment.topRight,
      child: Row(
        children: navigator,
      ),
    );
    if (top) {
      return Stack(
        children: [
          viewBuilder,
          loadingW,
          pictureNav,
          Positioned(bottom: 0, right: 0, child: viewerTools()),
        ],
      );
    }
    return Stack(
      children: [
        viewBuilder,
        loadingW,
        pictureNav,
        Positioned(bottom: 0, right: 0, child: viewerTools()),
      ],
    );
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
                  onPressed: () => {printMarker(), _animateResetInitialize()},
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

  Widget rowOrColumn() {
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
          onPressed: () => {scafKey.currentState!.openDrawer()},
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
        children: [
          rowOrColumn(),
          Stack(
            children: [
              magUp
                  ? Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                              child: Container(
                                color: Colors.black38,
                              ),
                              onTap: () {
                                if (magUp) {
                                  magW = 0;
                                  magH = 0;
                                  magDecoration = BoxDecoration();
                                  print('dismissing mag');
                                  setState(() {});
                                }
                                magUp = false;
                              }),
                        )
                      ],
                    )
                  : Container(),
              Positioned(
                bottom: tapdy,
                left: tapdx,
                child: AnimatedContainer(
                  width: magW,
                  height: magH,
                  decoration: magDecoration,
                  duration: Duration(milliseconds: 300),
                  child: Center(child: Text("I'm a zoomed in image")),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
