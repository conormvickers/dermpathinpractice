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
      home: MyHomePage(title: 'Dermpath in Practice', ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({ required this.title}) ;
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin{

  String reading = '';
  String chapterTitle = '';

  GlobalKey viewerKey = GlobalKey();
  void initState() {
    super.initState();
    _controllerReset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    updateDrawer();
    slideController = TransformationController();
    _image = Image.memory(  kTransparentImage );
    _loading = false;
  }

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
    final a = _transformationController.value.storage;
    double b = MediaQuery.of(context).size.width ;
    print(a);
    print(b);

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
  initImage(String fullPath, [bool firebase = true]) async {
    if (firebase) {
      ref = storage.ref('/').child(fullPath);
      print(fullPath);
      url = await ref.getDownloadURL();
    }else{
      url = fullPath;
    }
    print('got download url' + url);
    setState(() {
      _image = Image.network(url,
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
    });
    _image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
            (info, call) {
          print('Networkimage is fully loaded and saved' );
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

  updateInfo(firebase_storage.Reference itemRef) async {
    print('downloading text data' + itemRef.fullPath);
    final a = await itemRef.getDownloadURL();
    final b = await http.get(Uri.parse(a) );

    print(b);
    rawInfo = String.fromCharCodes(b.bodyBytes);
    reading = rawInfo;
    setState(() {

    });
  }


  List<Widget> drawerItems = [
  ];

  changeChapter () {
    var listRef = storage.ref().child('/dermpathinpractice/' + chapterTitle);
    listRef
        .listAll()
        .then((res) => {
          res.items.forEach((element) {
            if (element.fullPath.endsWith('.jpg') || element.fullPath.endsWith('.jpeg') ) {
              initImage(element.fullPath);
            }
            if (element.fullPath.endsWith('.txt') ) {
              updateInfo(element);
            }
          }),
    });
  }

  bool startingUp = true;
  updateDrawer() {
    var listRef = storage.ref().child('/dermpathinpractice/');
    String first = '';
    listRef
        .listAll()
        .then((res) => {
          if (res.prefixes.length > 0) {
            first = res.prefixes.first.name,
          },
      res.prefixes.forEach((itemRef) => {
        // All the items under listRef.
        print(itemRef),

        drawerItems.add(ListTile(
          title: Text(itemRef.name),
          onTap: () =>
          {
            setState(() =>
            {
              chapterTitle = itemRef.name,
              changeChapter(),
              _loading = true,
            }),
            Navigator.pop(context),

          },
        )),
      }),
      res.items.forEach((itemRef) {
        drawerItems.add(ListTile(
          title: Text(itemRef.name),
          onTap: () =>
          {
            setState(() =>
            {
              initImage(itemRef.fullPath),
              _loading = true,
            }),
            Navigator.pop(context),

          },
        ));
      }),
      if (startingUp) {
        setState(() {
          startingUp = false;
          if (first != '') {
            chapterTitle = first;
            changeChapter();
            _loading = true;
          }
        }),
      }
    })
        .onError((error, stackTrace) => {});
  }
  IconData infoIcon = Icons.info;
  String currentCase = "";


  Widget loadingWidget =  Center(

    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 70,
          width: 70,
          child: FittedBox(
            child: SpinKitFadingGrid(
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
              border: Border.all( color: Colors.red, width: 7) ,
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(15))
          ),
          child: Text(currentCase, style: TextStyle(fontSize: 30 , color: Colors.white),),
        ),
      );
    }
    return Container();
  }
  List<Container> infoTiles = [];

  copyImage() async {
    openInANewTab(Uri.file('tt.png').path );

  }
  openInANewTab(url){
    html.window.open(url, 'PlaceholderName');
  }

  
  Widget textScreen() {
    List<String> markerSplit = reading.split('see marker ' );
    List<TextSpan> textBits = [];
    markerSplit.asMap().forEach((key, value) {
      if (key > 0) {
        value = value.replaceRange(0, 1, '');
      }
      textBits.add(TextSpan(text: value , style: TextStyle(color: Colors.black)));

      if (key < markerSplit.length - 1) {
        String a = markerSplit[key = 1].substring(0,1);
        textBits.add(TextSpan(text: 'see marker ' + a,
            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold), recognizer: TapGestureRecognizer()
          ..onTap = () {
            print('clicked ' + a);
            print(viewerKey.currentContext!.size);
            double w = viewerKey.currentContext!.size!.width;
            double h = viewerKey.currentContext!.size!.height;
            double min = 0;
            if (w > h) {
              min = w;
            }else{
              min = h;
            }
            animateTo(
              Matrix4.fromList([4, 0, 0, 0,
                0, 4, 0, 0,
                0, 0, 4, 0,
                -4 * 0.5 * ( min )  ,
                -4 * 0.5 * ( min ) , 0, 1])
            );

          }),
        );
      }
    });

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(30),
            child: Text(chapterTitle, style: TextStyle(fontSize: 30),),),
    Container(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: RichText(
      text: TextSpan(
      children: textBits,),),
    ),]
      )
    );
  }

  bool zoomed = false;
  Widget viewer() {
    return Stack(
          children: [

            StatefulBuilder(
      builder: (BuildContext context, StateSetter build) =>
              Center(
                child: Container(

                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2)
                  ),
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
                      }else{
                        if (zoomed) {
                          print('out');
                          zoomed = false;
                          build(() {});
                        }
                      }
                    },
                    child:
                    FittedBox(
                      child: Stack(
                        children: [
                          Container(

                            width: 1000,
                            child: FittedBox(child: _image),
                            height: 1000,
                          ),

                          // zoomed ? Row(
                          //   children: [
                          //     Column(
                          //       children: [
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //       ],
                          //     ),
                          //     Column(
                          //       children: [
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //       ],
                          //     ),
                          //     Column(
                          //       children: [
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //       ],
                          //     ),
                          //     Column(
                          //       children: [
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.blue.withOpacity(0.5), width: 250, height: 250, child: Text('zoomed in tile'),),
                          //       ],
                          //     ),
                          //
                          //
                          //   ],
                          // ) : Row(
                          //   children: [
                          //     Column(
                          //       children: [
                          //         Container(alignment: Alignment.center, color: Colors.red.withOpacity(0.5), width: 500, height: 500, child: Text('zoomed out tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.red.withOpacity(0.5), width: 500, height: 500, child: Text('zoomed out tile'),),
                          //       ],
                          //     ),
                          //     Column(
                          //       children: [
                          //         Container(alignment: Alignment.center, color: Colors.red.withOpacity(0.5), width: 500, height: 500, child: Text('zoomed out tile'),),
                          //         Container(alignment: Alignment.center, color: Colors.red.withOpacity(0.5), width: 500, height: 500, child: Text('zoomed out tile'),),
                          //       ],
                          //     ),
                          //   ],
                          // ),
                          Positioned(
                              left: 600,
                              top: 600,
                              child: Container(width: 50, height: 50, decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 3)),))
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    ),
            _loading ? loadingWidget : Container(),
          ],
        );



  }

  Widget rowOrColumn() {

    if (MediaQuery.of(context).size.height > MediaQuery.of(context).size.width) {
      return  Column(
        children: <Widget>[
          Expanded(child: Container(child: textScreen(),)),
          Expanded(child: viewer())
        ],
      );
    }

    return  Row(
      children: <Widget>[
        Expanded(child: Container(child: textScreen(),)),
        Expanded(child: viewer())
      ],
    );
  }

  GlobalKey<ScaffoldState> scafKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      key: scafKey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu_book_outlined,),
          tooltip: 'Chapters',
          onPressed: () => { scafKey.currentState!.openDrawer() },
        ),
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(child: Center(child: Text('Chapters', style: TextStyle(fontSize: 30),))),
            ...drawerItems],
        ),
      ),
      body: rowOrColumn(),

        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [

            Expanded(
                child: Container()
            ),
            FloatingActionButton(
              onPressed: () => {_animateResetInitialize()},
              tooltip: 'Reset Zoom',
              child: Icon(Icons.fullscreen),
            ),
          ],
        ),
    );
  }
}
