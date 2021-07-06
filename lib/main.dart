import 'dart:convert';
import 'dart:io';

// import 'package:code_editor/code_editor.dart';
// import 'package:ext_storage/ext_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:script_engine/script_engine.dart';
import 'package:flutter_highlight/themes/androidstudio.dart';
// import 'package:script_runner/PublicDirectory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
      ChangeNotifierProvider(create: (context) => MyState(), child: MyApp()));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '脚本执行器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: '脚本列表'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool isDark = false;
  Map<String, String> scriptList = {};
  List<String> logs = [];
  String applicationDir = "";
  String downloadDir = "";
  // PublicDirectory pd;
  bool debugMode = false;
  ScrollController logSc = ScrollController();
  ScriptEngine? se;
  bool running = false;
  bool showEditor = false;
  // List<FileEditor>? scripts;
  static late SharedPreferences cache;
  final Map<String, TextStyle> myTheme = androidstudioTheme;
  late Size screenSize;

  @override
  void dispose() {
    se?.clear();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

    screenSize = WidgetsBinding.instance!.window.physicalSize;
//     scriptList = {
//       "HelloWorld测试脚本": """
// {
//   "processName": "testProc",
//   "beginSegment": [
//     {
//       "action": "getValue",
//       "exp": "{android.applicationDir} - hello world"
//     },
//     {
//       "action": "print"
//     }
//   ]
// }
//     """,
//       "MM当天图片": "http://olgeer.3322.org:8888/mm.json"
//     };
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((event) {
      if (event.level >= Logger.root.level) {
        // log("${DateTime.now().toString()} - [${event.loggerName}] - ${event.level.toString()} : ${event.message}");
        log("[${event.loggerName}] - ${event.level.toString()} : ${event.message}");
      }
    });

    init();
  }

  void init() async {
    if (Platform.isAndroid) {
      applicationDir = "${(await getExternalStorageDirectory())?.path}";
      var r = await [Permission.storage, Permission.photos].request();
      for (Permission k in r.keys) {
        print("${k.toString()}:${await k.status.isGranted}");
      }
    }

    if (Platform.isMacOS) {
      downloadDir = "${(await getDownloadsDirectory())?.path}";
      // var r = await [Permission.storage, Permission.photos].request();
      // for (Permission k in r.keys) {
      //   print("${k.toString()}:${await k.status.isGranted}");
      // }
    }

    // pd = PublicDirectory();
    // await pd.init();

    cache = await SharedPreferences.getInstance();
    scriptList =
        Map.castFrom(jsonDecode(cache.getString("scriptList") ?? "{}"));

    // scripts = [];
    for (String s in scriptList.keys) {
      scriptList[s] = await ScriptEngine.loadScript(scriptList[s]) ?? "";
      // scripts.add(FileEditor(name: s, language: "json", code: scriptList[s]));
    }

    setState(() {});
  }

  @override
  void didChangeMetrics() {
    screenSize = WidgetsBinding.instance!.window.physicalSize;
    // print(screenSize);
  }

  void log(String l) {
    while (logs.length >= 1000) {
      logs.removeAt(0);
    }
    setState(() {
      logs.add(l);
      logSc.jumpTo(logSc.position.maxScrollExtent);
    });
    print(l);
  }

  String myValueProvider(String valueName) {
    String ret;
    switch (valueName) {
      case "android.applicationDir":
        ret = applicationDir;
        break;
      case "macos.downloadDir":
        ret = downloadDir;
        break;
      default:
        // if("PublicDirectory".compareTo(valueName.split(".")[0])==0){
        //   switch(valueName.split(".")[1]){
        //     case "dcim":
        //       ret = pd.dcim;
        //       break;
        //     case "music":
        //       ret = pd.music;
        //       break;
        //     case "downloads":
        //       ret = pd.downloads;
        //       break;
        //     case "documents":
        //       ret = pd.documents;
        //       break;
        //     case "alarms":
        //       ret = pd.alarms;
        //       break;
        //     case "pictures":
        //       ret = pd.pictures;
        //       break;
        //     case "movies":
        //       ret = pd.movies;
        //       break;
        //     case "screenshots":
        //       ret = pd.screenshots;
        //       break;
        //     case "ringtones":
        //       ret = pd.ringtones;
        //       break;
        //     case "notifications":
        //       ret = pd.notifications;
        //       break;
        //     case "podcasts":
        //       ret = pd.podcasts;
        //       break;
        //     default:
        //       ret ="";
        //       break;
        //   }
        // }else
        ret = "";
        break;
    }
    return ret;
  }

  Future<void> onAction(
      dynamic value, dynamic ac, dynamic ret, String debugId) async {
    setState(() {});
  }

  void runScript(String scriptValue) async {
    se?.stop();
    se?.clear();
    setState(() {
      running = true;
    });

    log(scriptValue);
    se = ScriptEngine(scriptValue,
        extendValueProvide: myValueProvider,
        onAction: onAction,
        onScriptEngineStateChange: (s) =>
            log("State change to ${s.toString()}"),
        debugMode: debugMode);

    await se?.init().then((value) => se?.run().then((value) => setState(() {
          showToast("脚本已执行完成");
          running = false;
        })));
  }

  void showToast(String msg,
      {int showInSec = 2,
      ToastGravity gravity = ToastGravity.BOTTOM,
      double fontSize = 16.0,
      bool debugMode = false}) {
    if(Platform.isAndroid || Platform.isIOS){
      Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: showInSec,
        fontSize: fontSize,
      );
    }
    if (debugMode||Platform.isMacOS) log("Toast:$msg");
  }

  void showScript(
      String key, String script, TextEditingController textEditingController) {
    showDialog(
        context: context,
        builder: (ctx) {
          ButtonStyle editStyle = ElevatedButton.styleFrom(
            primary: myTheme["root"]!.color,
          );
          ButtonStyle style =
              ElevatedButton.styleFrom(primary: myTheme["comment"]!.color);
          TextStyle editTextStyle = TextStyle(color: myTheme["string"]!.color);
          TextStyle textStyle = TextStyle(color: myTheme["title"]!.color);
          return Consumer<MyState>(builder: (ctx, myState, _) {
            return SimpleDialog(
              backgroundColor: myTheme["root"]!.backgroundColor,
              titlePadding: EdgeInsets.fromLTRB(10, 5, 10, 0),
              title: Container(
                  height: 50,
                  width: 400,
                  color: myTheme["root"]!.backgroundColor,
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                        key,
                        style: myTheme["keyword"],
                      )),
                      myState.editing
                          ? ButtonBar(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    myState.setEditState(false);
                                  },
                                  child: Text(
                                    "取消",
                                    style: editTextStyle,
                                  ),
                                  style: editStyle,
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    myState.setEditState(false);
                                    setState(() {
                                      scriptList[key] =
                                          textEditingController.text;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    "保存",
                                    style: editTextStyle,
                                  ),
                                  style: editStyle,
                                )
                              ],
                            )
                          : ButtonBar(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    "关闭",
                                    style: textStyle,
                                  ),
                                  style: style,
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    myState.setEditState(true);
                                    print("editing=${myState.editing}");
                                  },
                                  child: Text(
                                    "编辑",
                                    style: textStyle,
                                  ),
                                  style: style,
                                )
                              ],
                            ),
                    ],
                  )),
              children: [
                Divider(
                  height: 1,
                  color: myTheme["comment"]!.color,
                ),
                Container(
                  height: 400,
                  width: 400,
                  color: myTheme["root"]!.backgroundColor,
                  child: myState.editing
                      ? TextField(
                          maxLines: 27,
                          controller: textEditingController,
                          decoration: InputDecoration(
                              fillColor: myTheme["root"]!.backgroundColor,
                              border: InputBorder.none),
                          style: myTheme["variable"]!
                              .copyWith(fontFamily: "monospace", fontSize: 12),
                        )
                      : SingleChildScrollView(
                          child: HighlightView(
                            script,
                            language: "json",
                            theme: myTheme,
                            tabSize: 2,
                            textStyle: TextStyle(
                              fontFamily: "monospace",
                              // letterSpacing: ,
                              fontSize: 12,
                              // height: opt.lineHeight, // line-height
                            ),
                          ),
                        ),
                )
              ],
              contentPadding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController sName = TextEditingController();
    TextEditingController source = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: ()=>setState((){}),
          ),
          IconButton(
              icon: Icon(
                Icons.add,
                size: 32,
              ),
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: Text("添加脚本"),
                        content: Material(
                          child: Container(
                            height: 160,
                            width: 300,
                            child: ListView(
                              children: [
                                TextField(
                                  controller: sName,
                                  decoration: InputDecoration(
                                    labelText: "名称:",
                                  ),
                                ),
                                TextField(
                                  controller: source,
                                  decoration: InputDecoration(
                                    labelText: "源地址或脚本:",
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("取消")),
                          ElevatedButton(
                              onPressed: () {
                                log("名称：${sName.text} 源地址:${source.text}");
                                setState(() {
                                  scriptList[sName.text.trim()] =
                                      source.text.trim();
                                  cache.setString(
                                      "scriptList", jsonEncode(scriptList));
                                  init();
                                });
                                Navigator.pop(context);
                              },
                              child: Text("添加")),
                        ],
                      );
                    });
              })
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isDark
                ? "assets/images/bg_dark.png"
                : "assets/images/bg_light.png"),
            fit: BoxFit.cover,
          ),
        ),
        height: screenSize.height - 60,
        width: screenSize.width,
        margin: EdgeInsets.all(0.0),
        padding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0.0),
        child: SingleChildScrollView(
          child: Container(
            height: screenSize.height - 60,
            child: Column(
              children: [
                Container(
                  height: 300,
                  child: ListView.builder(
                      //脚本列表
                      itemCount: scriptList.length,
                      itemBuilder: (BuildContext context, int index) {
                        // GlobalKey iconBtnKey = GlobalKey();
                        String key = scriptList.keys.toList()[index];
                        String script = scriptList[key] ?? "";
                        TextEditingController textEditingController =
                            TextEditingController();
                        textEditingController.text = script;
                        return Card(
                            child: ListTile(
                                title: Text(
                                  key,
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                                trailing: Container(
                                    width: 160,
                                    alignment: Alignment.center,
                                    child: ButtonBar(
                                        buttonMinWidth: 40,
                                        alignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                              icon: Icon(FontAwesomeIcons.trashAlt,
                                                  size: 24),
                                              onPressed: (){
                                                setState(() {
                                                  scriptList.remove(key);
                                                  cache.setString(
                                                      "scriptList", jsonEncode(scriptList));
                                                });
                                              }),
                                          IconButton(
                                              icon: Icon(FontAwesomeIcons.tools,
                                                  size: 24),
                                              onPressed: () => showScript(
                                                  key,
                                                  script,
                                                  textEditingController)),
                                          IconButton(
                                            icon: Icon(
                                                running
                                                    ? Icons.stop_rounded
                                                    : Icons.play_circle_filled,
                                                size: 24),
                                            onPressed: () {
                                              running
                                                  ? se?.stop()
                                                  : runScript(
                                                      scriptList[key] ?? "{}");
                                            },
                                          ),
                                        ]))));
                      }),
                ),
                Container(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text("日志等级：${Logger.root.level.toString()}"),
                      PopupMenuButton<Level>(
                        icon: Icon(
                          FontAwesomeIcons.checkSquare,
                          size: 20,
                        ),
                        initialValue: Logger.root.level,
                        itemBuilder: (context) {
                          return Level.LEVELS.map((l) {
                            return PopupMenuItem<Level>(
                              value: l,
                              child: Text(
                                l.toString(),
                              ),
                            );
                          }).toList();
                        },
                        onSelected: (select) {
                          Logger.root.level = select;
                          setState(() {});
                        },
                      ),
                      IconButton(
                          icon: Icon(
                            FontAwesomeIcons.trashAlt,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              logs.clear();
                            });
                          })
                    ],
                  ),
                ),
                Container(
                    height: 150,
                    child: ListView.builder(
                        controller: logSc,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          return Text(
                            logs[index],
                            softWrap: false,
                            style:
                                TextStyle(fontSize: 9, color: Colors.black54),
                          );
                        })),
                Container(
                  alignment: Alignment.centerLeft,
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "变量监控栏：",
                        // style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      IconButton(
                          icon: Icon(
                            FontAwesomeIcons.trashAlt,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              if (running) se?.stop();
                              se?.clear();
                            });
                          })
                    ],
                  ),
                ),
                Container(
                    height: 150,
                    child: ListView.builder(
                        itemCount: se?.tValue.length ?? 0,
                        itemBuilder: (context, index) {
                          String? key = se?.tValue.keys.toList()[index];
                          return Text(
                            "$key:${se?.tValue[key]}",
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.black54,
                            ),
                          );
                        })),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyState with ChangeNotifier {
  bool editing = false;
  void setEditState(bool editState) {
    editing = editState;
    notifyListeners();
  }
}
