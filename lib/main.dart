import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_k_chart/flutter_k_chart.dart';
import 'package:flutter_k_chart/generated/l10n.dart' as k_chart;
import 'package:flutter_k_chart/k_chart_widget.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      // supportedLocales: [const Locale('zh', 'CN')],
      localizationsDelegates: [k_chart.S.delegate],
      home: MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<KLineEntity> datas = [];
  bool showLoading = true;
  MainState _mainState = MainState.MA;
  SecondaryState _secondaryState = SecondaryState.MACD;
  bool isLine = true;
  List<DepthEntity> _bids = [], _asks = [];

  @override
  void initState() {
    super.initState();

    getData('60min');

    rootBundle.loadString('assets/depth.json').then((result) {
      final parseJson = json.decode(result);
      Map tick = parseJson['tick'];
      var bids = tick['bids']
          .map((item) => DepthEntity(item[0], item[1]))
          .toList()
          .cast<DepthEntity>();
      var asks = tick['asks']
          .map((item) => DepthEntity(item[0], item[1]))
          .toList()
          .cast<DepthEntity>();
      initDepth(bids, asks);
    });
  }

  void initDepth(List<DepthEntity>? bids, List<DepthEntity>? asks) {
    if (bids == null || asks == null || bids.isEmpty || asks.isEmpty) return;
    _bids = [];
    _asks = [];
    double amount = 0.0;
    bids.sort((left, right) => left.price.compareTo(right.price));
    //倒序循环 //累加买入委托量
    bids.reversed.forEach((item) {
      amount += item.amount;
      item.amount = amount;
      _bids.insert(0, item);
    });

    amount = 0.0;
    asks.sort((left, right) => left.price.compareTo(right.price));
    //循环 //累加买入委托量
    asks.forEach((item) {
      amount += item.amount;
      item.amount = amount;
      _asks.add(item);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.transparent,
        title: const Text('Demo'),
      ),
      backgroundColor: Color(0xff17212F),
      body: Stack(children: <Widget>[
        Container(
          height: 600,
          margin: EdgeInsets.symmetric(horizontal: 10),
          width: double.infinity,
          child: KChartWidget(
            datas,
            isLine: !isLine,
            mainState: _mainState,
            secondaryState: _secondaryState,
            volState: VolState.VOL,
            fractionDigits: 4,
          ),
        ),
        if (showLoading)
          Container(
              width: double.infinity,
              height: 450,
              alignment: Alignment.center,
              child: CircularProgressIndicator()),
        Container(
            width: double.infinity,
            height: 40,
            child: Row(children: [
              const SizedBox(width: 10.0),
              Container(
                width: 60,
                child: TextButton(
                  onPressed: () {
                    showLoading = true;
                    setState(() {});
                    getData('5min');
                  },
                  child: Text("5分钟",
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
              Container(
                width: 60,
                child: TextButton(
                  onPressed: () {
                    showLoading = true;
                    setState(() {});
                    getData('15min');
                  },
                  child: Text("15分钟",
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
              Container(
                width: 60,
                child: TextButton(
                  onPressed: () {
                    showLoading = true;
                    setState(() {});
                    getData('60min');
                  },
                  child: Text("1小时",
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
              Container(
                width: 60,
                child: TextButton(
                  onPressed: () {
                    showLoading = true;
                    setState(() {});
                    getData('4hour');
                  },
                  child: Text("4小时",
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
              Container(
                width: 50,
                child: TextButton(
                  onPressed: () {
                    showLoading = true;
                    setState(() {});
                    getData('1day');
                  },
                  child:
                      Text("日线", style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
            ])),
        //buildButtons(),
      ]),
    );
  }

  Widget buildButtons() {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 5,
      children: <Widget>[
        button("kLine", onPressed: () => isLine = !isLine),
        button("MA", onPressed: () => _mainState = MainState.MA),
        button("BOLL", onPressed: () => _mainState = MainState.BOLL),
        button("隐藏",
            onPressed: () => _mainState =
                _mainState == MainState.NONE ? MainState.MA : MainState.NONE),
        button("MACD", onPressed: () => _secondaryState = SecondaryState.MACD),
        button("KDJ", onPressed: () => _secondaryState = SecondaryState.KDJ),
        button("RSI", onPressed: () => _secondaryState = SecondaryState.RSI),
        button("WR", onPressed: () => _secondaryState = SecondaryState.WR),
        button("隐藏副视图",
            onPressed: () => _secondaryState =
                _secondaryState == SecondaryState.NONE
                    ? SecondaryState.MACD
                    : SecondaryState.NONE),
        button("update", onPressed: () {
          //更新最后一条数据
          datas.last.close += (Random().nextInt(100) - 50).toDouble();
          datas.last.high = max(datas.last.high, datas.last.close);
          datas.last.low = min(datas.last.low, datas.last.close);
          DataUtil.updateLastData(datas);
        }),
        button("addData", onPressed: () {
          //拷贝一个对象，修改数据
          var kLineEntity = KLineEntity.fromJson(datas.last.toJson());
          kLineEntity.id = kLineEntity.id! + 60 * 60 * 24;
          kLineEntity.open = kLineEntity.close;
          kLineEntity.close += (Random().nextInt(100) - 50).toDouble();
          datas.last.high = max(datas.last.high, datas.last.close);
          datas.last.low = min(datas.last.low, datas.last.close);
          DataUtil.addLastData(datas, kLineEntity);
        }),
        /* button("1month", onPressed: () async {
          //getData('1mon');
          String result = await rootBundle.loadString('assets/kmon.json');
          Map parseJson = json.decode(result);
          List list = parseJson['data'];
          datas = list
              .map((item) => KLineEntity.fromJson(item))
              .toList()
              .reversed
              .toList()
              .cast<KLineEntity>();
          DataUtil.calculate(datas);
        }),
        TextButton(
            onPressed: () {
              showLoading = true;
              setState(() {});
              getData('1day');
            },
            child: Text("日线", style: const TextStyle(color: Colors.black)),
            style: TextButton.styleFrom(backgroundColor: Colors.blue)),*/
      ],
    );
  }

  Widget button(String text, {VoidCallback? onPressed}) {
    return TextButton(
      onPressed: () {
        if (onPressed != null) {
          onPressed();
          setState(() {});
        }
      },
      child: Text("$text", style: TextStyle(color: Colors.grey.shade500)),
    );
  }

  void getData(String period) async {
    late String result;
    try {
      result = await getIPAddress('$period');
    } catch (e) {
      print('获取数据失败,获取本地数据');
      result = await rootBundle.loadString('assets/kline.json');
    } finally {
      Map parseJson = json.decode(result);
      List list = parseJson['data'];
      datas = list
          .map((item) => KLineEntity.fromJson(item))
          .toList()
          .reversed
          .toList()
          .cast<KLineEntity>();
      DataUtil.calculate(datas);
      showLoading = false;
      setState(() {});
    }
  }

  Future<String> getIPAddress(String? period) async {
    //火币api，需要翻墙
    var url =
        'https://api.huobi.br.com/market/history/kline?period=${period ?? '1day'}&size=600&symbol=ethusdt';
    String result;
    var response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 7));
    if (response.statusCode == 200) {
      result = response.body;
    } else {
      return Future.error("获取失败");
    }
    return result;
  }
}
