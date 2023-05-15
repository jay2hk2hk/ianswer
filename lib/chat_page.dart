import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ianswer/api/chat_api.dart';
import 'package:ianswer/models/chat_message.dart';
import 'package:ianswer/widgets/message_bubble.dart';
import 'package:ianswer/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'database_helper.dart';

// Auto-consume must be true on iOS.
// To try without auto-consume on another platform, change `true` to `false` here.
final bool _kAutoConsume = Platform.isIOS || true;

const String _kConsumableId = 'youaskianswerconsumableIA10';
const String _kUpgradeId = 'upgrade';
const String _kSilverSubscriptionId = 'subscription_silver';
const String _kGoldSubscriptionId = 'subscription_gold';
const List<String> _kProductIds = <String>[
  _kConsumableId,
  /*_kUpgradeId,
  _kSilverSubscriptionId,
  _kGoldSubscriptionId,*/
];

class ChatPage extends StatefulWidget {
  const ChatPage({
    required this.chatApi,
    super.key,
  });

  final ChatApi chatApi;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  //payment
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<String> _notFoundIds = <String>[];
  List<ProductDetails> _products = <ProductDetails>[];
  List<PurchaseDetails> _purchases = <PurchaseDetails>[];
  List<String> _consumables = <String>[];
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _loading = true;
  String? _queryProductError;

  final int storeCount = 5;
  static int page = 0;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  late Future<int> _counter;
  final _messages = <ChatMessage>[
    ChatMessage('您好，请问有什么可以帮忙的?', false),
  ];
  final _messagesToGPT = <ChatMessage>[
    ChatMessage('您好，请问有什么可以帮忙的?', false),
  ];
  var _awaitingResponse = false;
  final dbHelper = DatabaseHelper.instance;
  List<Chat> chatList = [];
  static int currentId = 0;
  bool hasCountOrNot = true;
  static int countDefault = 10;

  @override
  void initState() {
    super.initState();
    initCHatLlist();
    _counter = _prefs.then((SharedPreferences prefs) {
      return prefs.getInt('counter') ?? countDefault;
    });
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription =
        purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (Object error) {
      // handle error here.
    });
    initStoreInfo();
  }

  Future<void> initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isAvailable = isAvailable;
        _products = <ProductDetails>[];
        _purchases = <PurchaseDetails>[];
        _notFoundIds = <String>[];
        _consumables = <String>[];
        _purchasePending = false;
        _loading = false;
      });
      return;
    }

    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    final ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    if (productDetailResponse.error != null) {
      setState(() {
        _queryProductError = productDetailResponse.error!.message;
        _isAvailable = isAvailable;
        _products = productDetailResponse.productDetails;
        _purchases = <PurchaseDetails>[];
        _notFoundIds = productDetailResponse.notFoundIDs;
        _consumables = <String>[];
        _purchasePending = false;
        _loading = false;
      });
      return;
    }

    if (productDetailResponse.productDetails.isEmpty) {
      setState(() {
        _queryProductError = null;
        _isAvailable = isAvailable;
        _products = productDetailResponse.productDetails;
        _purchases = <PurchaseDetails>[];
        _notFoundIds = productDetailResponse.notFoundIDs;
        _consumables = <String>[];
        _purchasePending = false;
        _loading = false;
      });
      return;
    }

    final List<String> consumables = await ConsumableStore.load();
    setState(() {
      _isAvailable = isAvailable;
      _products = productDetailResponse.productDetails;
      _notFoundIds = productDetailResponse.notFoundIDs;
      _consumables = consumables;
      _purchasePending = false;
      _loading = false;
    });
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      iosPlatformAddition.setDelegate(null);
    }
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        showPendingUI();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            deliverProduct(purchaseDetails);
          } else {
            _handleInvalidPurchase(purchaseDetails);
            return;
          }
        }
        if (Platform.isAndroid) {
          if (!_kAutoConsume && purchaseDetails.productID == _kConsumableId) {
            final InAppPurchaseAndroidPlatformAddition androidAddition =
                _inAppPurchase.getPlatformAddition<
                    InAppPurchaseAndroidPlatformAddition>();
            await androidAddition.consumePurchase(purchaseDetails);
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void showPendingUI() {
    setState(() {
      _purchasePending = true;
    });
  }

  Future<void> deliverProduct(PurchaseDetails purchaseDetails) async {
    // IMPORTANT!! Always verify purchase details before delivering the product.
    if (purchaseDetails.productID == _kConsumableId) {
      await ConsumableStore.save(purchaseDetails.purchaseID!);
      final List<String> consumables = await ConsumableStore.load();
      setState(() {
        _purchasePending = false;
        _consumables = consumables;
        _incrementCounter(10);
      });
    } else {
      setState(() {
        _purchases.add(purchaseDetails);
        _purchasePending = false;
      });
    }
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    // handle invalid purchase here if  _verifyPurchase` failed.
  }

  void handleError(IAPError error) {
    setState(() {
      _purchasePending = false;
    });
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) {
    // IMPORTANT!! Always verify a purchase before delivering the product.
    // For the purpose of an example, we directly return true.
    return Future<bool>.value(true);
  }

  Future<void> initCHatLlist() async {
    chatList = await dbHelper.fetchChats();
  }

  @override
  Widget build(BuildContext context) {
    Widget tempList;
    if (page == 1)
      return _payment(context);
    else
      return _main(context);
  }

  Widget _main(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: FutureBuilder<int>(
              future: _counter,
              builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                    return const CircularProgressIndicator();
                  case ConnectionState.active:
                  case ConnectionState.done:
                    if (snapshot.hasError) {
                      return Text('你还有（0）题');
                    } else {
                      if ((snapshot.data) as int <= 0) {
                        hasCountOrNot = false;
                      } else {
                        hasCountOrNot = true;
                      }
                      return Text(
                        '你还有(${snapshot.data})题',
                      );
                    }
                }
              })),
      drawer: Drawer(
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: drawerItem(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ..._messages.map(
                  (msg) => MessageBubble(
                    content: msg.content,
                    isUserMessage: msg.isUserMessage,
                  ),
                ),
              ],
            ),
          ),
          MessageComposer(
            onSubmitted: (p0) {
              if (hasCountOrNot)
                _onSubmitted(p0);
              else {
                var snackBar = SnackBar(content: Text('请购买答案'));
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              }
            },
            awaitingResponse: _awaitingResponse,
          ),
        ],
      ),
    );
  }

  Widget _payment(BuildContext context) {
    // backing data
    var europeanCountries = [
      "Q1:为什么没有会员系统？",
      "A1:我们为了不收集客户的任何资料，我们选择放弃会员系统。",
      "Q2:如果我删了此应用程式，我的回答能拿回吗？",
      "A2:我们为了不收集客户的任何资料，所以我们没有备份的，删除应用程式前，请自行备份。"
    ];

    return new Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              //size: ScreenUtil().setSp(sizeOfIcon, allowFontScalingSelf: true),
            ),
            onPressed: () => {
              setState(() {
                page = 0;
              })
            },
          ),
          title: Text("FAQ"),
        ),
        body: new Center(
          child: ListView.separated(
            itemCount: europeanCountries.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                child: ListTile(
                  title: Text(
                    europeanCountries[index],
                  ),
                ),
              );
            }, //itemBuilder
            separatorBuilder: (context, index) {
              return Divider();
            }, //separatorBuilder
          ),
        ));
  }

  List<Widget> drawerItem() {
    List<Widget> temp = [];
    temp.add(SizedBox(
      //height: 64.0,
      child: DrawerHeader(
        margin: EdgeInsets.all(0.0),
        padding: EdgeInsets.all(0.0),
        decoration: BoxDecoration(
          image: DecorationImage(
            //fit: BoxFit.scaleDown,
            image: AssetImage("./assets/icon/icon.png"),
          ),
          color: Color.fromARGB(255, 0, 22, 150),
        ),
        child: Text(''),
      ),
    ));
    temp.add(
      ListTile(
        leading: Icon(Icons.add),
        title: Text('新增聊天'),
        onTap: () {
          newChat();
          Navigator.pop(context);
        },
      ),
    );
    temp.add(
      Divider(),
    );
    // This loading previous purchases code is just a demo. Please do not use this as it is.
    // In your app you should always verify the purchase data using the `verificationData` inside the [PurchaseDetails] object before trusting it.
    // We recommend that you use your own server to verify the purchase data.
    final Map<String, PurchaseDetails> purchases =
        Map<String, PurchaseDetails>.fromEntries(
            _purchases.map((PurchaseDetails purchase) {
      if (purchase.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
      return MapEntry<String, PurchaseDetails>(purchase.productID, purchase);
    }));
    temp.addAll(_products.map(
      (ProductDetails productDetails) {
        final PurchaseDetails? previousPurchase = purchases[productDetails.id];
        return ListTile(
          leading: Icon(Icons.payments),
          title: Text(
            productDetails.title,
          ),
          /*subtitle: Text(
            productDetails.description,
          ),*/
          trailing: /*previousPurchase != null
              ? IconButton(
                  onPressed: () => confirmPriceChange(context),
                  icon: const Icon(Icons.upgrade))
              : */
              TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.green[800],
              // TODO(darrenaustin): Migrate to new API once it lands in stable: https://github.com/flutter/flutter/issues/105724
              // ignore: deprecated_member_use
              primary: Colors.white,
            ),
            onPressed: () {
              late PurchaseParam purchaseParam;

              if (Platform.isAndroid) {
                // NOTE: If you are making a subscription purchase/upgrade/downgrade, we recommend you to
                // verify the latest status of you your subscription by using server side receipt validation
                // and update the UI accordingly. The subscription purchase status shown
                // inside the app may not be accurate.
                final GooglePlayPurchaseDetails? oldSubscription =
                    _getOldSubscription(productDetails, purchases);

                purchaseParam = GooglePlayPurchaseParam(
                    productDetails: productDetails,
                    changeSubscriptionParam: (oldSubscription != null)
                        ? ChangeSubscriptionParam(
                            oldPurchaseDetails: oldSubscription,
                            prorationMode:
                                ProrationMode.immediateWithTimeProration,
                          )
                        : null);
              } else {
                purchaseParam = PurchaseParam(
                  productDetails: productDetails,
                );
              }

              if (productDetails.id == _kConsumableId) {
                _inAppPurchase.buyConsumable(
                    purchaseParam: purchaseParam, autoConsume: _kAutoConsume);
              } else {
                _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
              }
            },
            child: Text(productDetails.price),
          ),
        );
      },
    ));
    temp.add(
      Divider(),
    );
    for (Chat chat in chatList) {
      temp.add(
        ListTile(
          leading: Icon(Icons.message),
          title: Flexible(
            child: new Container(
              child: new Text(
                chat.chatname,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          onTap: () {
            resetMessage(chat.id!);
            Navigator.pop(context);
          },
        ),
      );
      temp.add(
        Divider(),
      );
    }

    temp.add(Container(
        // This align moves the children to the bottom
        child: Align(
            alignment: FractionalOffset.bottomCenter,
            // This container holds all the children that will be aligned
            // on the bottom and should not scroll with the above ListView
            child: Container(
                child: Column(
              children: <Widget>[
                //Divider(),
                ListTile(
                  leading: Icon(Icons.question_mark),
                  title: Text('FAQ'),
                  onTap: () {
                    setState(() {
                      page = 1;
                    });
                    Navigator.pop(context);
                  },
                ),
                /*ListTile(
                    leading: Icon(Icons.payment),
                    title: Text('Payment'),
                    onTap: _incrementCounter)*/
              ],
            )))));

    return temp;
  }

  Future<void> confirmPriceChange(BuildContext context) async {
    if (Platform.isAndroid) {
      final InAppPurchaseAndroidPlatformAddition androidAddition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final BillingResultWrapper priceChangeConfirmationResult =
          await androidAddition.launchPriceChangeConfirmationFlow(
        sku: 'purchaseId',
      );
      if (context.mounted) {
        if (priceChangeConfirmationResult.responseCode == BillingResponse.ok) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('接受价格变动'),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              priceChangeConfirmationResult.debugMessage ??
                  '价格更改因代码失败 ${priceChangeConfirmationResult.responseCode}',
            ),
          ));
        }
      }
    }
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iapStoreKitPlatformAddition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iapStoreKitPlatformAddition.showPriceConsentIfNeeded();
    }
  }

  GooglePlayPurchaseDetails? _getOldSubscription(
      ProductDetails productDetails, Map<String, PurchaseDetails> purchases) {
    // This is just to demonstrate a subscription upgrade or downgrade.
    // This method assumes that you have only 2 subscriptions under a group, 'subscription_silver' & 'subscription_gold'.
    // The 'subscription_silver' subscription can be upgraded to 'subscription_gold' and
    // the 'subscription_gold' subscription can be downgraded to 'subscription_silver'.
    // Please remember to replace the logic of finding the old subscription Id as per your app.
    // The old subscription is only required on Android since Apple handles this internally
    // by using the subscription group feature in iTunesConnect.
    GooglePlayPurchaseDetails? oldSubscription;
    if (productDetails.id == _kSilverSubscriptionId &&
        purchases[_kGoldSubscriptionId] != null) {
      oldSubscription =
          purchases[_kGoldSubscriptionId]! as GooglePlayPurchaseDetails;
    } else if (productDetails.id == _kGoldSubscriptionId &&
        purchases[_kSilverSubscriptionId] != null) {
      oldSubscription =
          purchases[_kSilverSubscriptionId]! as GooglePlayPurchaseDetails;
    }
    return oldSubscription;
  }

  void newChat() {
    setState(() {
      _messages.removeRange(0, _messages.length);
      _messages.add(ChatMessage('您好，请问有什么可以帮忙的?', false));
      _messagesToGPT.removeRange(0, _messagesToGPT.length);
    });
  }

  Future<void> loadChat(int id) async {
    await dbHelper.fetchChatDetail(id);
    setState(() {});
  }

  Future<void> _onSubmitted(String message) async {
    /*if ((_getCounter() ?? 0) as int <= 0) {
      print('buy');
    } else {*/
    setState(() {
      setMessage(message, true);
      _awaitingResponse = true;
    });
    try {
      final response = await widget.chatApi.completeChat(_messagesToGPT);
      setState(() {
        setMessage(response, false);
        _awaitingResponse = false;
        _reduceCounter();
      });
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发生错误。 请再试一次。.')),
      );
      setState(() {
        _awaitingResponse = false;
      });
    }
    //}
  }

  void setMessage(String message, bool isUserMsg) {
    _messages.add(ChatMessage(message, isUserMsg));
    _messagesToGPT.add(ChatMessage(message, isUserMsg));
    for (ChatMessage tempC in _messagesToGPT) print(tempC.content);
    setMessageGPT();
    saveMessage();
  }

  Future<void> resetMessage(int id) async {
    currentId = id;
    _messages.removeRange(0, _messages.length);
    _messagesToGPT.removeRange(0, _messagesToGPT.length);

    List<ChatDetail> temp = await dbHelper.fetchChatDetailsByChatId(id);
    for (ChatDetail cd in temp) {
      ChatMessage cm = ChatMessage(cd.detail, cd.is_user == 0 ? false : true);
      setState(() {
        _messages.add(cm);
        _messagesToGPT.add(cm);
      });
    }
    setMessageGPT();
  }

  Future<void> saveMessage() async {
    if (_messages.length == 2) {
      Chat temp = Chat(chatname: '');
      temp.chatname = _messages[_messages.length - 1].content;
      currentId = (await dbHelper.upsertChat(temp)).id!;
      initCHatLlist();
      for (ChatMessage cm in _messages) {
        ChatDetail temp2 = ChatDetail(
            chat_id: currentId,
            detail: cm.content,
            is_user: cm.isUserMessage ? 1 : 0,
            id: null);
        await dbHelper.upsertChatDetail(temp2);
      }
    } else if (_messages.length > 2) {
      ChatDetail temp2 = ChatDetail(
          chat_id: currentId,
          detail: _messages[_messages.length - 1].content,
          is_user: _messages[_messages.length - 1].isUserMessage ? 1 : 0,
          id: null);
      await dbHelper.upsertChatDetail(temp2);
    }
  }

  void setMessageGPT() {
    if (_messagesToGPT.length > storeCount)
      _messagesToGPT.removeRange(0, _messagesToGPT.length - storeCount);
  }

  Future<void> _incrementCounter(int count) async {
    final SharedPreferences prefs = await _prefs;
    final int counter = (prefs.getInt('counter') ?? countDefault) + count;

    setState(() {
      _counter = prefs.setInt('counter', counter).then((bool success) {
        return counter;
      });
    });
  }

  Future<void> _reduceCounter() async {
    final SharedPreferences prefs = await _prefs;
    final int counter = (prefs.getInt('counter') ?? countDefault) - 1;

    setState(() {
      _counter = prefs.setInt('counter', counter).then((bool success) {
        return counter;
      });
    });
  }

  Future<int> _getCounter() async {
    final SharedPreferences prefs = await _prefs;
    final int counter = (prefs.getInt('counter') ?? countDefault);

    return counter;
  }

  Future<int> _checkCounter() async {
    final SharedPreferences prefs = await _prefs;
    final int counter = (prefs.getInt('counter') ?? countDefault);

    return counter;
  }

  /*
  final dbHelper = DatabaseHelper.instance;
// Adding a user to the database
User admin = new User();
admin.username = "admin";
admin = await dbHelper.upsertUser(admin);

// Adding a blog to the database
Blog blog = new Blog();
blog.title = "My First Blog";
blog.body = "Some awesome content...";
blog.user_id = admin.id;
blog = await dbHelper.upsertBlog(blog);

// Fetching list of all the blogs
List<Blog> blogList = await dbHelper.fetchBlogs();
// Fetch blogs of admin
List<Blog> blogListUser = await dbHelper.fetchUserBlogs(admin.id);
// Delete a blog
int count = await dbHelper.fetchBlogs(blog.id);
  */
}

// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: avoid_classes_with_only_static_members
/// A store of consumable items.
///
/// This is a development prototype tha stores consumables in the shared
/// preferences. Do not use this in real world apps.
class ConsumableStore {
  static const String _kPrefKey = 'consumables';
  static Future<void> _writes = Future<void>.value();

  /// Adds a consumable with ID `id` to the store.
  ///
  /// The consumable is only added after the returned Future is complete.
  static Future<void> save(String id) {
    _writes = _writes.then((void _) => _doSave(id));
    return _writes;
  }

  /// Consumes a consumable with ID `id` from the store.
  ///
  /// The consumable was only consumed after the returned Future is complete.
  static Future<void> consume(String id) {
    _writes = _writes.then((void _) => _doConsume(id));
    return _writes;
  }

  /// Returns the list of consumables from the store.
  static Future<List<String>> load() async {
    return (await SharedPreferences.getInstance()).getStringList(_kPrefKey) ??
        <String>[];
  }

  static Future<void> _doSave(String id) async {
    final List<String> cached = await load();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cached.add(id);
    await prefs.setStringList(_kPrefKey, cached);
  }

  static Future<void> _doConsume(String id) async {
    final List<String> cached = await load();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cached.remove(id);
    await prefs.setStringList(_kPrefKey, cached);
  }
}

/// Example implementation of the
/// [`SKPaymentQueueDelegate`](https://developer.apple.com/documentation/storekit/skpaymentqueuedelegate?language=objc).
///
/// The payment queue delegate can be implementated to provide information
/// needed to complete transactions.
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
